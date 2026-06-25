import SwiftUI

/// Custom tab bar with 4 tabs: 训练, 数据, 历史, 设置
struct MainTabView: View {
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var trajectoryTracker = TrajectoryTracker()
    @State private var selectedTab: Tab = .training
    
    enum Tab: String, CaseIterable {
        case training = "训练"
        case analytics = "数据"
        case history = "历史"
        case settings = "设置"
        
        var icon: String {
            switch self {
            case .training: return "figure.tennis"
            case .analytics: return "chart.bar.fill"
            case .history: return "clock.arrow.circlepath"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .training:
                    ContentView(
                        sessionStore: sessionStore,
                        cameraManager: cameraManager,
                        trajectoryTracker: trajectoryTracker
                    )
                case .analytics:
                    AnalyticsWrapperView(sessionStore: sessionStore)
                case .history:
                    SessionHistoryView(sessionStore: sessionStore)
                case .settings:
                    SettingsView(sessionStore: sessionStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Custom tab bar
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
    }
    
    // MARK: - Custom Tab Bar
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: selectedTab == tab ? 18 : 16, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundColor(selectedTab == tab ? Color(red: 0.78, green: 0.90, blue: 0.20) : .white.opacity(0.4))
                        
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium, design: .rounded))
                            .foregroundColor(selectedTab == tab ? Color(red: 0.78, green: 0.90, blue: 0.20) : .white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        VStack {
                            if selectedTab == tab {
                                Spacer()
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(red: 0.78, green: 0.90, blue: 0.20))
                                    .frame(width: 20, height: 2)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, max(8, 0))
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: -5)
        )
    }
}

// MARK: - Analytics Wrapper (shows latest session or empty state)

struct AnalyticsWrapperView: View {
    @ObservedObject var sessionStore: SessionStore
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let latest = sessionStore.sessions.first {
                    AnalyticsView(
                        session: latest,
                        previousSessions: Array(sessionStore.sessions.dropFirst())
                    )
                } else {
                    AnalyticsView(session: nil)
                }
            }
            .navigationTitle("数据分析")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
