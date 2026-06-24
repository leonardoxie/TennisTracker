# 🎾 TennisTracker — AI Tennis Ball Tracking Demo

A real-time tennis ball detection and trajectory tracking iOS app built with AVFoundation, Core Image, and a custom Kalman filter.

## Features

- **Real-time ball detection** using HSV color filtering with CIColorKernel
- **Trajectory tracking** with Kalman filter for smooth path estimation
- **Hit event detection** — automatically detects ball strikes with speed estimation
- **Court guide overlay** — draws a tennis court reference on the camera view
- **Speed visualization** — color-coded trajectory trail (green→yellow→red based on speed)
- **Session statistics** — real-time hit count, max/avg speed, current speed
- **Lighting modes** — Auto/Indoor/Outdoor color range presets

## Architecture

```
TennisTracker/
├── TennisTrackerApp.swift         # App entry point
├── ContentView.swift              # Main UI with camera + overlay + controls
├── CameraManager.swift            # AVFoundation camera capture (1080p@30fps)
├── BallDetector.swift             # HSV color-based ball detection via CIColorKernel
├── TrajectoryTracker.swift        # Kalman filter + hit detection + speed estimation
├── TrajectoryOverlayView.swift    # Canvas-based trajectory rendering
└── CameraPreviewView.swift        # UIViewRepresentable for AVCaptureVideoPreviewLayer
```

## Technical Details

### Ball Detection Pipeline
1. **CIColorKernel** applies HSV color thresholding (isolates yellow-green tennis balls)
2. **Pixel analysis** finds clusters of matching pixels
3. **Blob validation** checks size, roundness, and density
4. Returns normalized position + confidence

### Kalman Filter
- 4-state filter: `[x, y, vx, vy]`
- Predicts ball position when detection misses a frame
- Separates measurement noise from process noise
- Velocity estimation enables speed calculation and hit detection

### Hit Detection
- Monitors speed changes between frames
- Speed change > threshold → hit event
- Minimum frame gap prevents double-counting

## Requirements

- iOS 16.0+
- Xcode 15+
- iPhone with camera (real device required for camera features)

## Build

Open `TennisTracker.xcodeproj` in Xcode, select your device as the target, and run.

Or use xcodegen to regenerate the project:
```bash
xcodegen generate
```

## Roadmap

- [ ] Core ML model for more robust ball detection (replace color-based)
- [ ] Court calibration via Homography (user taps 4 corners)
- [ ] 3D trajectory reconstruction from monocular video
- [ ] Shot type classification (serve/forehand/backhand/volley)
- [ ] Match mode with score tracking
- [ ] Export/share analysis reports
- [ ] Badminton mode

## License

MIT
