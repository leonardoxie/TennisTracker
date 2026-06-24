import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var trajectoryTracker = TrajectoryTracker()
    
    @State private var ballDetector = BallDetector()
    @State private var currentBallPosition: CGPoint? = nil
    @State private var currentBallRadius: CGFloat = 0
    @State private var showCourtGuide = true
    @State private var showStats = true
    @State private var isRecording = false
    @State private var frameCount: Int = 0
    @State private var fps: Double = 0
    @State private var lastFpsTime: TimeInterval = 0
    @State private var fpsFrameCount: Int = 0
    
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
                            showCourtGuide: showCourtGuide
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
                
                // Real-time stats
                if showStats && isRecording {
                    realtimeStats
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
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    // MARK: - UI Components
    
    private var topBar: some View {
        HStack {
            // App title
            VStack(alignment: .leading, spacing: 2) {
                Text("🎾 RacquetVision")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("Tennis Ball Tracker")
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.7)
            }
            .foregroundColor(.white)
            .padding(10)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            Spacer()
            
            // FPS indicator
            if isRecording {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(isRecording ? 1 : 0.3)
                    Text(String(format: "%.0f fps", fps))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            }
            
            // Settings
            Menu {
                Toggle("Court Guide", isOn: $showCourtGuide)
                Toggle("Stats Panel", isOn: $showStats)
                
                Menu("Lighting") {
                    Button("Auto") { ballDetector.colorRange = .default }
                    Button("Indoor") { ballDetector.colorRange = .indoor }
                    Button("Outdoor") { ballDetector.colorRange = .outdoor }
                }
                
                Button("Switch Camera") { cameraManager.switchCamera() }
                Button("Reset Trajectory") { trajectoryTracker.reset() }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
            }
        }
    }
    
    private var realtimeStats: some View {
        HStack(spacing: 16) {
            StatBadge(
                icon: "speedometer",
                label: "Speed",
                value: String(format: "%.0f", trajectoryTracker.currentSpeed),
                unit: "km/h",
                color: speedColor(trajectoryTracker.currentSpeed)
            )
            
            StatBadge(
                icon: "target",
                label: "Hits",
                value: "\(trajectoryTracker.stats.totalHits)",
                unit: "shots",
                color: .blue
            )
            
            StatBadge(
                icon: "bolt.fill",
                label: "Max",
                value: String(format: "%.0f", trajectoryTracker.stats.maxSpeed),
                unit: "km/h",
                color: .orange
            )
            
            StatBadge(
                icon: "chart.line.uptrend.xyaxis",
                label: "Avg",
                value: String(format: "%.0f", trajectoryTracker.stats.avgSpeed),
                unit: "km/h",
                color: .green
            )
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var bottomControls: some View {
        HStack(spacing: 24) {
            // Reset button
            Button {
                withAnimation {
                    trajectoryTracker.reset()
                    currentBallPosition = nil
                    frameCount = 0
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20))
                    Text("Reset")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
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
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .fill(isRecording ? .red : .white)
                        .frame(width: isRecording ? 32 : 60, height: isRecording ? 32 : 60)
                        .cornerRadius(isRecording ? 4 : 30)
                }
            }
            
            // Toggle court guide
            Button {
                withAnimation {
                    showCourtGuide.toggle()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: showCourtGuide ? "rectangle.and.hand.point.up.left" : "rectangle")
                        .font(.system(size: 20))
                    Text("Court")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
        }
        .padding(.bottom, 8)
    }
    
    private var cameraRequestView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Camera Access Required")
                .font(.title2.bold())
            
            Text("RacquetVision needs camera access to detect and track tennis balls in real-time.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button("Grant Access") {
                cameraManager.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    private var cameraDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Camera Access Denied")
                .font(.title2.bold())
            
            Text("Please enable camera access in Settings to use RacquetVision.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    // MARK: - Logic
    
    private func setupFrameProcessing() {
        cameraManager.onFrameCaptured = { [weak trajectoryTracker] sampleBuffer in
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            
            // Detect ball
            if let detection = self.ballDetector.detect(in: pixelBuffer, timestamp: timestamp) {
                DispatchQueue.main.async {
                    self.currentBallPosition = detection.center
                    self.currentBallRadius = detection.radius
                    self.frameCount += 1
                    
                    if self.isRecording {
                        trajectoryTracker?.processDetection(detection)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    // Ball not found - use Kalman prediction if recording
                    if self.isRecording {
                        trajectoryTracker?.processMiss(timestamp: timestamp)
                    }
                    // Fade out ball indicator after a short delay
                    self.currentBallPosition = nil
                }
            }
            
            // FPS calculation
            DispatchQueue.main.async {
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
        } else {
            trajectoryTracker.stopTracking()
        }
    }
    
    private func speedColor(_ speed: Double) -> Color {
        if speed < 50 { return .green }
        if speed < 100 { return .yellow }
        if speed < 150 { return .orange }
        return .red
    }
}

// MARK: - Stat Badge Component

struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            HStack(spacing: 2) {
                Text(label)
                Text(unit)
            }
            .font(.system(size: 8, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
        }
        .frame(minWidth: 55)
    }
}

#Preview {
    ContentView()
}
