import SwiftUI

/// Overlay view that draws ball trajectory, hit markers, detection boxes, and court guide
struct TrajectoryOverlayView: View {
    @ObservedObject var tracker: TrajectoryTracker
    let ballPosition: CGPoint?
    let ballRadius: CGFloat
    let showCourtGuide: Bool
    var detections: [BallDetector.Detection] = []
    var currentSpeed: Double = 0
    
    @State private var hitPulseScale: CGFloat = 1.0
    
    var body: some View {
        Canvas { context, size in
            // Draw detection bounding boxes
            drawDetectionBoxes(in: context, size: size)
            
            // Draw court guide lines
            if showCourtGuide {
                drawCourtGuide(in: context, size: size)
            }
            
            // Draw trajectory trail with enhanced visuals
            drawTrajectory(in: context, size: size)
            
            // Draw hit events
            drawHitMarkers(in: context, size: size)
            
            // Draw current ball
            if let pos = ballPosition {
                drawBall(at: pos, radius: ballRadius, in: context, size: size)
            }
        }
    }
    
    // MARK: - Detection Boxes
    
    private func drawDetectionBoxes(in context: GraphicsContext, size: CGSize) {
        for det in detections {
            let rect = CGRect(
                x: det.boundingBox.origin.x * size.width,
                y: (1 - det.boundingBox.origin.y - det.boundingBox.height) * size.height,
                width: det.boundingBox.width * size.width,
                height: det.boundingBox.height * size.height
            )
            
            let color: Color
            switch det.classId {
            case 0: color = .blue.opacity(0.5)
            case 1: color = .purple.opacity(0.5)
            case 2: color = .yellow.opacity(0.7)
            default: color = .white.opacity(0.3)
            }
            
            // Rounded corner bounding box
            context.stroke(Path(roundedRect: rect, cornerRadius: 6), with: .color(color), lineWidth: 1.5)
            
            // Label with rounded background
            let labelWidth: CGFloat = 100
            let labelRect = CGRect(x: rect.origin.x, y: rect.origin.y - 20, width: labelWidth, height: 18)
            context.fill(Path(roundedRect: labelRect, cornerRadius: 4), with: .color(color))
            
            let label = Text("\(det.className) \(Int(det.confidence * 100))%")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
            context.draw(label, at: CGPoint(x: labelRect.midX, y: labelRect.midY + 1))
        }
    }
    
    // MARK: - Court Guide
    
    private func drawCourtGuide(in context: GraphicsContext, size: CGSize) {
        let margin: CGFloat = size.width * 0.08
        let courtTop: CGFloat = size.height * 0.15
        let courtBottom: CGFloat = size.height * 0.85
        let courtLeft: CGFloat = margin
        let courtRight: CGFloat = size.width - margin
        let courtMidY: CGFloat = (courtTop + courtBottom) / 2
        let serviceLineTop: CGFloat = courtTop + (courtMidY - courtTop) * 0.45
        let serviceLineBottom: CGFloat = courtBottom - (courtBottom - courtMidY) * 0.45
        let singleLeft: CGFloat = margin + (courtRight - margin) * 0.12
        let singleRight: CGFloat = courtRight - (courtRight - margin) * 0.12
        
        var path = Path()
        
        // Outer boundary
        path.move(to: CGPoint(x: courtLeft, y: courtTop))
        path.addLine(to: CGPoint(x: courtRight, y: courtTop))
        path.addLine(to: CGPoint(x: courtRight, y: courtBottom))
        path.addLine(to: CGPoint(x: courtLeft, y: courtBottom))
        path.closeSubpath()
        
        // Center line
        path.move(to: CGPoint(x: size.width / 2, y: serviceLineTop))
        path.addLine(to: CGPoint(x: size.width / 2, y: serviceLineBottom))
        
        // Service lines
        path.move(to: CGPoint(x: singleLeft, y: serviceLineTop))
        path.addLine(to: CGPoint(x: singleRight, y: serviceLineTop))
        path.move(to: CGPoint(x: singleLeft, y: serviceLineBottom))
        path.addLine(to: CGPoint(x: singleRight, y: serviceLineBottom))
        
        // Single sidelines
        path.move(to: CGPoint(x: singleLeft, y: courtTop))
        path.addLine(to: CGPoint(x: singleLeft, y: courtBottom))
        path.move(to: CGPoint(x: singleRight, y: courtTop))
        path.addLine(to: CGPoint(x: singleRight, y: courtBottom))
        
        // Net
        path.move(to: CGPoint(x: courtLeft, y: courtMidY))
        path.addLine(to: CGPoint(x: courtRight, y: courtMidY))
        
        // Draw with slight glow effect
        context.stroke(path, with: .color(.green.opacity(0.25)), lineWidth: 2)
        
        // Net highlight
        var netPath = Path()
        netPath.move(to: CGPoint(x: courtLeft, y: courtMidY))
        netPath.addLine(to: CGPoint(x: courtRight, y: courtMidY))
        context.stroke(netPath, with: .color(.green.opacity(0.15)), lineWidth: 6)
        
        // Labels
        let netText = Text("网")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.green.opacity(0.5))
        context.draw(netText, at: CGPoint(x: size.width / 2, y: courtMidY - 14))
        
