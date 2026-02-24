//
//  LocalizedViews.swift
//  EarWords
//
//  Refactored Views using NSLocalizedString
//  This file provides examples of how to update existing views for localization
//  Created: 2026-02-24
//

import SwiftUI

// MARK: - Example: MainTabView (Localized)
// Original: Views/MainTabView.swift

struct LocalizedMainTabView: View {
    @StateObject private var dataManager = DataManager.shared
    @Binding var selectedTab: Int
    
    init(selectedTab: Binding<Int> = .constant(0)) {
        self._selectedTab = selectedTab
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            StudyView()
                .tabItem {
                    Label(NSLocalizedString("tab.study", comment: "Study tab"), 
                          systemImage: "book.fill")
                }
                .tag(0)
            
            AudioReviewView()
                .tabItem {
                    Label(NSLocalizedString("tab.audio", comment: "Audio review tab"), 
                          systemImage: "headphones")
                }
                .tag(1)
            
            StatisticsView()
                .tabItem {
                    Label(NSLocalizedString("tab.statistics", comment: "Statistics tab"), 
                          systemImage: "chart.bar.fill")
                }
                .tag(2)
            
            ChapterListView()
                .tabItem {
                    Label(NSLocalizedString("tab.vocabulary", comment: "Vocabulary tab"), 
                          systemImage: "books.vertical.fill")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label(NSLocalizedString("tab.settings", comment: "Settings tab"), 
                          systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .accentColor(ThemeManager.shared.primary)
        .environmentObject(dataManager)
    }
}

// MARK: - Example: StatusBadge (Localized)
// Original: MainTabView.swift - StatusBadge

struct LocalizedStatusBadge: View {
    let status: String
    
    var color: Color {
        switch status {
        case "new": return .gray
        case "learning": return .blue
        case "mastered": return .green
        default: return .gray
        }
    }
    
    var localizedLabel: String {
        switch status {
        case "new":
            return NSLocalizedString("status.new", comment: "New word status")
        case "learning":
            return NSLocalizedString("status.learning", comment: "Learning status")
        case "mastered":
            return NSLocalizedString("status.mastered", comment: "Mastered status")
        default:
            return status
        }
    }
    
    var body: some View {
        Text(localizedLabel)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Example: EmptyStudyView (Localized)
// Original: StudyView.swift - EmptyStudyView

struct LocalizedEmptyStudyView: View {
    let onLoad: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(NSLocalizedString("study.empty.title", comment: "Empty study title"))
                .font(.title2.weight(.bold))
            
            Text(NSLocalizedString("study.empty.message", comment: "Empty study message"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onLoad) {
                Text(NSLocalizedString("study.empty.button", comment: "Refresh button"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

// MARK: - Example: StudyCompleteView (Localized)
// Original: StudyView.swift - StudyCompleteView

struct LocalizedStudyCompleteView: View {
    let stats: TodayStudyStats
    let onContinue: () -> Void
    let onFinish: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 顶部庆祝图标
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                    }
                    
                    Text(NSLocalizedString("study.complete.title", comment: "Study complete title"))
                        .font(.largeTitle.weight(.bold))
                    
                    Text(NSLocalizedString("study.complete.subtitle", comment: "Study complete subtitle"))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // 今日统计卡片 - 使用本地化键
                VStack(spacing: 16) {
                    Text(NSLocalizedString("statistics.today.overview", comment: "Today's overview"))
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 16) {
                        LocalizedStatCard(
                            titleKey: "stats.newWords",
                            value: "\(stats.newWordsCount)",
                            icon: "sparkles",
                            color: .blue
                        )
                        
                        LocalizedStatCard(
                            titleKey: "stats.reviewWords",
                            value: "\(stats.reviewWordsCount)",
                            icon: "arrow.clockwise",
                            color: .orange
                        )
                    }
                    
                    HStack(spacing: 16) {
                        LocalizedStatCard(
                            titleKey: "stats.correct",
                            value: "\(stats.correctCount)",
                            icon: "checkmark.circle",
                            color: .green
                        )
                        
                        LocalizedStatCard(
                            titleKey: "stats.accuracy",
                            value: String(format: "%.0f%%", stats.accuracy * 100),
                            icon: "percent",
                            color: .purple
                        )
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                
                // 连续打卡
                if stats.streakDays > 0 {
                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: NSLocalizedString("stats.streakDays", comment: "Streak days"), stats.streakDays))
                                .font(.headline)
                            Text(NSLocalizedString("stats.streakKeep", comment: "Keep it up"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(16)
                }
                
                // 明日预览
                if !stats.tomorrowPreview.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("stats.tomorrowPreview", comment: "Tomorrow preview"))
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("\(NSLocalizedString("stats.tomorrow.review", comment: "Review")): \(stats.tomorrowPreview[safe: 0] ?? 0)")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            
                            Divider()
                                .frame(height: 16)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("\(NSLocalizedString("stats.tomorrow.new", comment: "New")): \(stats.tomorrowPreview[safe: 1] ?? 0)")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                }
                
                // 操作按钮
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text(NSLocalizedString("study.complete.continue", comment: "Continue learning"))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Button(action: onFinish) {
                        Text(NSLocalizedString("study.complete.finish", comment: "Finish"))
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Localized Stat Card

struct LocalizedStatCard: View {
    let titleKey: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(NSLocalizedString(titleKey, comment: ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Example: Audio Mode Localization
// Original: AudioPlayerManager.swift - PlaybackMode

enum LocalizedPlaybackMode: String, CaseIterable {
    case sequential = "sequential"
    case random = "random"
    case spaced = "spaced"
    
    var localizedName: String {
        switch self {
        case .sequential:
            return NSLocalizedString("audio.mode.sequential", comment: "Sequential mode")
        case .random:
            return NSLocalizedString("audio.mode.random", comment: "Random mode")
        case .spaced:
            return NSLocalizedString("audio.mode.spaced", comment: "Spaced repetition mode")
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .sequential:
            return NSLocalizedString("audio.mode.sequential.desc", comment: "Sequential description")
        case .random:
            return NSLocalizedString("audio.mode.random.desc", comment: "Random description")
        case .spaced:
            return NSLocalizedString("audio.mode.spaced.desc", comment: "Spaced description")
        }
    }
}

// MARK: - Example: Theme Color Localization
// Original: Theme.swift - ThemeColor

extension ThemeColor {
    var localizedDisplayName: String {
        switch self {
        case .purple:
            return NSLocalizedString("settings.themes.purple", comment: "Purple theme")
        case .blue:
            return NSLocalizedString("settings.themes.blue", comment: "Blue theme")
        case .green:
            return NSLocalizedString("settings.themes.green", comment: "Green theme")
        case .orange:
            return NSLocalizedString("settings.themes.orange", comment: "Orange theme")
        }
    }
}

// MARK: - Migration Checklist

/*
 
 ## 代码国际化迁移清单
 
 ### Phase 1: 基础替换 (高优先级)
 - [ ] MainTabView.swift - 所有 Tab 标签
 - [ ] StudyView.swift - 学习界面文本
 - [ ] SettingsView.swift - 设置界面文本
 - [ ] AudioReviewView.swift - 音频界面文本
 - [ ] StatisticsView.swift - 统计界面文本
 - [ ] WordListView.swift - 词库界面文本
 
 ### Phase 2: 状态与枚举 (中优先级)
 - [ ] WordStatusFilter - 单词状态筛选
 - [ ] PlaybackMode - 播放模式
 - [ ] SyncStatus - 同步状态
 - [ ] ThemeColor - 主题颜色
 
 ### Phase 3: 错误提示与弹窗 (中优先级)
 - [ ] 所有 Alert 标题和消息
 - [ ] 错误提示文本
 - [ ] 确认对话框
 
 ### Phase 4: 辅助功能 (低优先级)
 - [ ] 所有 accessibilityLabel
 - [ ] 所有 accessibilityHint
 
 ### Phase 5: 高级功能 (可选)
 - [ ] 数字格式化
 - [ ] 日期格式化
 - [ ] 复数形式 (.stringsdict)
 
 ## 替换模式
 
 ### 模式 1: 直接替换
 // 之前
 Text("学习")
 
 // 之后
 Text(NSLocalizedString("tab.study", comment: ""))
 
 ### 模式 2: 条件文本
 // 之前
 Text(showMeaning ? "隐藏释义" : "显示释义")
 
 // 之后
 Text(showMeaning 
      ? NSLocalizedString("study.card.hideMeaning", comment: "")
      : NSLocalizedString("study.card.showMeaning", comment: ""))
 
 ### 模式 3: 格式化字符串
 // 之前
 Text("\(current)/\(total)")
 
 // 之后
 Text(String(format: NSLocalizedString("study.progress.format", comment: ""), current, total))
 
 ### 模式 4: Switch 语句
 // 之前
 var label: String {
     switch status {
     case "new": return "未学习"
     case "learning": return "学习中"
     ...
     }
 }
 
 // 之后
 var label: String {
     switch status {
     case "new": return NSLocalizedString("status.new", comment: "")
     case "learning": return NSLocalizedString("status.learning", comment: "")
     ...
     }
 }
 
 */

// MARK: - Preview

struct LocalizedViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LocalizedEmptyStudyView(onLoad: {})
                .previewDisplayName("English")
            
            LocalizedEmptyStudyView(onLoad: {})
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .previewDisplayName("简体中文")
            
            LocalizedEmptyStudyView(onLoad: {})
                .environment(\.locale, Locale(identifier: "zh-Hant"))
                .previewDisplayName("繁體中文")
        }
    }
}
