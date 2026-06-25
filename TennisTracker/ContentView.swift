import SwiftUI
import AVFoundation

/// Main training view with camera + detection + trajectory overlay
struct ContentView: View {
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var trajectoryTracker: TrajectoryTracker
    
    @State private var ballDetector = BallDetector()
    @State private var currentBallPosition: CGPoint? = nil
    @State private var currentBallRadius: CGFloat = 0
    @State private var currentDetections: [BallDetector.Detection] = []
    @State private var showCourtGuide = true
    @State private var showStats = true
    @State private var isRecording = false
    @State private var frameCount: Int = 0
    @State private var fps: Double = 0
    @State private var lastFpsTime: TimeInterval = 0
    @State private var fpsFrameCount: Int = 0
    @State private var modelLoaded: Bool = false
    
    // Session summary popup
    @State private var showSessionSummary = false
    @State private var lastSession: SessionRecord?
    
    // For hit type classification
    @State private var courtMapper = CourtCoordinateSystem()
    
    // Landing point tracking
    @State private var ballLandingPoints: [LandingPoint] = []
    @State private var playerPositions: [PlayerPosition] = []
    @State private var previousBallSpeed: Double = 0
    @State private var speedDropCount: Int = 0
    
    var body: some View {
        ZStack {
            // Camera preview
            if cameraManager.authorizationStatus == .authorized {
                CameraPreviewView(captureSession: cameraManager.captureSession)
                    .ignoresSafeArea()
                    .overlay {
                        TrajectoryOverlayView(
                            tracker: trajectoryTracker,
                            ballPosition: currentBallPosition,
                            ballRadius: currentBallRadius,
                            showCourtGuide: showCourtGuide,
                            detections: currentDetections,
                            currentSpeed: trajectoryTracker.currentSpeed
                        )
                        .ignoresSafeArea()
                    }
            } else if cameraManager.authorizationStatus == .denied {
                cameraDeniedView
            } else {
                cameraRequestView
            }
            
            // UI Overlay
            VStack {
                // Top bar
                topBar
                
                Spacer()
                
                // Detection info
                if !currentDetections.isEmpty {
                    detectionInfo
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Real-time stats
                if showStats && isRecording {
                    realtimeStats
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Session summary popup
                if showSessionSummary, let session = lastSession {
                    sessionSummaryCard(session)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Bottom controls
                bottomControls
            }
            .padding()
        }
        .onAppear {
            cameraManager.requestPermission()
            setupFrameProcessing()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                modelLoaded = true
            }
        }
        .onDisappear {
            if isRecording {
                stopRecording()
            }
        }
    }
    
    // MARK: - UI Components
    
    private var topBar: some View {
        HStack {
            // App title
            HStack(spacing: 8) {
                Image(systemName: "tennisball.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.78, green: 0.90, blue: 0.20))
                VStack(alignment: .leading, spacing: 1) {
                    Text("TennisTracker")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(modelLoaded ? Color(red: 0.78, green: 0.90, blue: 0.20) : .orange)
                            .frame(width: 6, height: 6)
                        Text(modelLoaded ? "就绪" : "加载中...")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
            
            Spacer()
            
            // Recording indicator + FPS
            if isRecording {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 7, height: 7)
                            .opacity(isRecording ? 1 : 0.3)
                        Text("录制中")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Text(String(format: "%.0f", fps))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("fps")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            }
            
            // Settings menu
            Menu {
                Toggle("球场标线", isOn: $showCourtGuide)
                Toggle("实时统计", isOn: $showStats)
                Button("切换摄像头") { cameraManager.switchCamera() }
                Button("重置轨迹") {
                    withAnimation {
                        trajectoryTracker.reset()
                        ballLandingPoints.removeAll()
                        playerPositions.removeAll()
                    }
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }
        }
    }
    
    private var detectionInfo: some View {
        HStack(spacing: 6) {
            ForEach(currentDetections, id: \.timestamp) { det in
                HStack(spacing: 4) {
                    Circle()
                        .fill(det.classId == 2 ? Color.yellow : det.classId == 0 ? Color.blue : Color.purple)
                        .frame(width: 6, height: 6)
                    Text(det.className)
                        .font(.system(size: 10, weight: .semibold))
                    Text(String(format: "%.0f%%", det.confidence * 100))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .opacity(0.7)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            }
        }
    }
    
    private var realtimeStats: some View {
        HStack(spacing: 8) {
            CompactStatBadge(
                icon: "speedometer",
                value: String(format: "%.0f", trajectoryTracker.currentSpeed),
                unit: "km/h",
                color: speedColor(trajectoryTracker.currentSpeed)
            )
            
            CompactStatBadge(
                icon: "target",
                value: "\(trajectoryTracker.stats.totalHits)",
                unit: "次",
                color: .blue
            )
            
            CompactStatBadge(
                icon: "bolt.fill",
                value: String(format: "%.0f", trajectoryTracker.stats.maxSpeed),
                unit: "最高",
                color: .orange
            )
            
            CompactStatBadge(
                icon: "chart.line.uptrend.xyaxis",
                value: String(format: "%.0f", trajectoryTracker.stats.avgSpeed),
                unit: "平均",
                color: Color(red: 0.78, green: 0.90, blue: 0.20)
            )
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
    }
    
    // MARK: - Session Summary Card
    
    private func sessionSummaryCard(_ session: SessionRecord) -> some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.78, green: 0.90, blue: 0.20))
                Text("训练完成")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    withAnimation { showSessionSummary = false }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            // Quick stats
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("\(session.summary.totalHits)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("击球")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                
                Divider().background(Color.white.opacity(0.1)).frame(height: 28)
                
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", session.summary.avgSpeed))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("km/h")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                
                Divider().background(Color.white.opacity(0.1)).frame(height: 28)
                
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", session.summary.maxSpeed))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("最高速度")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }
            
            // Mini heatmap preview button
            if !session.hitEvents.isEmpty {
                Button {
                    // Navigate to analytics - this would need to be handled via tab switching
                    showSessionSummary = false
                } label: {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 12))
                        Text("查看详细分析")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.78, green: 0.90, blue: 0.20), Color(red: 0.65, green: 0.82, blue: 0.15)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(10)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        HStack(spacing: 20) {
            // Reset button
            Button {
                withAnimation {
                    trajectoryTracker.reset()
                    currentBallPosition = nil
                    frameCount = 0
                    ballLandingPoints.removeAll()
                    playerPositions.removeAll()
                    showSessionSummary = false
                }
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 18))
                    Text("重置")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial)
                .cornerRadius(14)
            }
            
            // Record button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    toggleRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 76, height: 76)
                    
                    Circle()
                        .fill(isRecording ? .red : Color(red: 0.78, green: 0.90, blue: 0.20))
                        .frame(width: isRecording ? 30 : 58, height: isRecording ? 30 : 58)
                        .cornerRadius(isRecording ? 4 : 29)
                        .animation(.spring(response: 0.3), value: isRecording)
                }
            }
            
            // Toggle court guide
            Button {
                withAnimation {
                    showCourtGuide.toggle()
                }
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: showCourtGuide ? "rectangle.and.hand.point.up.left" : "rectangle")
                        .font(.system(size: 18))
                    Text("球场")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial)
                .cornerRadius(14)
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Camera Views
    
