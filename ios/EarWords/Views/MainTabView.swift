//
//  MainTabView.swift
//  EarWords
//
//  主 Tab 框架
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 学习 Tab
            StudyView()
                .tabItem {
                    Label("学习", systemImage: "book.fill")
                }
                .tag(0)
            
            // 磨耳朵 Tab
            AudioReviewView()
                .tabItem {
                    Label("磨耳朵", systemImage: "headphones")
                }
                .tag(1)
            
            // 统计 Tab
            StatisticsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar.fill")
                }
                .tag(2)
            
            // 词库 Tab
            WordListView()
                .tabItem {
                    Label("词库", systemImage: "list.bullet")
                }
                .tag(3)
            
            // 设置 Tab
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .accentColor(.purple)
        .environmentObject(dataManager)
    }
}

// MARK: - 词库列表视图

struct WordListView: View {
    @State private var searchText = ""
    @State private var selectedChapter: String?
    @State private var words: [WordEntity] = []
    
    let chapters = [
        "01_自然地理", "02_植物研究", "03_动物保护", "04_太空探索",
        "05_学校教育", "06_科技发明", "07_文化历史", "08_语言演化",
        "09_娱乐运动", "10_物品材料", "11_时尚潮流", "12_饮食健康",
        "13_建筑场所", "14_交通旅行", "15_国家政府", "16_社会经济",
        "17_法律法规", "18_沙场争锋", "19_社会角色", "20_行为动作",
        "21_身心健康", "22_时间日期"
    ]
    
    var body: some View {
        NavigationView {
            List {
                // 搜索栏
                SearchBar(text: $searchText)
                
                // 章节选择
                Section("按章节") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ChapterChip(
                                title: "全部",
                                isSelected: selectedChapter == nil
                            ) {
                                selectedChapter = nil
                            }
                            
                            ForEach(chapters, id: \.self) { chapter in
                                ChapterChip(
                                    title: chapter,
                                    isSelected: selectedChapter == chapter
                                ) {
                                    selectedChapter = chapter
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // 单词列表
                Section("单词列表") {
                    ForEach(words.prefix(20)) { word in
                        WordListRow(word: word)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("词库")
            .searchable(text: $searchText, prompt: "搜索单词")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索单词", text: $text)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ChapterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var displayTitle: String {
        if title == "全部" { return title }
        return String(title.dropFirst(3)) // 去掉 "01_" 前缀
    }
    
    var body: some View {
        Button(action: action) {
            Text(displayTitle)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.purple : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct WordListRow: View {
    let word: WordEntity
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(word.word)
                    .font(.headline)
                
                if let phonetic = word.phonetic, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(word.meaning.prefix(10) + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                StatusBadge(status: word.status)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: String
    
    var color: Color {
        switch status {
        case "new": return .gray
        case "learning": return .blue
        case "mastered": return .green
        default: return .gray
        }
    }
    
    var label: String {
        switch status {
        case "new": return "未学习"
        case "learning": return "学习中"
        case "mastered": return "已掌握"
        default: return status
        }
    }
    
    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - 设置视图

struct SettingsView: View {
    @StateObject private var settings = UserSettings.defaultSettings()
    @State private var showResetAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // 学习设置
                Section("每日目标") {
                    Stepper("新单词: \(settings.dailyNewWordsGoal)", 
                           value: $settings.dailyNewWordsGoal, in: 5...50)
                    Stepper("复习单词: \(settings.dailyReviewGoal)", 
                           value: $settings.dailyReviewGoal, in: 10...100)
                }
                
                // 播放设置
                Section("音频设置") {
                    Toggle("自动播放音频", isOn: $settings.audioAutoPlay)
                    Toggle("显示音标", isOn: $settings.showPhonetic)
                    Toggle("显示例句", isOn: $settings.showExample)
                    
                    VStack(alignment: .leading) {
                        Text("语速")
                            .font(.subheadline)
                        Slider(value: $settings.speechRate, in: 0.5...1.0)
                        HStack {
                            Text("慢")
                            Spacer()
                            Text("快")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                // 提醒设置
                Section("学习提醒") {
                    Toggle("启用提醒", isOn: $settings.reminderEnabled)
                    if settings.reminderEnabled {
                        DatePicker("提醒时间", selection: Binding(
                            get: { settings.reminderTime ?? Date() },
                            set: { settings.reminderTime = $0 }
                        ), displayedComponents: .hourAndMinute)
                    }
                }
                
                // 同步设置
                Section("同步") {
                    Toggle("iCloud 同步", isOn: $settings.iCloudEnabled)
                    Button("立即同步") {
                        // 触发同步
                    }
                }
                
                // 数据管理
                Section("数据管理") {
                    Button("重置学习进度", role: .destructive) {
                        showResetAlert = true
                    }
                    
                    Button("导出学习数据") {
                        // 导出数据
                    }
                }
                
                // 关于
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("隐私政策", destination: URL(string: "https://example.com/privacy")!)
                    Link("使用条款", destination: URL(string: "https://example.com/terms")!)
                }
            }
            .navigationTitle("设置")
            .alert("确认重置", isPresented: $showResetAlert) {
                Button("取消", role: .cancel) {}
                Button("重置", role: .destructive) {
                    DataManager.shared.resetAllProgress()
                }
            } message: {
                Text("这将清除所有学习进度，此操作不可撤销。")
            }
        }
    }
}

// MARK: - UserSettings

class UserSettings: ObservableObject {
    @Published var dailyNewWordsGoal: Int = 20
    @Published var dailyReviewGoal: Int = 50
    @Published var audioAutoPlay: Bool = true
    @Published var showPhonetic: Bool = true
    @Published var showExample: Bool = false
    @Published var speechRate: Double = 0.8
    @Published var reminderEnabled: Bool = true
    @Published var reminderTime: Date?
    @Published var iCloudEnabled: Bool = true
    
    static func defaultSettings() -> UserSettings {
        return UserSettings()
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
