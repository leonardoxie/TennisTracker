import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var sessionManager: WatchSessionManager
    @State private var showingSessionDetail = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Connection Status
                    connectionStatusView
                    
                    // Session Controls
                    sessionControlView
                    
                    // Live Stats (when session active)
                    if sessionManager.isSessionActive {
                        liveStatsView
                    }
                    
                    // Quick Stats
                    quickStatsView
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("TennisTracker")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Connection Status
    
    private var connectionStatusView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(sessionManager.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(sessionManager.isConnected ? "已连接 iPhone" : "未连接")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Session Controls
    
    private var sessionControlView: some View {
        VStack(spacing: 8) {
            if sessionManager.isSessionActive {
                // Stop Button
                Button(action: {
                    sessionManager.sendStopSession()
                }) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("停止训练")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .background(Color.red.opacity(0.8))
                .cornerRadius(12)
                .buttonStyle(.plain)
            } else {
                // Start Button
                Button(action: {
                    sessionManager.sendStartSession()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("开始训练")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .background(Color.green.opacity(0.8))
                .cornerRadius(12)
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Live Stats
    
    private var liveStatsView: some View {
        VStack(spacing: 8) {
            Text("实时数据")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                WatchStatCard(
                    icon: "clock.fill",
                    value: formatDuration(sessionManager.sessionDuration),
                    label: "时长",
                    color: .blue
                )
                
                WatchStatCard(
                    icon: "circle.fill",
                    value: "\(sessionManager.ballCount)",
                    label: "击球",
                    color: .orange
                )
                
                WatchStatCard(
                    icon: "heart.fill",
                    value: "\(Int(sessionManager.heartRate))",
                    label: "心率 BPM",
                    color: .red
                )
                
                WatchStatCard(
                    icon: "flame.fill",
                    value: "\(Int(sessionManager.calories))",
                    label: "卡路里",
                    color: .yellow
                )
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.15))
        .cornerRadius(12)
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今日概览")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Label("\(sessionManager.rallyCount)", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                Spacer()
                Label("得分 \(sessionManager.currentScore)", systemImage: "star.fill")
                    .font(.caption)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Stat Card

struct WatchStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(value)
                .font(.system(.body, design: .rounded).bold())
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
}

#Preview {
    WatchContentView()
        .environmentObject(WatchSessionManager.shared)
}