    private var cameraRequestView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.78, green: 0.90, blue: 0.20))
            Text("需要摄像头权限")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("TennisTracker需要使用摄像头来实时检测和追踪网球。")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 40)
            Button("授权使用") {
                cameraManager.requestPermission()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(red: 0.78, green: 0.90, blue: 0.20))
            .cornerRadius(12)
        }
    }
    
    private var cameraDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            Text("摄像头权限已拒绝")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("请在设置中开启摄像头权限以使用TennisTracker。")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 40)
            Button("打开设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(red: 0.78, green: 0.90, blue: 0.20))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Logic
    
    private func setupFrameProcessing() {
        cameraManager.onFrameCaptured = { [weak trajectoryTracker] sampleBuffer in
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            
            let detections = self.ballDetector.detect(in: pixelBuffer, timestamp: timestamp)
            let ballDetection = detections.first { $0.classId == 2 }
            
            // Player detection
            let playerDetection = detections.first { $0.classId == 0 }
            
            DispatchQueue.main.async {
                self.currentDetections = detections
                self.frameCount += 1
                
                // Track player position
                if let player = playerDetection {
                    self.playerPositions.append(PlayerPosition(position: player.center, timestamp: timestamp))
                }
                
                if let ball = ballDetection {
                    self.currentBallPosition = ball.center
                    self.currentBallRadius = ball.radius
                    
                    if self.isRecording {
                        trajectoryTracker?.processDetection(
                            TrajectoryDetection(
                                center: ball.center,
                                radius: ball.radius,
                                confidence: ball.confidence,
                                boundingBox: ball.boundingBox,
                                timestamp: ball.timestamp
                            )
                        )
                        
                        // Landing point detection: significant speed drop
                        let currentSpeed = trajectoryTracker?.currentSpeed ?? 0
                        if self.previousBallSpeed > 30 && currentSpeed < self.previousBallSpeed * 0.4 {
                            self.speedDropCount += 1
                            if self.speedDropCount >= 2 {
                                self.ballLandingPoints.append(LandingPoint(
                                    position: ball.center,
                                    timestamp: timestamp,
                                    speed: currentSpeed
                                ))
                                self.speedDropCount = 0
                            }
                        } else {
                            self.speedDropCount = max(0, self.speedDropCount - 1)
                        }
                        self.previousBallSpeed = currentSpeed
                    }
                } else {
                    if self.isRecording {
                        trajectoryTracker?.processMiss(timestamp: timestamp)
                    }
                    self.currentBallPosition = nil
                }
                
                // FPS calculation
                self.fpsFrameCount += 1
                let now = timestamp
                if now - self.lastFpsTime >= 1.0 {
                    self.fps = Double(self.fpsFrameCount) / (now - self.lastFpsTime)
                    self.fpsFrameCount = 0
                    self.lastFpsTime = now
                }
            }
        }
    }
    
    private func toggleRecording() {
        isRecording.toggle()
        if isRecording {
            cameraManager.startSession()
            trajectoryTracker.startTracking()
            showSessionSummary = false
            ballLandingPoints.removeAll()
            playerPositions.removeAll()
        } else {
            stopRecording()
        }
    }
    
    private func stopRecording() {
        isRecording = false
        trajectoryTracker.stopTracking()
        
        // Build session record
        let session = buildSessionRecord()
        sessionStore.save(session)
        lastSession = session
        
        withAnimation(.spring(response: 0.4)) {
            showSessionSummary = true
        }
    }
    
    private func buildSessionRecord() -> SessionRecord {
        // Classify hit types using court mapper
        let hitRecords: [HitEventRecord] = trajectoryTracker.hitEvents.map { event in
            let velocity = CGPoint(x: cos(event.direction * .pi / 180), y: sin(event.direction * .pi / 180))
            let (_, hitType) = courtMapper.classifyHit(normalizedPoint: event.position, velocity: velocity)
            return HitEventRecord(
                position: event.position,
                speed: event.speed,
                direction: event.direction,
                timestamp: event.timestamp,
                hitType: hitType
            )
        }
        
        // Build summary
        var summary = SessionSummary()
        summary.totalHits = hitRecords.count
        summary.duration = trajectoryTracker.stats.sessionDuration
        summary.maxSpeed = trajectoryTracker.stats.maxSpeed
        summary.avgSpeed = trajectoryTracker.stats.avgSpeed
        
        for hit in hitRecords {
            switch hit.hitType {
            case .forehand: summary.forehandCount += 1
            case .backhand: summary.backhandCount += 1
            case .serve: summary.serveCount += 1
            case .volley: summary.volleyCount += 1
            case .unknown: summary.unknownCount += 1
            }
        }
        
        return SessionRecord(
            date: trajectoryTracker.stats.startTime ?? Date(),
            duration: summary.duration,
            hitEvents: hitRecords,
            ballLandingPoints: ballLandingPoints,
            playerPositions: playerPositions,
            summary: summary
        )
    }
    
    private func speedColor(_ speed: Double) -> Color {
        if speed < 50 { return .green }
        if speed < 100 { return .yellow }
        if speed < 150 { return .orange }
        return .red
    }
}

// MARK: - Bridge type between BallDetector and TrajectoryTracker

struct TrajectoryDetection {
    let center: CGPoint
    let radius: CGFloat
    let confidence: Float
    let boundingBox: CGRect
    let timestamp: TimeInterval
}

// MARK: - Compact Stat Badge Component

struct CompactStatBadge: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(unit)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(minWidth: 50)
    }
}

#Preview {
    ContentView(
        sessionStore: SessionStore(),
        cameraManager: CameraManager(),
        trajectoryTracker: TrajectoryTracker()
    )
}
