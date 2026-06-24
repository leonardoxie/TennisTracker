import Foundation

/// Tracks ball trajectory using a simplified Kalman filter
class TrajectoryTracker: ObservableObject {
    
    // MARK: - Types
    
    struct TrackedPoint: Identifiable {
        let id = UUID()
        let position: CGPoint     // Normalized (0-1)
        let velocity: CGPoint     // Normalized velocity per second
        let timestamp: TimeInterval
        let speed: Double         // Estimated speed in km/h
        let isFiltered: Bool      // Was this a Kalman-filtered estimate?
    }
    
    struct HitEvent: Identifiable {
        let id = UUID()
        let position: CGPoint
        let timestamp: TimeInterval
        let speed: Double         // Ball speed at hit (km/h)
        let direction: Double     // Angle in degrees
    }
    
    struct SessionStats {
        var totalHits: Int = 0
        var maxSpeed: Double = 0
        var avgSpeed: Double = 0
        var totalSpeed: Double = 0
        var sessionDuration: TimeInterval = 0
        var startTime: Date?
        
        mutating func recordHit(speed: Double) {
            totalHits += 1
            totalSpeed += speed
            avgSpeed = totalSpeed / Double(totalHits)
            if speed > maxSpeed { maxSpeed = speed }
        }
    }
    
    // MARK: - Published State
    
    @Published var trajectoryPoints: [TrackedPoint] = []
    @Published var hitEvents: [HitEvent] = []
    @Published var stats = SessionStats()
    @Published var currentSpeed: Double = 0
    @Published var isTracking = false
    
    // MARK: - Kalman Filter State (scalar representation)
    // State vector: [x, y, vx, vy]
    // Covariance: 4x4 stored as flat array [16 elements]
    
    private var sx: Double = 0, sy: Double = 0  // position
    private var svx: Double = 0, svy: Double = 0 // velocity
    
    // Covariance matrix P (4x4, row-major)
    private var P = [Double](repeating: 0, count: 16)
    
    // Noise parameters
    private let qPos: Double = 0.001    // Process noise for position
    private let qVel: Double = 0.01     // Process noise for velocity
    private let rMeas: Double = 0.003   // Measurement noise
    
    // MARK: - Tracking Parameters
    
    var maxTrajectoryPoints: Int = 200
    var hitDetectionThreshold: Double = 40 // Speed change (km/h) to count as hit
    var minFramesForHit: Int = 3
    var speedScaleFactor: Double = 800     // Scale normalized velocity to km/h
    
    private var lastDetectionTime: TimeInterval = 0
    private var framesSinceLastHit: Int = 0
    private var previousSpeed: Double = 0
    
    // MARK: - Public API
    
    func startTracking() {
        reset()
        isTracking = true
        stats.startTime = Date()
    }
    
    func stopTracking() {
        if let start = stats.startTime {
            stats.sessionDuration = Date().timeIntervalSince(start)
        }
        isTracking = false
    }
    
    func reset() {
        trajectoryPoints.removeAll()
        hitEvents.removeAll()
        stats = SessionStats()
        sx = 0; sy = 0; svx = 0; svy = 0
        P = [Double](repeating: 0, count: 16)
        // Initialize diagonal
        P[0] = 1; P[5] = 1; P[10] = 1; P[15] = 1
        lastDetectionTime = 0
        framesSinceLastHit = 0
        previousSpeed = 0
        currentSpeed = 0
    }
    
    /// Process a new ball detection
    func processDetection(_ detection: TrajectoryDetection) {
        let dt: Double
        if lastDetectionTime > 0 {
            dt = detection.timestamp - lastDetectionTime
        } else {
            dt = 1.0 / 30.0
        }
        lastDetectionTime = detection.timestamp
        
        guard dt > 0 && dt < 0.5 else { return }
        
        let mx = Double(detection.center.x)
        let my = Double(detection.center.y)
        
        // Kalman predict
        kalmanPredict(dt: dt)
        
        // Kalman update
        kalmanUpdate(mx: mx, my: my)
        
        // Calculate speed
        let speed = sqrt(svx * svx + svy * svy) * speedScaleFactor
        currentSpeed = speed
        
        // Check for hit event
        framesSinceLastHit += 1
        let speedChange = abs(speed - previousSpeed)
        if speedChange > hitDetectionThreshold && framesSinceLastHit >= minFramesForHit {
            let direction = atan2(svy, svx) * 180 / .pi
            let hit = HitEvent(
                position: CGPoint(x: sx, y: sy),
                timestamp: detection.timestamp,
                speed: speed,
                direction: direction
            )
            hitEvents.append(hit)
            stats.recordHit(speed: speed)
            framesSinceLastHit = 0
        }
        previousSpeed = speed
        
        // Add to trajectory
        let point = TrackedPoint(
            position: CGPoint(x: sx, y: sy),
            velocity: CGPoint(x: svx, y: svy),
            timestamp: detection.timestamp,
            speed: speed,
            isFiltered: false
        )
        trajectoryPoints.append(point)
        
        if trajectoryPoints.count > maxTrajectoryPoints {
            trajectoryPoints.removeFirst(trajectoryPoints.count - maxTrajectoryPoints)
        }
    }
    
