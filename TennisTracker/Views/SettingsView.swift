import SwiftUI

/// Settings screen
struct SettingsView: View {
    @AppStorage("confidenceThreshold") private var confidenceThreshold: Double = 0.35
    @AppStorage("detectionMode") private var detectionMode: Int = 0  // 0=auto, 1=coreML, 2=HSV
    @AppStorage("courtOrientation") private var courtOrientation: Int = 0  // 0=portrait, 1=landscape
    @AppStorage("showCourtGuide") private var showCourtGuide: Bool = true
    @AppStorage("showStats") private var showStats: Bool = true
    @AppStorage("speedScaleFactor") private var speedScaleFactor: Double = 800
    
    @ObservedObject var sessionStore: SessionStore
    @State private var showClearAlert = false
    @State private var showExportSheet = false
    @State private var exportData: Data?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                List {
                    // Detection settings
                    Section {
                        // Confidence threshold
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("检测置信度")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(String(format: "%.0f%%", confidenceThreshold * 100))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(red: 0.78, green: 0.90, blue: 0.20))
                            }
                            Slider(value: $confidenceThreshold, in: 0.15...0.70, step: 0.05)
                                .tint(Color(red: 0.78, green: 0.90, blue: 0.20))
                            HStack {
                                Text("低")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                                Spacer()
                                Text("高")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                        
                        // Speed scale factor
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("速度系数")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Text(String(format: "%.0f", speedScaleFactor))
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(red: 0.78, green: 0.90, blue: 0.20))
                            }
                            Slider(value: $speedScaleFactor, in: 400...1500, step: 50)
                                .tint(Color(red: 0.78, green: 0.90, blue: 0.20))
                            Text("调整归一化速度到km/h的转换系数")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                    } header: {
                        Label("检测设置", systemImage: "eye.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // Display settings
                    Section {
                        Toggle(isOn: $showCourtGuide) {
                            HStack {
                                Image(systemName: "rectangle.and.hand.point.up.left")
                                    .foregroundColor(.green)
                                    .frame(width: 24)
                                Text("显示球场标线")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .tint(Color(red: 0.78, green: 0.90, blue: 0.20))
                        .listRowBackground(Color.white.opacity(0.04))
                        
                        Toggle(isOn: $showStats) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text("显示实时统计")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .tint(Color(red: 0.78, green: 0.90, blue: 0.20))
                        .listRowBackground(Color.white.opacity(0.04))
                    } header: {
                        Label("显示", systemImage: "paintbrush.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // Detection mode
                    Section {
                        Picker(selection: $detectionMode, label:
                            HStack {
                                Image(systemName: "cpu")
                                    .foregroundColor(.purple)
                                    .frame(width: 24)
                                Text("检测模式")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        ) {
                            Text("自动").tag(0)
                            Text("Core ML").tag(1)
                            Text("HSV颜色").tag(2)
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                        .listRowBackground(Color.white.opacity(0.04))
                    } header: {
                        Label("高级", systemImage: "gearshape.2.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // Data management
                    Section {
                        HStack {
                            Image(systemName: "number")
                                .foregroundColor(.cyan)
                                .frame(width: 24)
                            Text("训练记录")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(sessionStore.sessions.count) 条")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                        
                        Button {
                            showExportSheet = true
                            exportData = sessionStore.exportAll()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.green)
                                    .frame(width: 24)
                                Text("导出数据")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                        
                        Button {
                            showClearAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                Text("清除所有数据")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.red)
                            }
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                    } header: {
                        Label("数据管理", systemImage: "externaldrive.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    // About
                    Section {
                        HStack {
                            Image(systemName: "tennisball.fill")
                                .foregroundColor(Color(red: 0.78, green: 0.90, blue: 0.20))
                                .frame(width: 24)
                            Text("TennisTracker")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("v1.0.0")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("技术栈")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("YOLOv8 + Kalman")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .listRowBackground(Color.white.opacity(0.04))
                    } header: {
                        Label("关于", systemImage: "info.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("确认清除", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) { }
            Button("清除全部", role: .destructive) {
                sessionStore.deleteAll()
            }
        } message: {
            Text("确定要删除所有训练数据吗？此操作无法撤销。")
        }
        .sheet(isPresented: $showExportSheet) {
            if let data = exportData {
                ShareSheet(items: [data])
            }
        }
    }
}

// MARK: - Share Sheet (UIKit bridge)

import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiView: UIActivityViewController, context: Context) {}
}
