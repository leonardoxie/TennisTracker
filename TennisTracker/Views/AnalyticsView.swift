import SwiftUI

/// Full analytics dashboard screen
struct AnalyticsView: View {
    let session: SessionRecord?
    let previousSessions: [SessionRecord]
    
    @State private var insights: [Insight] = []
    
    private let insightEngine = InsightEngine()
    
    init(session: SessionRecord? = nil, previousSessions: [SessionRecord] = []) {
        self.session = session
        self.previousSessions = previousSessions
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                if let session = session {
                    // Session summary card
                    sessionSummaryCard(session)
                    
                    // Speed chart
                    if !session.hitEvents.isEmpty {
                        speedChart(session)
                    }
                    
                    // Shot distribution
                    shotDistribution(session)
                    
                    // Court heatmap
                    if !session.hitEvents.isEmpty {
                        courtHeatmapSection(session)
                    }
                    
                    // AI Insights
                    insightSection
                    
                    Spacer(minLength: 40)
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            if let session = session {
                insights = insightEngine.generateInsights(for: session, previousSessions: previousSessions)
            }
        }
    }
    
    // MARK: - Session Summary Card
    
    private func sessionSummaryCard(_ session: SessionRecord) -> some View {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        return VStack(spacing: 12) {
            // Date and duration header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("训练报告")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(formatter.string(from: session.date))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.78, green: 0.90, blue: 0.20))
                        Text(formatDuration(session.duration))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Text("训练时长")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Stats grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                StatCard(icon: "target", value: "\(session.summary.totalHits)", label: "总击球", unit: "次",
                         gradient: [Color(red: 0.10, green: 0.22, blue: 0.12), Color(red: 0.18, green: 0.30, blue: 0.18)])
                StatCard(icon: "speedometer", value: String(format: "%.0f", session.summary.avgSpeed), label: "平均速度", unit: "km/h",
                         gradient: [Color(red: 0.12, green: 0.18, blue: 0.25), Color(red: 0.20, green: 0.28, blue: 0.35)])
                StatCard(icon: "bolt.fill", value: String(format: "%.0f", session.summary.maxSpeed), label: "最高速度", unit: "km/h",
                         gradient: [Color(red: 0.25, green: 0.18, blue: 0.10), Color(red: 0.35, green: 0.25, blue: 0.15)])
                StatCard(icon: "chart.line.uptrend.xyaxis", value: "\(session.hitEvents.count)", label: "有效击球", unit: "次",
                         gradient: [Color(red: 0.18, green: 0.12, blue: 0.22), Color(red: 0.28, green: 0.20, blue: 0.32)])
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    // MARK: - Speed Chart
    
    private func speedChart(_ session: SessionRecord) -> some View {
        let speeds: [(TimeInterval, Double)] = session.hitEvents.map { event in
            (event.timestamp - (session.hitEvents.first?.timestamp ?? 0), event.speed)
        }
        
        return SpeedLineChart(speeds: speeds, title: "速度变化")
    }
    
    // MARK: - Shot Distribution
    
    private func shotDistribution(_ session: SessionRecord) -> some View {
        ShotTypeBarChart(counts: session.summary.hitTypeCounts, title: "击球类型分布")
    }
    
    // MARK: - Court Heatmap
    
    private func courtHeatmapSection(_ session: SessionRecord) -> some View {
        CourtHeatmapView(
            hitPositions: session.hitEvents.map(\.position),
            landingPoints: session.ballLandingPoints.map(\.position)
        )
    }
    
    // MARK: - Insights
    
    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.78, green: 0.90, blue: 0.20))
                Text("AI 分析")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            if insights.isEmpty {
                Text("分析中...")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ForEach(insights) { insight in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: insight.icon)
                            .font(.system(size: 16))
                            .foregroundColor(insightColor(insight.severity))
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(insight.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text(insight.detail)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(nil)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(insightColor(insight.severity).opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(insightColor(insight.severity).opacity(0.15), lineWidth: 1)
                    )
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
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.2))
            Text("暂无训练数据")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            Text("开始一次训练后，这里将显示详细的数据分析")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func insightColor(_ severity: Insight.Severity) -> Color {
        switch severity {
        case .tip: return .blue
        case .warning: return .orange
        case .good: return Color(red: 0.78, green: 0.90, blue: 0.20)
        }
    }
}

#Preview {
    AnalyticsView()
}
