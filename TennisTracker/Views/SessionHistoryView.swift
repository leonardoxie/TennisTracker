import SwiftUI

/// List of past training sessions
struct SessionHistoryView: View {
    @ObservedObject var sessionStore: SessionStore
    
    @State private var selectedSession: SessionRecord?
    @State private var showDeleteAlert = false
    @State private var sessionToDelete: SessionRecord?
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if sessionStore.sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("训练历史")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $selectedSession) { session in
            NavigationStack {
                AnalyticsView(
                    session: session,
                    previousSessions: previousSessions(before: session)
                )
                .navigationTitle("训练详情")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("关闭") {
                            selectedSession = nil
                        }
                    }
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let session = sessionToDelete {
                    sessionStore.delete(session)
                }
            }
        } message: {
            Text("确定要删除这条训练记录吗？此操作无法撤销。")
        }
    }
    
    // MARK: - Session List
    
    private var sessionList: some View {
        List {
            // Summary header
            Section {
                summaryHeader
                    .listRowBackground(Color.white.opacity(0.04))
            }
            
            // Sessions
            Section {
                ForEach(sessionStore.sessions) { session in
                    sessionRow(session)
                        .listRowBackground(Color.white.opacity(0.04))
                        .onTapGesture {
                            selectedSession = session
                        }
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        sessionToDelete = sessionStore.sessions[index]
                        showDeleteAlert = true
                    }
                }
            } header: {
                Text("记录")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Summary Header
    
    private var summaryHeader: some View {
        let totalSessions = sessionStore.sessions.count
        let totalHits = sessionStore.sessions.reduce(0) { $0 + $1.summary.totalHits }
        let totalDuration = sessionStore.sessions.reduce(0.0) { $0 + $1.duration }
        let avgSpeed = sessionStore.sessions.isEmpty ? 0 :
            sessionStore.sessions.reduce(0.0) { $0 + $1.summary.avgSpeed } / Double(sessionStore.sessions.count)
        
        return HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("\(totalSessions)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("训练次数")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .background(Color.white.opacity(0.1))
                .frame(height: 30)
            
            VStack(spacing: 2) {
                Text(formatTotalDuration(totalDuration))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("总时长")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .background(Color.white.opacity(0.1))
                .frame(height: 30)
            
            VStack(spacing: 2) {
                Text("\(totalHits)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("总击球")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .background(Color.white.opacity(0.1))
                .frame(height: 30)
            
            VStack(spacing: 2) {
                Text("\(Int(avgSpeed))")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("均速km/h")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Session Row
    
    private func sessionRow(_ session: SessionRecord) -> some View {
        HStack(spacing: 12) {
            // Date column
            VStack(alignment: .leading, spacing: 4) {
                Text(dateFormatter.string(from: session.date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(formatDuration(session.duration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(session.summary.totalHits)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("次")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                HStack(spacing: 4) {
                    Text(String(format: "%.0f", session.summary.avgSpeed))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(red: 0.78, green: 0.90, blue: 0.20))
                    Text("km/h")
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.2))
            Text("暂无训练记录")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            Text("完成一次训练后，记录将显示在这里")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        if mins > 0 {
            return String(format: "%d分%d秒", mins, secs)
        }
        return String(format: "%d秒", secs)
    }
    
    private func formatTotalDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let mins = (Int(duration) % 3600) / 60
        if hours > 0 {
            return String(format: "%dh%dm", hours, mins)
        }
        return String(format: "%dm", mins)
    }
    
    private func previousSessions(before session: SessionRecord) -> [SessionRecord] {
        sessionStore.sessions.filter { $0.date < session.date }
    }
}