    /// Process a frame with no detection (use Kalman prediction)
    func processMiss(timestamp: TimeInterval) {
        guard lastDetectionTime > 0 else { return }
        
        let dt = timestamp - lastDetectionTime
        guard dt > 0 && dt < 0.15 else { return }
        
        kalmanPredict(dt: dt)
        
        let speed = sqrt(svx * svx + svy * svy) * speedScaleFactor
        currentSpeed = speed * 0.8
        
        let point = TrackedPoint(
            position: CGPoint(x: sx, y: sy),
            velocity: CGPoint(x: svx, y: svy),
            timestamp: timestamp,
            speed: speed * 0.8,
            isFiltered: true
        )
        trajectoryPoints.append(point)
    }
    
    // MARK: - Kalman Filter (scalar implementation)
    
    private func kalmanPredict(dt: Double) {
        // State prediction
        sx += svx * dt
        sy += svy * dt
        // velocity unchanged
        
        // Covariance prediction: P = F * P * F^T + Q
        // F = [[1,0,dt,0],[0,1,0,dt],[0,0,1,0],[0,0,0,1]]
        // This is equivalent to:
        // P'[i][j] = P[i][j] + dt * (P[i][3]*F[j][3]^T + F[i][2]*P[2][j] ...) 
        // Simplified for our specific F:
        
        let dt2 = dt * dt
        
        // Update position-velocity cross terms
        P[0] += dt * (P[2] + P[8]) + dt2 * P[10] + qPos   // P[0][0]
        P[1] += dt * (P[3] + P[9]) + dt2 * P[11]           // P[0][1]
        P[4] += dt * (P[6] + P[12]) + dt2 * P[14]           // P[1][0]
        P[5] += dt * (P[7] + P[13]) + dt2 * P[15] + qPos   // P[1][1]
        
        P[2] += dt * P[10]   // P[0][2]
        P[3] += dt * P[11]   // P[0][3]
        P[6] += dt * P[14]   // P[1][2]
        P[7] += dt * P[15]   // P[1][3]
        
        P[8] += dt * P[10]   // P[2][0]
        P[9] += dt * P[11]   // P[2][1]
        P[12] += dt * P[14]  // P[3][0]
        P[13] += dt * P[15]  // P[3][1]
        
        P[10] += qVel  // P[2][2]
        P[15] += qVel  // P[3][3]
    }
    
    private func kalmanUpdate(mx: Double, my: Double) {
        // Measurement: z = [mx, my]
        // H = [[1,0,0,0],[0,1,0,0]]
        // We only observe position, not velocity
        
        // Innovation
        let ix = mx - sx
        let iy = my - sy
        
        // Innovation covariance S = H*P*H^T + R
        // S is 2x2: S[0][0] = P[0][0] + R, S[0][1] = P[0][1], S[1][0] = P[1][0], S[1][1] = P[1][1] + R
        let s00 = P[0] + rMeas
        let s01 = P[1]
        let s10 = P[4]
        let s11 = P[5] + rMeas
        
        // S inverse (2x2)
        let det = s00 * s11 - s01 * s10
        guard abs(det) > 1e-12 else { return }
        let invDet = 1.0 / det
        let si00 = s11 * invDet
        let si01 = -s01 * invDet
        let si10 = -s10 * invDet
        let si11 = s00 * invDet
        
        // Kalman gain K = P * H^T * S^-1 (4x2)
        // K[i][0] = P[i][0]*si00 + P[i][1]*si10
        // K[i][1] = P[i][0]*si01 + P[i][1]*si11
        let k00 = P[0] * si00 + P[1] * si10
        let k01 = P[0] * si01 + P[1] * si11
        let k10 = P[4] * si00 + P[5] * si10
        let k11 = P[4] * si01 + P[5] * si11
        let k20 = P[8] * si00 + P[9] * si10
        let k21 = P[8] * si01 + P[9] * si11
        let k30 = P[12] * si00 + P[13] * si10
        let k31 = P[12] * si01 + P[13] * si11
        
        // State update: x = x + K * innovation
        sx += k00 * ix + k01 * iy
        sy += k10 * ix + k11 * iy
        svx += k20 * ix + k21 * iy
        svy += k30 * ix + k31 * iy
        
        // Covariance update: P = (I - K*H) * P
        // K*H is 4x4 with K*H[i][j] = K[i][0]*H[0][j] + K[i][1]*H[1][j]
        // Since H = [[1,0,0,0],[0,1,0,0]], K*H[i][j] = K[i][0] if j==0, K[i][1] if j==1, else 0
        // So (I - K*H)[i][j] = delta(i,j) - K[i][j_col]
        
        // New P = (I - K*H) * P
        // Store old P first
        let oldP = P
        
        for i in 0..<4 {
            for j in 0..<4 {
                var sum = 0.0
                for k in 0..<4 {
                    var iKh: Double
                    if k == 0 { iKh = (i == 0 ? 1.0 : 0.0) - [k00, k10, k20, k30][i] }
                    else if k == 1 { iKh = (i == 1 ? 1.0 : 0.0) - [k01, k11, k21, k31][i] }
                    else { iKh = (i == k ? 1.0 : 0.0) }
                    sum += iKh * oldP[k * 4 + j]
                }
                P[i * 4 + j] = sum
            }
        }
    }
}
