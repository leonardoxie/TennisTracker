import SwiftUI

/// Overlay view that draws ball trajectory, hit markers, detection boxes, and court guide
struct TrajectoryOverlayView: View {
    @ObservedObject var tracker: TrajectoryTracker
    let ballPosition: CGPoint?    // Current ball position (normalized)
    let ballRadius: CGFloat       // Current ball radius (normalized)
    let showCourtGuide: Bool
    var detections: [BallDetector.Detection] = []
    
    var body: some View {
        Canvas { context, size in
            // Draw detection bounding boxes
            drawDetectionBoxes(in: context, size: size)
            // Draw court guide lines
            if showCourtGuide {
                drawCourtGuide(in: context, size: size)
            }
            
            // Draw trajectory trail
            drawTrajectory(in: context, size: size)
            
            // Draw hit events
            drawHitMarkers(in: context, size: size)
            
            // Draw current ball
            if let pos = ballPosition {
                drawBall(at: pos, radius: ballRadius, in: context, size: size)
            }
        }
    }
    
    // MARK: - Drawing Functions
    
    private func drawDetectionBoxes(in context: GraphicsContext, size: CGSize) {
        for det in detections {
            let rect = CGRect(
                x: det.boundingBox.origin.x * size.width,
                y: (1 - det.boundingBox.origin.y - det.boundingBox.height) * size.height,
                width: det.boundingBox.width * size.width,
                height: det.boundingBox.height * size.height
            )
            
            // Color by class
            let color: Color
            switch det.classId {
            case 0: color = .blue.opacity(0.5)     // Player
            case 1: color = .purple.opacity(0.5)   // Racket
            case 2: color = .yellow.opacity(0.7)   // Tennis Ball
            default: color = .white.opacity(0.3)
            }
            
            // Bounding box
            context.stroke(Path(roundedRect: rect, cornerRadius: 4), with: .color(color), lineWidth: 2)
            
            // Label
            let label = Text("\(det.className) \(Int(det.confidence * 100))%")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
            let labelBg = Path(roundedRect: CGRect(x: rect.origin.x, y: rect.origin.y - 18, width: 90, height: 16), cornerRadius: 3)
            context.fill(labelBg, with: .color(color))
            context.draw(label, at: CGPoint(x: rect.origin.x + 45, y: rect.origin.y - 10))
        }
    }
    
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
        
        // Outer boundary (doubles court)
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
        
        context.stroke(path, with: .color(.green.opacity(0.3)), lineWidth: 1.5)
        
        // Labels
        let netText = Text("NET").font(.system(size: 10)).foregroundColor(.green.opacity(0.4))
        context.draw(netText, at: CGPoint(x: size.width / 2, y: courtMidY - 12))
    }
    
    private func drawTrajectory(in context: GraphicsContext, size: CGSize) {
        let points = tracker.trajectoryPoints
        guard points.count >= 2 else { return }
        
        // Draw fading trail
        for i in 1..<points.count {
            let prev = points[i - 1]
            let curr = points[i]
            
            let progress = Double(i) / Double(points.count)
            let opacity = progress * 0.8 + 0.1
            let lineWidth = progress * 4 + 1
            
            let p1 = CGPoint(x: prev.position.x * size.width, y: (1 - prev.position.y) * size.height)
            let p2 = CGPoint(x: curr.position.x * size.width, y: (1 - curr.position.y) * size.height)
            
            // Color based on speed
            let speedRatio = min(curr.speed / 200, 1.0)
            let color = Color(
                hue: 0.3 - speedRatio * 0.3, // Green → Red
                saturation: 0.8,
                brightness: 0.9,
                opacity: opacity
            )
            
            var path = Path()
            path.move(to: p1)
            path.addLine(to: p2)
            
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
            
            // Draw dot at each point
            if i % 3 == 0 {
                let dotSize: CGFloat = CGFloat(lineWidth) * 1.5
                let dotRect = CGRect(
                    x: p2.x - dotSize / 2,
                    y: p2.y - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )
                context.fill(Path(ellipseIn: dotRect), with: .color(color))
            }
        }
    }
    
    private func drawHitMarkers(in context: GraphicsContext, size: CGSize) {
        for hit in tracker.hitEvents.suffix(10) { // Show last 10 hits
            let pos = CGPoint(
                x: hit.position.x * size.width,
                y: (1 - hit.position.y) * size.height
            )
            
            // Crosshair
            let crossSize: CGFloat = 15
            var crosshair = Path()
            crosshair.move(to: CGPoint(x: pos.x - crossSize, y: pos.y))
            crosshair.addLine(to: CGPoint(x: pos.x + crossSize, y: pos.y))
            crosshair.move(to: CGPoint(x: pos.x, y: pos.y - crossSize))
            crosshair.addLine(to: CGPoint(x: pos.x, y: pos.y + crossSize))
            
            context.stroke(crosshair, with: .color(.orange), lineWidth: 2)
            
            // Circle
            let circleRect = CGRect(
                x: pos.x - crossSize,
                y: pos.y - crossSize,
                width: crossSize * 2,
                height: crossSize * 2
            )
            context.stroke(Path(ellipseIn: circleRect), with: .color(.orange), lineWidth: 1.5)
            
            // Speed label
            let speedText = Text("\(Int(hit.speed))km/h")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)
            context.draw(speedText, at: CGPoint(x: pos.x, y: pos.y - crossSize - 10))
        }
    }
    
    private func drawBall(at position: CGPoint, radius: CGFloat, in context: GraphicsContext, size: CGSize) {
        let center = CGPoint(
            x: position.x * size.width,
            y: (1 - position.y) * size.height
        )
        let r = max(radius * size.width, 6) // Minimum 6pt radius
        
        // Glow effect
        let glowRect = CGRect(x: center.x - r * 2, y: center.y - r * 2, width: r * 4, height: r * 4)
        context.fill(
            Path(ellipseIn: glowRect),
            with: .color(.yellow.opacity(0.2))
        )
        
        // Ball
        let ballRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        context.fill(
            Path(ellipseIn: ballRect),
            with: .color(.yellow)
        )
        
        // Ball outline
        context.stroke(
            Path(ellipseIn: ballRect),
            with: .color(.white),
            lineWidth: 1.5
        )
        
        // Ball shadow
        let shadowRect = CGRect(x: center.x - r * 0.7, y: center.y + r * 0.5, width: r * 1.4, height: r * 0.6)
        context.fill(
            Path(ellipseIn: shadowRect),
            with: .color(.black.opacity(0.15))
        )
    }
}
