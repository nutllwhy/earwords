//
//  LocalizationQuickRef.swift
//  EarWords
//
//  Quick reference for localization
//  Copy-paste ready snippets
//

import SwiftUI

// MARK: - Quick Reference

/*
 ╔══════════════════════════════════════════════════════════════╗
 ║                   EarWords 国际化速查表                        ║
 ╚══════════════════════════════════════════════════════════════╝
 
 1. 基础用法
 ──────────────────────────────────────────────────────────────
 
 // 简单文本
 Text(NSLocalizedString("tab.study", comment: ""))
 
 // 使用工具类
 Text(L.string("tab.study"))
 
 // 带格式的文本
 Text(L.string(format: "study.title", 42))
 
 2. 常用键值
 ──────────────────────────────────────────────────────────────
 
 Tab 导航:
 • tab.study      → "学习"
 • tab.audio      → "磨耳朵"
 • tab.statistics → "统计"
 • tab.vocabulary → "词库"
 • tab.settings   → "设置"
 
 单词状态:
 • status.new       → "未学习"
 • status.learning  → "学习中"
 • status.mastered  → "已掌握"
 
 通用操作:
 • common.done    → "完成"
 • common.cancel  → "取消"
 • common.save    → "保存"
 • common.close   → "关闭"
 
 3. 格式化字符串
 ──────────────────────────────────────────────────────────────
 
 // 数字参数
 "study.title" = "今日学习 (%d)"
 Text(String(format: NSLocalizedString("study.title", comment: ""), wordCount))
 
 // 多个参数
 "study.progress.format" = "%d/%d"
 Text(String(format: NSLocalizedString("study.progress.format", comment: ""), current, total))
 
 // 浮点数
 "settings.audio.speechRate.value" = "%.1fx"
 Text(String(format: NSLocalizedString("settings.audio.speechRate.value", comment: ""), rate))
 
 4. 条件文本
 ──────────────────────────────────────────────────────────────
 
 // 之前
 Text(showMeaning ? "隐藏释义" : "显示释义")
 
 // 之后
 Text(showMeaning
      ? NSLocalizedString("study.card.hideMeaning", comment: "")
      : NSLocalizedString("study.card.showMeaning", comment: ""))
 
 // 使用三元运算符简化
 Text(NSLocalizedString(showMeaning ? "study.card.hideMeaning" : "study.card.showMeaning", comment: ""))
 
 5. Switch 语句
 ──────────────────────────────────────────────────────────────
 
 // 之前
 var label: String {
     switch status {
     case "new": return "未学习"
     case "learning": return "学习中"
     case "mastered": return "已掌握"
     default: return status
     }
 }
 
 // 之后
 var localizedLabel: String {
     switch status {
     case "new":
         return NSLocalizedString("status.new", comment: "")
     case "learning":
         return NSLocalizedString("status.learning", comment: "")
     case "mastered":
         return NSLocalizedString("status.mastered", comment: "")
     default:
         return status
     }
 }
 
 6. 按钮
 ──────────────────────────────────────────────────────────────
 
 // 之前
 Button("确定") { ... }
 
 // 之后
 Button(NSLocalizedString("common.done", comment: "")) { ... }
 
 // 带图标的按钮
 Button(action: {}) {
     Label(
         NSLocalizedString("tab.settings", comment: ""),
         systemImage: "gearshape.fill"
     )
 }
 
 7. 导航栏
 ──────────────────────────────────────────────────────────────
 
 // 标题
 .navigationTitle(NSLocalizedString("settings.title", comment: ""))
 
 // 导航按钮
 .toolbar {
     ToolbarItem(placement: .navigationBarLeading) {
         Button(NSLocalizedString("common.skip", comment: "")) { ... }
     }
 }
 
 8. 警告框
 ──────────────────────────────────────────────────────────────
 
 // 之前
 .alert("确认重置", isPresented: $showAlert) {
     Button("取消", role: .cancel) {}
     Button("重置", role: .destructive) { ... }
 } message: {
     Text("这将清除所有学习进度...")
 }
 
 // 之后
 .alert(NSLocalizedString("settings.data.reset.alert.title", comment: ""), 
        isPresented: $showAlert) {
     Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
     Button(NSLocalizedString("settings.data.reset", comment: ""), role: .destructive) { ... }
 } message: {
     Text(NSLocalizedString("settings.data.reset.alert.message", comment: ""))
 }
 
 9. Picker/Segmented Control
 ──────────────────────────────────────────────────────────────
 
 Picker("选择", selection: $selected) {
     Text(NSLocalizedString("vocabulary.filter.all", comment: "")).tag("all")
     Text(NSLocalizedString("vocabulary.filter.new", comment: "")).tag("new")
 }
 
 10. Section 标题
 ──────────────────────────────────────────────────────────────
 
 List {
     Section(NSLocalizedString("settings.goals.title", comment: "")) {
         // 内容
     }
 }
 
 */

// MARK: - Copy-Paste Templates

/// Template: Simple Text View
struct LocalizedTextTemplate: View {
    var body: some View {
        Text(NSLocalizedString("key.name", comment: "Description"))
    }
}

/// Template: Button
struct LocalizedButtonTemplate: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(NSLocalizedString("common.done", comment: ""))
        }
    }
}

/// Template: Formatted Text
struct LocalizedFormattedTextTemplate: View {
    let count: Int
    
