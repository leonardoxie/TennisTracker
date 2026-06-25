import Foundation

// MARK: - Insight Model

struct Insight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let severity: Severity
    
    enum Severity {
        case tip, warning, good
    }
}

// MARK: - Insight Engine

class InsightEngine {
    
    /// Generate insights for a single session
    func generateInsights(for session: SessionRecord, previousSessions: [SessionRecord] = []) -> [Insight] {
        var insights: [Insight] = []
        
        // Shot distribution analysis
        if let distInsight = analyzeShotDistribution(session) {
            insights.append(distInsight)
        }
        
        // Speed consistency
        if let speedInsight = analyzeSpeedConsistency(session) {
            insights.append(speedInsight)
        }
        
        // Court coverage
        if let coverageInsight = analyzeCourtCoverage(session) {
            insights.append(coverageInsight)
        }
        
        // Fatigue detection
        if let fatigueInsight = analyzeFatigue(session) {
            insights.append(fatigueInsight)
        }
        
        // Improvement tracking
        if let prevSession = previousSessions.first,
           let improvementInsight = analyzeImprovement(current: session, previous: prevSession) {
            insights.append(improvementInsight)
        }
        
        // If no insights, add a generic one
        if insights.isEmpty {
            insights.append(Insight(
                icon: "sparkles",
                title: "训练完成",
                detail: "继续保持训练节奏，逐步提升技术水平！",
                severity: .good
            ))
        }
        
        return insights
    }
    
    // MARK: - Analysis Methods
    
    private func analyzeShotDistribution(_ session: SessionRecord) -> Insight? {
        let summary = session.summary
        let total = summary.totalHits
        guard total >= 5 else { return nil }
        
        let fhRatio = Double(summary.forehandCount) / Double(total)
        let bhRatio = Double(summary.backhandCount) / Double(total)
        
        // Too many forehands
        if fhRatio > 0.75 && summary.backhandCount > 0 {
            return Insight(
                icon: "arrow.triangle.2.circlepath",
                title: "正反手比例失衡",
                detail: "你的正手击球占\(Int(fhRatio * 100))%，反手较少。建议增加反手训练，提高全面性。",
                severity: .warning
            )
        }
        
        // Very few backhands
        if bhRatio < 0.15 && total > 10 {
            return Insight(
                icon: "arrow.left.arrow.right",
                title: "反手练习不足",
                detail: "反手仅占\(Int(bhRatio * 100))%，建议专门练习反手击球，平衡左右手技术。",
                severity: .warning
            )
        }
        
        // Good balance
        if abs(fhRatio - bhRatio) < 0.2 && total > 10 {
            return Insight(
                icon: "checkmark.seal.fill",
                title: "正反手均衡",
                detail: "你的正反手比例接近，技术发展均衡，继续保持！",
                severity: .good
            )
        }
        
        return nil
    }
    
    private func analyzeSpeedConsistency(_ session: SessionRecord) -> Insight? {
        let speeds = session.hitEvents.map(\.speed)
        guard speeds.count >= 5 else { return nil }
        
        let avg = speeds.reduce(0, +) / Double(speeds.count)
        let variance = speeds.reduce(0) { $0 + ($1 - avg) * ($1 - avg) } / Double(speeds.count)
        let stdDev = sqrt(variance)
        let coefficientOfVariation = stdDev / avg
        
        if coefficientOfVariation > 0.35 {
            return Insight(
                icon: "waveform.path.ecg",
                title: "速度波动较大",
                detail: "速度标准差为\(Int(stdDev))km/h，波动较大（CV=\(Int(coefficientOfVariation*100))%）。建议保持稳定的击球节奏和发力方式。",
                severity: .warning
            )
        }
        
        if coefficientOfVariation < 0.15 {
            return Insight(
                icon: "metronome.fill",
                title: "击球稳定性优秀",
                detail: "速度变化系数仅\(Int(coefficientOfVariation*100))%，击球节奏非常稳定，表现优秀！",
                severity: .good
            )
        }
        
        return nil
    }
    
    private func analyzeCourtCoverage(_ session: SessionRecord) -> Insight? {
        let positions = session.hitEvents.map(\.position)
        guard positions.count >= 5 else { return nil }
        
        // Calculate X spread
        let xValues = positions.map(\.x)
        let xMin = xValues.min() ?? 0
        let xMax = xValues.max() ?? 1
        let xSpread = xMax - xMin
        
        // Check if too narrow
        if xSpread < 0.3 {
            return Insight(
                icon: "arrow.left.and.right",
                title: "场地覆盖不足",
                detail: "你的击球集中在\(Int(xSpread * 100))%的宽度范围，建议增加变线练习，扩大场地覆盖。",
                severity: .tip
            )
        }
        
        // Good coverage
        if xSpread > 0.6 {
            return Insight(
                icon: "rectangle.expand.vertical",
                title: "场地覆盖良好",
                detail: "你的击球覆盖了场地\(Int(xSpread * 100))%的宽度，变线意识出色！",
                severity: .good
            )
        }
        
        return nil
    }
    
    private func analyzeFatigue(_ session: SessionRecord) -> Insight? {
        let events = session.hitEvents
        guard events.count >= 10 else { return nil }
        
        // Split into first half and second half
        let mid = events.count / 2
        let firstHalfSpeeds = events.prefix(mid).map(\.speed)
        let secondHalfSpeeds = events.suffix(mid).map(\.speed)
        
        let firstAvg = firstHalfSpeeds.reduce(0, +) / Double(firstHalfSpeeds.count)
        let secondAvg = secondHalfSpeeds.reduce(0, +) / Double(secondHalfSpeeds.count)
        
        let speedDrop = (firstAvg - secondAvg) / firstAvg
        
        if speedDrop > 0.15 {
            return Insight(
                icon: "battery.25percent",
                title: "后半段速度下降",
                detail: "后半段平均速度下降了\(Int(speedDrop * 100))%，可能是体能下降。建议加强体能训练，或适当调整训练强度。",
                severity: .warning
            )
        }
        
        // Check if speed actually improved
        if speedDrop < -0.1 {
            return Insight(
                icon: "flame.fill",
                title: "越打越热",
                detail: "后半段速度提升了\(Int(abs(speedDrop) * 100))%，状态越来越好，热身效果明显！",
                severity: .good
            )
        }
        
        return nil
    }
    
    private func analyzeImprovement(current: SessionRecord, previous: SessionRecord) -> Insight? {
        let currentAvg = current.summary.avgSpeed
        let previousAvg = previous.summary.avgSpeed
        guard previousAvg > 0, currentAvg > 0 else { return nil }
        
        let change = (currentAvg - previousAvg) / previousAvg
        
        if change > 0.1 {
            return Insight(
                icon: "arrow.up.circle.fill",
                title: "速度提升",
                detail: "与上次训练相比，平均速度提升了\(Int(change * 100))%，进步明显！",
                severity: .good
            )
        }
        
        if change < -0.1 {
            return Insight(
                icon: "arrow.down.circle.fill",
                title: "速度下降",
                detail: "平均速度较上次下降了\(Int(abs(change) * 100))%，可能与训练强度或状态有关。",
                severity: .warning
            )
        }
        
        // Hit count comparison
        let hitChange = current.summary.totalHits - previous.summary.totalHits
        if hitChange > 5 {
            return Insight(
                icon: "plus.circle.fill",
                title: "训练量增加",
                detail: "本次击球\(current.summary.totalHits)次，比上次多\(hitChange)次，训练量在增加！",
                severity: .good
            )
        }
        
        return nil
    }
}
