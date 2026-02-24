//
//  SettingsView.swift
//  EarWords
//
//  设置页面 - 完整版
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = UserSettingsViewModel.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.colorScheme) private var systemColorScheme
    
    @State private var showResetAlert = false
    @State private var showPermissionAlert = false
    @State private var showSyncSuccessToast = false
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - 每日目标
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("每日新词目标")
                                .font(.body)
                            Spacer()
                            Text("\(settings.dailyNewWordsGoal) 词")
                                .font(.subheadline)
                                .foregroundColor(.purple)
                                .fontWeight(.semibold)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(settings.dailyNewWordsGoal) },
                                set: { settings.dailyNewWordsGoal = Int($0) }
                            ),
                            in: 10...50,
                            step: 5
                        ) {
                            Text("新词数量")
                        } minimumValueLabel: {
                            Text("10")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("50")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tint(.purple)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("每日复习上限")
                                .font(.body)
                            Spacer()
                            Text("\(settings.dailyReviewGoal) 词")
                                .font(.subheadline)
                                .foregroundColor(.purple)
                                .fontWeight(.semibold)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(settings.dailyReviewGoal) },
                                set: { settings.dailyReviewGoal = Int($0) }
                            ),
                            in: 10...100,
                            step: 10
                        ) {
                            Text("复习数量")
                        } minimumValueLabel: {
                            Text("10")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tint(.purple)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("学习目标")
                } footer: {
                    Text("建议根据自己的学习时间合理安排目标数量")
                }
                
                // MARK: - 音频设置
                Section {
                    Toggle("自动播放音频", isOn: $settings.audioAutoPlay)
                    
                    Toggle("显示音标", isOn: $settings.showPhonetic)
                    
                    Toggle("显示例句", isOn: $settings.showExample)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("语速")
                            Spacer()
                            Text(String(format: "%.1fx", settings.speechRate))
                                .foregroundColor(.purple)
                                .fontWeight(.semibold)
                        }
                        
                        Slider(
                            value: $settings.speechRate,
                            in: 0.5...1.5,
                            step: 0.1
                        )
                        .tint(.purple)
                        
                        HStack {
                            Text("慢")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("快")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("音频设置")
                }
                
                // MARK: - 提醒设置
                Section {
                    Toggle("启用学习提醒", isOn: $settings.reminderEnabled)
                        .onChange(of: settings.reminderEnabled) { enabled in
                            if enabled {
                                requestNotificationPermission()
                            }
                        }
                    
                    if settings.reminderEnabled {
                        DatePicker(
                            "提醒时间",
                            selection: $settings.reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        
                        if !notificationManager.isAuthorized {
                            Button("开启通知权限") {
                                requestNotificationPermission()
                            }
                            .foregroundColor(.orange)
                        }
                    }
                } header: {
                    Text("学习提醒")
                } footer: {
                    if settings.reminderEnabled {
                        Text("每天会在设定时间提醒您学习单词")
                    }
                }
                
                // MARK: - 外观设置
                Section {
                    // 主题颜色选择
                    NavigationLink(destination: ThemePickerView()) {
                        HStack {
                            Text("主题颜色")
                            Spacer()
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(ThemeManager.shared.gradient)
                                    .frame(width: 16, height: 16)
                                Text(ThemeManager.shared.currentTheme.displayName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Toggle("跟随系统外观", isOn: $settings.useSystemAppearance)
                    
                    if !settings.useSystemAppearance {
                        Picker("外观模式", selection: $settings.forceDarkMode) {
                            Text("浅色").tag(false)
                            Text("深色").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text("外观")
                } footer: {
                    Text("选择你喜欢的主题颜色和外观模式")
                }
                
                // MARK: - iCloud 同步
                Section {
                    Toggle("iCloud 同步", isOn: $settings.iCloudEnabled)
                    
                    Button {
                        settings.triggerSync()
                        withAnimation {
                            showSyncSuccessToast = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showSyncSuccessToast = false
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: settings.syncStatusIcon)
                                .foregroundColor(syncIconColor)
                            Text("立即同步")
                            Spacer()
                            Text(settings.syncStatusDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(settings.syncStatus != .idle && settings.syncStatus != .completed)
                } header: {
                    Text("数据同步")
                } footer: {
                    Text("开启 iCloud 同步可在多设备间同步学习进度")
                }
                
                // MARK: - 数据管理
                Section {
                    Button("重置学习进度", role: .destructive) {
                        showResetAlert = true
                    }
                    
                    NavigationLink(destination: DataExportView()) {
                        Text("导出学习数据")
                    }
                } header: {
                    Text("数据管理")
                }
                
                // MARK: - 关于
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("隐私政策", destination: URL(string: "https://example.com/privacy")!)
                    Link("使用条款", destination: URL(string: "https://example.com/terms")!)
                    
                    Link(destination: URL(string: "https://apps.apple.com/app/id123456789")!) {
                        HStack {
                            Text("评价应用")
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                } header: {
                    Text("关于")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
            .alert("确认重置", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) {
                    DataManager.shared.resetAllProgress()
                }
            } message: {
                Text("这将清除所有学习进度，此操作不可撤销。")
            }
            .alert("需要通知权限", isPresented: $showPermissionAlert) {
                Button("取消", role: .cancel) {
                    settings.reminderEnabled = false
                }
                Button("前往设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("请在系统设置中开启通知权限，以便接收学习提醒。")
            }
            .overlay {
                if showSyncSuccessToast {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("同步已触发")
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color(.systemBackground))
                                .shadow(radius: 10)
                        )
                        .padding(.bottom, 100)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onAppear {
                notificationManager.checkAuthorizationStatus()
            }
        }
    }
    
    // MARK: - 辅助属性
    
    private var syncIconColor: Color {
        switch settings.syncStatus {
        case .idle, .completed:
            return .purple
        case .syncing, .importing, .exporting:
            return .blue
        case .error:
            return .red
        case .disabled:
            return .gray
        }
    }
    
    // MARK: - 方法
    
    private func requestNotificationPermission() {
        Task {
            let granted = await notificationManager.requestAuthorization()
            if !granted {
                await MainActor.run {
                    showPermissionAlert = true
                }
            } else {
                // 更新提醒
                notificationManager.scheduleDailyReminder(
                    at: settings.reminderTime,
                    enabled: settings.reminderEnabled
                )
            }
        }
    }
}

// MARK: - 数据导出视图

struct DataExportView: View {
    @State private var exportData: String = ""
    @State private var showShareSheet = false
    @State private var isLoading = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "doc.text")
                            .font(.title2)
                            .foregroundColor(.purple)
                        VStack(alignment: .leading) {
                            Text("学习数据导出")
                                .font(.headline)
                            Text("包含学习记录、单词掌握情况等数据")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        exportStudyData()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "导出中..." : "导出为 JSON")
                        }
                    }
                    .disabled(isLoading)
                }
                .padding(.vertical, 8)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.bar")
                            .font(.title2)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("学习统计报告")
                                .font(.headline)
                            Text("生成可视化的学习进度报告")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button("生成报告") {
                        generateReport()
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("导出数据")
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [exportData])
        }
    }
    
    private func exportStudyData() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let records = DataManager.shared.fetchStudyRecords(limit: 1000)
            
            let exportDict: [String: Any] = [
                "exportDate": ISO8601DateFormatter().string(from: Date()),
                "appVersion": "1.0.0",
                "records": records.map { record in
                    [
                        "word": record.word,
                        "date": ISO8601DateFormatter().string(from: record.reviewDate),
                        "quality": record.quality,
                        "result": record.result
                    ]
                }
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: exportDict, options: .prettyPrinted),
               let jsonString = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.exportData = jsonString
                    self.isLoading = false
                    self.showShareSheet = true
                }
            }
        }
    }
    
    private func generateReport() {
        // 生成报告逻辑
    }
}

// MARK: - 分享 Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 预览

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
