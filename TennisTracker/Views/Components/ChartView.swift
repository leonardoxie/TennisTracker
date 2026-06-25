import SwiftUI

// MARK: - Speed Line Chart

struct SpeedLineChart: View {
    let speeds: [(time: TimeInterval, speed: Double)]
    let title: String
    
    @State private var animationProgress: CGFloat = 0
    
    var maxSpeed: Double {
        speeds.map(\.speed).max() ?? 1
    }
    
    private func formatTime(_ t: TimeInterval) -> String {
        let mins = Int(t) / 60
        let secs = Int(t) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private var chartCanvas: some View {
        Canvas { context, size in
            guard speeds.count >= 2 else { return }
            
            let chartRect = CGRect(x: 35, y: 8, width: size.width - 45, height: size.height - 30)
            let maxY = maxSpeed * 1.1
            let maxX = speeds.last!.time
            let accentColor = Color(red: 0.78, green: 0.90, blue: 0.20)
            
            // Grid lines
            for i in 0...4 {
                let y = chartRect.origin.y + chartRect.height * CGFloat(i) / 4.0
                var gridPath = Path()
                gridPath.move(to: CGPoint(x: chartRect.origin.x, y: y))
                gridPath.addLine(to: CGPoint(x: chartRect.maxX, y: y))
                context.stroke(gridPath, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
                
                let speedValue = maxY * (1.0 - Double(i) / 4.0)
                let label = Text("\(Int(speedValue))")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                context.draw(label, at: CGPoint(x: 15, y: y))
            }
            
            // Build path
            var path = Path()
            var fillPath = Path()
            var firstPoint = true
            let pointCount = Int(CGFloat(speeds.count) * animationProgress)
            guard pointCount >= 2 else { return }
            
            for i in 0..<pointCount {
                let s = speeds[i]
                let x = chartRect.origin.x + CGFloat(s.time / maxX) * chartRect.width
                let y = chartRect.origin.y + CGFloat(1.0 - s.speed / maxY) * chartRect.height
                let point = CGPoint(x: x, y: y)
                if firstPoint {
                    path.move(to: point)
                    fillPath.move(to: CGPoint(x: x, y: chartRect.maxY))
                    fillPath.addLine(to: point)
                    firstPoint = false
                } else {
                    path.addLine(to: point)
                    fillPath.addLine(to: point)
                }
            }
            
            // Fill gradient
            let lastSpeed = speeds.prefix(pointCount).last
            if let lastS = lastSpeed {
                let lastX = chartRect.origin.x + CGFloat(lastS.time / maxX) * chartRect.width
                fillPath.addLine(to: CGPoint(x: lastX, y: chartRect.maxY))
                fillPath.closeSubpath()
                context.fill(fillPath, with: .color(accentColor.opacity(0.08)))
            }
            
            // Line
            context.stroke(path, with: .color(accentColor), lineWidth: 2)
            
            // Data points
            let step = max(1, pointCount / 12)
            for i in stride(from: 0, to: pointCount, by: step) {
                let s = speeds[i]
                let x = chartRect.origin.x + CGFloat(s.time / maxX) * chartRect.width
                let y = chartRect.origin.y + CGFloat(1.0 - s.speed / maxY) * chartRect.height
                let dotRect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: dotRect), with: .color(accentColor))
            }
            
            // X-axis time labels
            let xSteps = min(4, speeds.count - 1)
            for i in 0...xSteps {
                let t = maxX * Double(i) / Double(xSteps)
                let x = chartRect.origin.x + CGFloat(Double(i) / Double(xSteps)) * chartRect.width
                let label = Text(formatTime(t))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                context.draw(label, at: CGPoint(x: x, y: chartRect.maxY + 14))
            }
        }
        .frame(height: 180)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            chartCanvas
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Shot Type Bar Chart

struct ShotTypeBarChart: View {
    let counts: [HitType: Int]
    let title: String
    
    @State private var animationProgress: CGFloat = 0
    
    private var sortedTypes: [(HitType, Int)] {
        let all: [(HitType, Int)] = HitType.allCases.compactMap { type in
            let count = counts[type] ?? 0
            return count > 0 ? (type, count) : nil
        }
        return all.sorted { $0.1 > $1.1 }
    }
    
    private var maxCount: Int {
        sortedTypes.map(\.1).max() ?? 1
    }
    
    private var totalCount: Int {
        sortedTypes.map(\.1).reduce(0, +)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            
            if sortedTypes.isEmpty {
                Text("暂无数据")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ForEach(sortedTypes, id: \.0) { type, count in
                    HStack(spacing: 10) {
                        // Type label
                        HStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 11))
                                .foregroundColor(type.color)
                                .frame(width: 16)
                            Text(type.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 32, alignment: .leading)
                        }
                        
                        // Bar
                        GeometryReader { geo in
                            let barWidth = CGFloat(count) / CGFloat(maxCount) * geo.size.width
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.05))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [type.color.opacity(0.8), type.color.opacity(0.4)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: barWidth * animationProgress)
                            }
                        }
                        .frame(height: 14)
                        
                        // Count and percentage
                        Text("\(count)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 28, alignment: .trailing)
                        
                        Text(totalCount > 0 ? "\(Int(Double(count) / Double(totalCount) * 100))%" : "0%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 32, alignment: .trailing)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animationProgress = 1.0
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 16) {
            SpeedLineChart(
                speeds: (0..<20).map { (TimeInterval($0 * 3), Double.random(in: 40...150)) },
                title: "速度变化"
            )
            ShotTypeBarChart(
                counts: [.forehand: 15, .backhand: 8, .serve: 5, .volley: 3],
                title: "击球类型分布"
            )
        }
        .padding()
    }
}
