//
//  EarWordsAppIntents.swift
//  EarWords
//
//  App Intents - 用于小组件交互和深度链接
//

import AppIntents
import SwiftUI

// MARK: - 打开学习页面 Intent
struct OpenStudyIntent: AppIntent {
    static var title: LocalizedStringResource = "开始学习"
    static var description = IntentDescription("打开 EarWords 并开始学习")
    
    @MainActor
    func perform() async throws -> some IntentResult &amp; ReturnsValue<String> {
        // 触发打开学习页面的通知
        NotificationCenter.default.post(
            name: .openStudyPage,
            object: nil
        )
        
        // 同时刷新小组件数据
        WidgetDataProvider.shared.reloadWidgetData()
        
        return .result(value: "已打开学习页面")
    }
}

// MARK: - 打开磨耳朵页面 Intent
struct OpenAudioReviewIntent: AppIntent {
    static var title: LocalizedStringResource = "磨耳朵"
    static var description = IntentDescription("打开 EarWords 磨耳朵功能")
    
    @MainActor
    func perform() async throws -> some IntentResult &amp; ReturnsValue<String> {
        NotificationCenter.default.post(
            name: .openAudioReviewPage,
            object: nil
        )
        return .result(value: "已打开磨耳朵页面")
    }
}

// MARK: - 刷新小组件数据 Intent
struct RefreshWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "刷新数据"
    static var description = IntentDescription("刷新小组件显示的数据")
    
    @MainActor
    func perform() async throws -> some IntentResult &amp; ReturnsValue<String> {
        WidgetDataProvider.shared.reloadWidgetData()
        return .result(value: "小组件数据已刷新")
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let openStudyPage = Notification.Name("openStudyPage")
    static let openAudioReviewPage = Notification.Name("openAudioReviewPage")
    static let widgetDataUpdated = Notification.Name("widgetDataUpdated")
}

// MARK: - URL Scheme 处理
enum EarWordsDeepLink: String {
    case study = "study"
    case audioReview = "audio"
    case statistics = "stats"
    case settings = "settings"
    
    var url: URL {
        URL(string: "earwords://\(rawValue)")!
    }
}

// MARK: - 小组件配置 Intent（iOS 17+ 可配置小组件）
@available(iOS 17.0, *)
struct WidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "小组件配置"
    static var description = IntentDescription("自定义小组件显示内容")
    
    @Parameter(title: "显示模式")
    var displayMode: DisplayMode
    
    @Parameter(title: "主题颜色", default: .purple)
    var themeColor: ThemeColor
    
    init() {
        self.displayMode = .progress
        self.themeColor = .purple
    }
}

@available(iOS 17.0, *)
enum DisplayMode: String, AppEnum {
    case progress = "progress"
    case streak = "streak"
    case dueWords = "dueWords"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "显示模式"
    }
    
    static var caseDisplayRepresentations: [DisplayMode: DisplayRepresentation] {
        [
            .progress: "学习进度",
            .streak: "连续打卡",
            .dueWords: "待复习单词"
        ]
    }
}

@available(iOS 17.0, *)
enum ThemeColor: String, AppEnum {
    case purple = "purple"
    case blue = "blue"
    case green = "green"
    case orange = "orange"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "主题颜色"
    }
    
    static var caseDisplayRepresentations: [ThemeColor: DisplayRepresentation] {
        [
            .purple: "紫色",
            .blue: "蓝色",
            .green: "绿色",
            .orange: "橙色"
        ]
    }
    
    var swiftUIColor: Color {
        switch self {
        case .purple: return .purple
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        }
    }
}
