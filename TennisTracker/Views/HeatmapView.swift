import SwiftUI

/// Top-down tennis court heatmap view
struct CourtHeatmapView: View {
    let hitPositions: [CGPoint]
    let landingPoints: [CGPoint]
    
    @State private var selectedMode: HeatmapMode = .hitPositions
    
    enum HeatmapMode: String, CaseIterable {
        case hitPositions = "击球位置"
        case landingPoints = "落点分布"
    }
    
    // Zone statistics
    struct ZoneStat {
        let zone: CourtZone
        var count: Int = 0
        var percentage: Double = 0
    }
    
    private var currentPoints: [CGPoint] {
        selectedMode == .hitPositions ? hitPositions : landingPoints
    }
    
    private var zoneStats: [ZoneStat] {
        var stats: [CourtZone: Int] = [:]
        for zone in CourtZone.allCases { stats[zone] = 0 }
        
        for point in currentPoints {
            let zones = SessionRecord.classifyZones(for: point, isLandingPoint: selectedMode == .landingPoints)
            for zone in zones {
                stats[zone, default: 0] += 1
            }
        }
        
        let total = max(currentPoints.count, 1)
        return CourtZone.allCases.map { zone in
            ZoneStat(zone: zone, count: stats[zone] ?? 0, percentage: Double(stats[zone] ?? 0) / Double(total) * 100)
        }.sorted { $0.count > $1.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Mode picker
            Picker("模式", selection: $selectedMode) {
                ForEach(HeatmapMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            
            HStack(alignment: .top, spacing: 16) {
                // Court with heatmap
                courtView
                    .frame(maxWidth: .infinity)
                
                // Zone stats
                VStack(alignment: .leading, spacing: 6) {
                    Text("区域分布")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    ForEach(zoneStats.filter { $0.count > 0 }, id: \.zone) { stat in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(stat.zone.color)
                                .frame(width: 6, height: 6)
                            Text(stat.zone.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Text("\(Int(stat.percentage))%")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(width: 90)
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
    }
    
    // MARK: - Court View
    
    private var courtView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let courtRect = CGRect(x: w * 0.05, y: h * 0.05, width: w * 0.9, height: h * 0.9)
            
            ZStack {
                // Court background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.10, green: 0.30, blue: 0.12))
                    .frame(width: courtRect.width, height: courtRect.height)
                    .position(x: courtRect.midX, y: courtRect.midY)
                
                // Court lines
                Canvas { context, size in
                    let cr = courtRect
                    
                    // Outer boundary
                    let outer = Path(roundedRect: cr, cornerRadius: 2)
                    context.stroke(outer, with: .color(.white.opacity(0.6)), lineWidth: 1.5)
                    
                    // Net (horizontal center)
                    var net = Path()
                    net.move(to: CGPoint(x: cr.minX, y: cr.midY))
                    net.addLine(to: CGPoint(x: cr.maxX, y: cr.midY))
                    context.stroke(net, with: .color(.white.opacity(0.4)), lineWidth: 1)
                    
                    // Service lines
                    let serviceY1 = cr.minY + cr.height * 0.3
                    let serviceY2 = cr.maxY - cr.height * 0.3
                    let singleX1 = cr.minX + cr.width * 0.1
                    let singleX2 = cr.maxX - cr.width * 0.1
                    
                    var serviceLines = Path()
                    serviceLines.move(to: CGPoint(x: singleX1, y: serviceY1))
                    serviceLines.addLine(to: CGPoint(x: singleX2, y: serviceY1))
                    serviceLines.move(to: CGPoint(x: singleX1, y: serviceY2))
                    serviceLines.addLine(to: CGPoint(x: singleX2, y: serviceY2))
                    context.stroke(serviceLines, with: .color(.white.opacity(0.3)), lineWidth: 1)
                    
                    // Center service line
                    var centerLine = Path()
                    centerLine.move(to: CGPoint(x: cr.midX, y: serviceY1))
                    centerLine.addLine(to: CGPoint(x: cr.midX, y: serviceY2))
                    context.stroke(centerLine, with: .color(.white.opacity(0.3)), lineWidth: 1)
                    
                    // Singles sidelines
                    var singles = Path()
                    singles.move(to: CGPoint(x: singleX1, y: cr.minY))
                    singles.addLine(to: CGPoint(x: singleX1, y: cr.maxY))
                    singles.move(to: CGPoint(x: singleX2, y: cr.minY))
                    singles.addLine(to: CGPoint(x: singleX2, y: cr.maxY))
                    context.stroke(singles, with: .color(.white.opacity(0.25)), lineWidth: 0.8)
                    
                    // Labels
                    let netLabel = Text("网")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                    context.draw(netLabel, at: CGPoint(x: cr.midX, y: cr.midY - 10))
                }
                
                // Heatmap dots
                Canvas { context, size in
                    let points = currentPoints
                    guard !points.isEmpty else { return }
                    
                    for point in points {
                        let x = courtRect.minX + point.x * courtRect.width
                        let y = courtRect.minY + point.y * courtRect.height
                        let dotSize: CGFloat = 16
                        
                        // Glow
                        let glowRect = CGRect(x: x - dotSize * 1.5, y: y - dotSize * 1.5, width: dotSize * 3, height: dotSize * 3)
                        let color = heatmapColor(for: point)
                        context.fill(Path(ellipseIn: glowRect), with: .color(color.opacity(0.15)))
                        
                        // Dot
                        let dotRect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                        context.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(0.6)))
                    }
                }
                
                // Empty state
                if currentPoints.isEmpty {
                    Text("暂无数据")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .aspectRatio(10.97 / 23.77, contentMode: .fit)
    }
    
    private func heatmapColor(for point: CGPoint) -> Color {
        // Distance from center for color variation
        let distFromCenter = sqrt(pow(point.x - 0.5, 2) + pow(point.y - 0.5, 2))
        let t = min(distFromCenter * 2, 1.0)
        
        // Blue-green for center, orange-red for edges
        if t < 0.5 {
            return Color(red: 0.2, green: 0.8, blue: 0.4) // green
        } else {
            return Color(red: 1.0, green: 0.6, blue: 0.2) // orange
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CourtHeatmapView(
            hitPositions: (0..<30).map { _ in CGPoint(x: Double.random(in: 0...1), y: Double.random(in: 0...1)) },
            landingPoints: (0..<20).map { _ in CGPoint(x: Double.random(in: 0...1), y: Double.random(in: 0...1)) }
        )
        .padding()
    }
}