        // Corner markers
        let cornerSize: CGFloat = 12
        let corners: [CGPoint] = [
            CGPoint(x: courtLeft, y: courtTop),
            CGPoint(x: courtRight, y: courtTop),
            CGPoint(x: courtLeft, y: courtBottom),
            CGPoint(x: courtRight, y: courtBottom)
        ]
        for corner in corners {
            var hLine = Path()
            hLine.move(to: CGPoint(x: corner.x - cornerSize, y: corner.y))
            hLine.addLine(to: CGPoint(x: corner.x + cornerSize, y: corner.y))
            context.stroke(hLine, with: .color(.green.opacity(0.5)), lineWidth: 2)
            
            var vLine = Path()
            vLine.move(to: CGPoint(x: corner.x, y: corner.y - cornerSize))
            vLine.addLine(to: CGPoint(x: corner.x, y: corner.y + cornerSize))
            context.stroke(vLine, with: .color(.green.opacity(0.5)), lineWidth: 2)
        }
    }
    
    // MARK: - Enhanced Trajectory
    
    private func drawTrajectory(in context: GraphicsContext, size: CGSize) {
        let points = tracker.trajectoryPoints
        guard points.count >= 2 else { return }
        
        // Draw wider trail with glow effect
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            
            let progress = Double(i) / Double(points.count)
            let opacity = progress * 0.85 + 0.1
            let lineWidth = progress * 5 + 1.5
            
            let p1 = CGPoint(x: prev.position.x * size.width, y: (1 - prev.position.y) * size.height)
            let p2 = CGPoint(x: curr.position.x * size.width, y: (1 - curr.position.y) * size.height)
            
            // Color based on speed - enhanced gradient
            let speedRatio = min(curr.speed / 200, 1.0)
            let hue = 0.3 - speedRatio * 0.3
            let color = Color(hue: hue, saturation: 0.85, brightness: 0.95, opacity: opacity)
            
            var path = Path()
            path.move(to: p1)
            path.addLine(to: p2)
            
            // Glow (wider, more transparent)
            context.stroke(path, with: .color(color.opacity(0.25)), lineWidth: lineWidth * 2.5)
            // Main line
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
            
            // Particle dots
            if i % 2 == 0 {
                let dotSize: CGFloat = CGFloat(lineWidth) * 1.8
                let dotRect = CGRect(x: p2.x - dotSize / 2, y: p2.y - dotSize / 2, width: dotSize, height: dotSize)
                context.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(0.7)))
            }
        }
    }
    
    // MARK: - Enhanced Hit Markers
    
    private func drawHitMarkers(in context: GraphicsContext, size: CGSize) {
        for hit in tracker.hitEvents.suffix(10) {
            let pos = CGPoint(
                x: hit.position.x * size.width,
                y: (1 - hit.position.y) * size.height
            )
            
            let crossSize: CGFloat = 16
            let isLatest = hit.id == tracker.hitEvents.last?.id
            let markerOpacity: Double = isLatest ? 1.0 : 0.6
            
            // Pulse ring for latest hit
            if isLatest {
                let pulseSize: CGFloat = crossSize * 2.5
                let pulseRect = CGRect(x: pos.x - pulseSize, y: pos.y - pulseSize, width: pulseSize * 2, height: pulseSize * 2)
                context.stroke(Path(ellipseIn: pulseRect), with: .color(.orange.opacity(0.2)), lineWidth: 2)
            }
            
            // Outer ring
            let circleRect = CGRect(x: pos.x - crossSize, y: pos.y - crossSize, width: crossSize * 2, height: crossSize * 2)
            context.stroke(Path(ellipseIn: circleRect), with: .color(.orange.opacity(markerOpacity * 0.8)), lineWidth: 1.5)
            
            // Crosshair with rounded caps
            var crosshair = Path()
            crosshair.move(to: CGPoint(x: pos.x - crossSize, y: pos.y))
            crosshair.addLine(to: CGPoint(x: pos.x + crossSize, y: pos.y))
            crosshair.move(to: CGPoint(x: pos.x, y: pos.y - crossSize))
            crosshair.addLine(to: CGPoint(x: pos.x, y: pos.y + crossSize))
            context.stroke(crosshair, with: .color(.orange.opacity(markerOpacity)), lineWidth: 2)
            
            // Center dot
            let dotRect = CGRect(x: pos.x - 3, y: pos.y - 3, width: 6, height: 6)
            context.fill(Path(ellipseIn: dotRect), with: .color(.orange.opacity(markerOpacity)))
            
            // Speed label with background
            let speedLabel = "\(Int(hit.speed))km/h"
            let labelText = Text(speedLabel)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.orange.opacity(markerOpacity))
            
            // Label background
            let labelWidth: CGFloat = 65
            let labelBgRect = CGRect(x: pos.x - labelWidth / 2, y: pos.y - crossSize - 22, width: labelWidth, height: 16)
            context.fill(Path(roundedRect: labelBgRect, cornerRadius: 4), with: .color(.black.opacity(0.6)))
            context.draw(labelText, at: CGPoint(x: pos.x, y: pos.y - crossSize - 14))
        }
    }
    
    // MARK: - Enhanced Ball Drawing
    
    private func drawBall(at position: CGPoint, radius: CGFloat, in context: GraphicsContext, size: CGSize) {
        let center = CGPoint(
            x: position.x * size.width,
            y: (1 - position.y) * size.height
        )
        let r = max(radius * size.width, 7)
        
        // Outer glow
        let outerGlowRect = CGRect(x: center.x - r * 3, y: center.y - r * 3, width: r * 6, height: r * 6)
        context.fill(Path(ellipseIn: outerGlowRect), with: .color(.yellow.opacity(0.08)))
        
        // Inner glow
        let glowRect = CGRect(x: center.x - r * 2, y: center.y - r * 2, width: r * 4, height: r * 4)
        context.fill(Path(ellipseIn: glowRect), with: .color(.yellow.opacity(0.2)))
        
        // Ball body
        let ballRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        context.fill(Path(ellipseIn: ballRect), with: .color(.yellow))
        
        // Ball highlight
        let highlightRect = CGRect(x: center.x - r * 0.5, y: center.y - r * 0.6, width: r * 0.7, height: r * 0.5)
        context.fill(Path(ellipseIn: highlightRect), with: .color(.white.opacity(0.4)))
        
        // Ball outline
        context.stroke(Path(ellipseIn: ballRect), with: .color(.white.opacity(0.8)), lineWidth: 1.5)
        
        // Shadow
        let shadowRect = CGRect(x: center.x - r * 0.7, y: center.y + r * 0.6, width: r * 1.4, height: r * 0.5)
        context.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(0.15)))
        
        // Speed label near ball when moving fast
        if currentSpeed > 60 {
            let speedLabel = Text("\(Int(currentSpeed)) km/h")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
            
            let labelBgRect = CGRect(x: center.x + r + 6, y: center.y - 8, width: 62, height: 16)
            context.fill(Path(roundedRect: labelBgRect, cornerRadius: 4), with: .color(.black.opacity(0.5)))
            context.draw(speedLabel, at: CGPoint(x: center.x + r + 37, y: center.y))
        }
    }
}