    var body: some View {
        Text(String(format: NSLocalizedString("study.title", comment: ""), count))
    }
}

/// Template: Conditional Text
struct LocalizedConditionalTemplate: View {
    @State private var isExpanded = false
    
    var body: some View {
        Button(action: { isExpanded.toggle() }) {
            Text(NSLocalizedString(isExpanded ? "common.collapse" : "common.expand", comment: ""))
        }
    }
}

/// Template: Status Badge
struct LocalizedStatusBadgeTemplate: View {
    let status: String
    
    var localizedStatus: String {
        switch status {
        case "new":
            return NSLocalizedString("status.new", comment: "")
        case "learning":
            return NSLocalizedString("status.learning", comment: "")
        case "mastered":
            return NSLocalizedString("status.mastered", comment: "")
        default:
            return status
        }
    }
    
    var body: some View {
        Text(localizedStatus)
    }
}

/// Template: Navigation View
struct LocalizedNavigationTemplate: View {
    var body: some View {
        NavigationView {
            List {
                Text("Content")
            }
            .navigationTitle(NSLocalizedString("settings.title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "")) {}
                }
            }
        }
    }
}

/// Template: Alert
struct LocalizedAlertTemplate: View {
    @State private var showAlert = false
    
    var body: some View {
        Button("Show Alert") { showAlert = true }
            .alert(NSLocalizedString("common.warning", comment: ""), isPresented: $showAlert) {
                Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("common.ok", comment: ""), role: .destructive) {}
            } message: {
                Text(NSLocalizedString("error.generic", comment: ""))
            }
    }
}

// MARK: - Key Categories Reference

/*
 
 按模块分类的键值前缀：
 
 通用:
 • app.*         → App 信息
 • common.*      → 通用操作
 • tab.*         → Tab 导航
 
 学习:
 • study.*       → 学习界面
 • study.card.*  → 单词卡片
 • study.gesture.* → 手势提示
 
 评分:
 • rating.*      → SM-2 评分
 • status.*      → 单词状态
 • stats.*       → 统计数据
 
 音频:
 • audio.*       → 磨耳朵
 • audio.mode.*  → 播放模式
 • audio.player.* → 播放器控制
 • audio.playlist.* → 播放列表
 
 词库:
 • vocabulary.*  → 词库浏览
 • vocabulary.filter.* → 筛选器
 • wordDetail.*  → 单词详情
 
 设置:
 • settings.*    → 设置界面
 • settings.goals.* → 学习目标
 • settings.audio.* → 音频设置
 • settings.reminders.* → 学习提醒
 • settings.appearance.* → 外观
 • settings.sync.* → 数据同步
 • settings.data.* → 数据管理
 • settings.about.* → 关于
 • settings.themes.* → 主题颜色
 
 其他:
 • export.*      → 数据导出
 • onboarding.*  → 引导页
 • launch.*      → 启动页
 • notification.* → 通知
 • accessibility.* → 辅助功能
 • error.*       → 错误消息
 • format.*      → 格式
 
 */

// MARK: - Cheat Sheet for Common Tasks

/*
 
 任务快速查找：
 
 ┌────────────────────────────────────────────────────────────┐
 │ 任务                              │ 示例键值                │
 ├───────────────────────────────────┼─────────────────────────┤
 │ Tab 标签 - 学习                    │ tab.study               │
 │ Tab 标签 - 磨耳朵                  │ tab.audio               │
 │ Tab 标签 - 统计                    │ tab.statistics          │
 │ Tab 标签 - 词库                    │ tab.vocabulary          │
 │ Tab 标签 - 设置                    │ tab.settings            │
 ├───────────────────────────────────┼─────────────────────────┤
 │ 单词状态 - 未学习                  │ status.new              │
 │ 单词状态 - 学习中                  │ status.learning         │
 │ 单词状态 - 已掌握                  │ status.mastered         │
 ├───────────────────────────────────┼─────────────────────────┤
 │ 按钮 - 完成                        │ common.done             │
 │ 按钮 - 取消                        │ common.cancel           │
 │ 按钮 - 跳过                        │ common.skip             │
 │ 按钮 - 继续                        │ common.continue         │
 ├───────────────────────────────────┼─────────────────────────┤
 │ 学习 - 空状态标题                  │ study.empty.title       │
 │ 学习 - 完成标题                    │ study.complete.title    │
 │ 学习 - 继续学习                    │ study.complete.continue │
 ├───────────────────────────────────┼─────────────────────────┤
 │ 设置 - 标题                        │ settings.title          │
 │ 设置 - 每日目标                    │ settings.goals.title    │
 │ 设置 - 音频设置                    │ settings.audio.title    │
 └────────────────────────────────────────────────────────────┘

 */

// MARK: - Preview

struct LocalizationQuickRef_Previews: PreviewProvider {
    static var previews: some View {
        List {
            Section("模板示例") {
                LocalizedTextTemplate()
                LocalizedButtonTemplate(action: {})
                LocalizedFormattedTextTemplate(count: 42)
                LocalizedConditionalTemplate()
                LocalizedStatusBadgeTemplate(status: "learning")
            }
            
            Section("多语言预览") {
                Text(NSLocalizedString("tab.study", comment: ""))
                    .previewDisplayName("中文")
            }
            .environment(\.locale, Locale(identifier: "zh-Hans"))
        }
    }
}
