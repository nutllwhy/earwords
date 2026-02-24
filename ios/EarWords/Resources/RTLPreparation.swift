//
//  RTLPreparation.swift
//  EarWords
//
//  RTL (Right-to-Left) Language Support Preparation
//  Created: 2026-02-24
//
//  This file contains RTL support helpers and documentation for
//  future Arabic, Hebrew, Persian, and Urdu language support.
//

import SwiftUI

// MARK: - RTL Environment

/// RTL support utilities
enum RTLConfiguration {
    /// Supported RTL language codes
    static let rtlLanguages: Set<String> = [
        "ar",    // Arabic (العربية)
        "he",    // Hebrew (עברית)
        "iw",    // Hebrew legacy code
        "ur",    // Urdu (اردو)
        "fa",    // Persian/Farsi (فارسی)
        "ps",    // Pashto (پښتو)
        "ug",    // Uyghur (ئۇيغۇرچە)
        "ku",    // Kurdish (کوردی)
        "yi"     // Yiddish (ייִדיש)
    ]
    
    /// Check if a language code is RTL
    static func isRTLLanguage(_ languageCode: String) -> Bool {
        let baseCode = String(languageCode.prefix(2))
        return rtlLanguages.contains(baseCode)
    }
    
    /// Check if current locale is RTL
    static var isCurrentLocaleRTL: Bool {
        return Locale.characterDirection(forLanguage: Locale.preferredLanguage) == .rightToLeft
    }
    
    /// Preferred language
    static var preferredLanguage: String {
        return Locale.preferredLanguages.first ?? "en"
    }
}

// MARK: - RTL View Modifiers

extension View {
    /// Flips the view horizontally for RTL languages
    @ViewBuilder
    func rtlFlip() -> some View {
        if RTLConfiguration.isCurrentLocaleRTL {
            self.scaleEffect(x: -1, y: 1)
        } else {
            self
        }
    }
    
    /// Automatically flips SF Symbols that need mirroring in RTL
    func mirrorForRTL() -> some View {
        self.flipsForRightToLeftLayoutDirection(true)
    }
    
    /// Sets text alignment based on current layout direction
    func adaptiveTextAlignment() -> some View {
        self.multilineTextAlignment(RTLConfiguration.isCurrentLocaleRTL ? .trailing : .leading)
    }
}

// MARK: - RTL Container

/// A container view that adapts to RTL layouts
struct RTLAdaptiveContainer<Content: View>: View {
    @Environment(\.layoutDirection) private var layoutDirection
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .environment(\.layoutDirection, layoutDirection)
    }
}

// MARK: - Directional Layout Helpers

/// Layout direction-aware HStack
struct DirectionalHStack<Content: View>: View {
    @Environment(\.layoutDirection) private var layoutDirection
    let alignment: VerticalAlignment
    let spacing: CGFloat?
    let content: Content
    
    init(
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        HStack(alignment: alignment, spacing: spacing) {
            content
        }
    }
}

/// Leading/Trailing adaptive layout
struct AdaptiveEdgeStack<Content: View>: View {
    @Environment(\.layoutDirection) private var layoutDirection
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        HStack {
            if layoutDirection == .rightToLeft {
                Spacer()
            }
            content
            if layoutDirection == .leftToRight {
                Spacer()
            }
        }
    }
}

// MARK: - RTL-Safe Components

/// A text field that adapts to RTL
struct RTLTextField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField(placeholder, text: $text)
            .multilineTextAlignment(RTLConfiguration.isCurrentLocaleRTL ? .trailing : .leading)
    }
}

/// A progress view that adapts to RTL
struct RTLProgressView: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                
                // Progress - automatically adapts to RTL via HStack
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue)
                    .frame(width: geometry.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
    }
}

/// Navigation button that adapts to RTL
struct RTLNavigationButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .mirrorForRTL()
                Text(title)
            }
        }
    }
}

// MARK: - Current Code Review for RTL

/*
 
 # RTL 适配代码审查报告
 
 ## 已适配的组件 ✅
 
 ### 1. SwiftUI 原生组件 (自动适配)
 - List - 自动处理 RTL
 - Form - 自动处理 RTL
 - NavigationView - 自动处理 RTL
 - TabView - 自动处理 RTL
 - Picker - 自动处理 RTL
 - Toggle - 自动处理 RTL
 - Slider - 自动处理 RTL
 - ProgressView - 自动处理 RTL
 - Button - 自动处理 RTL
 
 ### 2. 需要检查的自定义组件
 
 #### StudyView.swift
 ```swift
 // ✅ 手势识别 - 需要测试
 DragGesture()
     .onChanged { value in
         // 左右滑动在 RTL 中应该反向吗？
         // 结论：滑动逻辑应该保持一致（左=模糊，右=认识）
         // 视觉反馈需要适配
     }
 
 // ⚠️ 进度条
 StudyProgressBar(
     current: viewModel.currentIndex + 1,
     total: viewModel.totalCount,
     ...
 )
 // 建议：使用 RTLProgressView 替代自定义实现
 ```
 
 #### WordCardView.swift
 ```swift
 // ✅ 使用 HStack 和 Spacer() - 自动适配 RTL
 HStack {
     Text(word.chapter)
     Spacer()
     DifficultyBadge(...)
 }
 
 // ⚠️ 按钮布局
 ActionButton(...)
 // 建议使用 DirectionalHStack 包装
 ```
 
 #### AudioReviewView.swift
 ```swift
 // ✅ 播放器控制 - 需要镜像图标
 Button(action: onPrevious) {
     Image(systemName: "backward.fill")
         .mirrorForRTL()  // 添加此行
 }
 
 Button(action: onNext) {
     Image(systemName: "forward.fill")
         .mirrorForRTL()  // 添加此行
 }
 ```
 
 #### StatisticsView.swift
 ```swift
 // ✅ 图表 (iOS 16+)
 Chart(data) { point in
     BarMark(...)
 }
 // 图表自动适配 RTL
 
 // ⚠️ 进度列表
 ChapterProgressList(...)
 // 需要检查进度条方向
 ```
 
 ## 需要的修改清单
 
 ### 高优先级
 
 1. **镜像图标**
    - 所有箭头图标：arrow.left, arrow.right, chevron.left, chevron.right
    - 返回按钮：backward.fill, forward.fill
    - 播放控制：play, pause
 
 2. **文本对齐**
    - 所有 Text 默认使用 .adaptiveTextAlignment()
    - 数字保持左对齐（或根据内容）
    - 英文单词保持左对齐
 
 3. **进度条**
    - 替换所有自定义进度条为 RTLProgressView
    - 确保进度增长方向正确
 
 ### 中优先级
 
 4. **手势交互**
    - 确认滑动手势逻辑在 RTL 下正确
    - 可能需要反转某些手势的视觉反馈
 
 5. **列表项**
    - 检查 DisclosureGroup 箭头方向
    - 检查删除按钮位置
 
 6. **文本方向混合**
    - 处理阿拉伯语 + 英语的混合文本
    - 确保音标显示正确
 
 ### 低优先级
 
 7. **数字和日期**
    - 阿拉伯数字使用西方数字 (0-9) 还是阿拉伯数字 (٠-٩)
    - 日期格式本地化
 
 8. **字体**
    - 阿拉伯语需要专门的字体支持
    - 确保字体回退正确
 
 */

// MARK: - Migration Examples

/// Example: Converting a view to RTL-safe
struct RTLSafeExample {
    
    // BEFORE: 原始代码
    struct OriginalButtonRow: View {
        var body: some View {
            HStack(spacing: 40) {
                Button(action: {}) {
                    Image(systemName: "backward.fill")
                }
                Button(action: {}) {
                    Image(systemName: "play.circle.fill")
                }
                Button(action: {}) {
                    Image(systemName: "forward.fill")
                }
            }
        }
    }
    
    // AFTER: RTL 安全代码
    struct RTLSafeButtonRow: View {
        var body: some View {
            HStack(spacing: 40) {
                Button(action: {}) {
                    Image(systemName: "backward.fill")
                        .mirrorForRTL()  // 关键修改
                }
                Button(action: {}) {
                    Image(systemName: "play.circle.fill")
                    // 播放按钮不需要镜像
                }
                Button(action: {}) {
                    Image(systemName: "forward.fill")
                        .mirrorForRTL()  // 关键修改
                }
            }
        }
    }
}

// MARK: - Testing Helpers

/// Preview helpers for RTL testing
struct RTLPreviews {
    
    static func previews<Content: View>(for view: Content) -> some View {
        Group {
            // LTR (English)
            view
                .previewDisplayName("LTR (English)")
            
            // RTL (Arabic)
            view
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
                .previewDisplayName("RTL (Arabic)")
            
            // Pseudo-RTL (for testing)
            view
                .environment(\.layoutDirection, .rightToLeft)
                .previewDisplayName("Pseudo-RTL")
        }
    }
}

// MARK: - Preview

struct RTLPreparation_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Test RTL progress view
            VStack(spacing: 20) {
                RTLProgressView(progress: 0.3)
                RTLProgressView(progress: 0.7)
            }
            .padding()
            .previewDisplayName("LTR Progress")
            
            // RTL version
            VStack(spacing: 20) {
                RTLProgressView(progress: 0.3)
                RTLProgressView(progress: 0.7)
            }
            .padding()
            .environment(\.layoutDirection, .rightToLeft)
            .previewDisplayName("RTL Progress")
            
            // Test navigation buttons
            HStack(spacing: 20) {
                RTLNavigationButton(
                    title: "Previous",
                    systemImage: "backward.fill"
                ) {}
                RTLNavigationButton(
                    title: "Next",
                    systemImage: "forward.fill"
                ) {}
            }
            .padding()
            .previewDisplayName("LTR Navigation")
            
            // RTL version
            HStack(spacing: 20) {
                RTLNavigationButton(
                    title: "السابق",
                    systemImage: "backward.fill"
                ) {}
                RTLNavigationButton(
                    title: "التالي",
                    systemImage: "forward.fill"
                ) {}
            }
            .padding()
            .environment(\.layoutDirection, .rightToLeft)
            .previewDisplayName("RTL Navigation (Arabic)")
        }
    }
}

// MARK: - Implementation Checklist

/*
 
 # RTL 实施检查清单
 
 ## 准备阶段
 - [ ] 识别所有需要镜像的图标
 - [ ] 识别所有自定义进度条
 - [ ] 识别所有绝对定位的文本
 - [ ] 识别所有滑动手势
 
 ## 实施阶段
 - [ ] 添加 .mirrorForRTL() 到所有箭头图标
 - [ ] 替换自定义进度条为 RTLProgressView
 - [ ] 添加文本对齐修饰符
 - [ ] 测试混合文本（阿拉伯语+英语）
 
 ## 测试阶段
 - [ ] 使用 Pseudo-RTL 语言测试
 - [ ] 使用真实阿拉伯语测试
 - [ ] 测试所有界面流程
 - [ ] 测试辅助功能 (VoiceOver)
 
 ## 发布阶段
 - [ ] 添加阿拉伯语到支持语言列表
 - [ ] 更新应用商店截图
 - [ ] 更新应用商店描述
 - [ ] 准备阿拉伯语客服支持
 
 */
