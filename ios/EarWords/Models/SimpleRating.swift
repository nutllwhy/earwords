//
//  SimpleRating.swift
//  EarWords
//
//  简化的3档评分枚举 - 用户友好的评分系统
//  将原有的0-5分6档简化为：忘记/模糊/记住
//

import SwiftUI

/// 简化评分枚举 (3档)
/// 替代原有的 ReviewQuality (0-5分6档)
enum SimpleRating: Int, CaseIterable, Codable {
    case forgot = 0      // 忘记 - 红色
    case vague = 1       // 模糊 - 黄色
    case remembered = 2  // 记住 - 绿色
    
    // MARK: - 显示文本
    
    var title: String {
        switch self {
        case .forgot: return "忘记"
        case .vague: return "模糊"
        case .remembered: return "记住"
        }
    }
    
    /// 详细描述（用于引导提示）
    var description: String {
        switch self {
        case .forgot: return "完全想不起来"
        case .vague: return "有点印象，但不确定"
        case .remembered: return "确定记得"
        }
    }
    
    // MARK: - 表情符号
    
    var emoji: String {
        switch self {
        case .forgot: return "😵"
        case .vague: return "😕"
        case .remembered: return "😊"
        }
    }
    
    // MARK: - 颜色
    
    var color: Color {
        switch self {
        case .forgot: return .red
        case .vague: return .orange
        case .remembered: return .green
        }
    }
    
    /// 背景色（带透明度）
    var backgroundColor: Color {
        color.opacity(0.15)
    }
    
    /// 边框色
    var borderColor: Color {
        color.opacity(0.5)
    }
    
    // MARK: - SM-2 算法映射
    
    /// 基础间隔天数（首次复习时）
    var baseIntervalDays: Int {
        switch self {
        case .forgot: return 0   // 当天重复
        case .vague: return 1    // 1天后
        case .remembered: return 3 // 3天后（首次）
        }
    }
    
    /// 是否需要当天重复
    var needsSameDayRepeat: Bool {
        return self == .forgot
    }
    
    /// 是否回答正确（记住或模糊）
    var isCorrect: Bool {
        return self != .forgot
    }
    
    /// 是否完全掌握（记住）
    var isMastered: Bool {
        return self == .remembered
    }
    
    // MARK: - 映射到旧版 ReviewQuality (用于兼容)
    
    /// 转换为旧版 ReviewQuality
    var reviewQuality: ReviewQuality {
        switch self {
        case .forgot: return .blackOut      // 0分
        case .vague: return .hesitation     // 3分（中等）
        case .remembered: return .good      // 4分（良好）
        }
    }
    
    /// 从 ReviewQuality 创建（用于兼容旧数据）
    init?(from quality: ReviewQuality) {
        switch quality {
        case .blackOut, .incorrect:
            self = .forgot
        case .difficult, .hesitation:
            self = .vague
        case .good, .perfect:
            self = .remembered
        }
    }
    
    // MARK: - 间隔计算
    
    /// 获取推荐间隔天数（基于复习次数）
    /// - Parameter reviewCount: 已复习次数
    /// - Returns: 推荐间隔天数
    func intervalDays(for reviewCount: Int) -> Int {
        switch self {
        case .forgot:
            return 0  // 当天重复
            
        case .vague:
            return 1  // 总是1天后
            
        case .remembered:
            // 记住后递增间隔：1→3→7→14→30→60→...天
            let intervals = [1, 3, 7, 14, 30, 60, 90, 180, 365]
            let index = min(reviewCount, intervals.count - 1)
            return intervals[index]
        }
    }
}

// MARK: - 引导提示

extension SimpleRating {
    /// 首次使用的引导提示文本
    static var guideText: String {
        "忘记：完全想不起来 / 模糊：有点印象 / 记住：确定记得"
    }
    
    /// 获取对应评分档位的提示
    var guideTip: String {
        switch self {
        case .forgot:
            return "完全想不起来这个词的意思"
        case .vague:
            return "有点印象，但不确定具体含义"
        case .remembered:
            return "确定记得这个词的意思"
        }
    }
}

// MARK: - 触觉反馈

extension SimpleRating {
    /// 对应的触觉反馈强度
    var hapticIntensity: Double {
        switch self {
        case .forgot: return 1.0   // 强震动（失败感）
        case .vague: return 0.5    // 中等震动
        case .remembered: return 0.3 // 轻震动（成功感）
        }
    }
    
    /// 触发触觉反馈
    func triggerHaptic() {
        switch self {
        case .forgot:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        case .vague:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred(intensity: 0.5)
        case .remembered:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}

// MARK: - 按钮样式

struct SimpleRatingButtonStyle: ButtonStyle {
    let rating: SimpleRating
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? rating.color.opacity(0.25) : rating.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? rating.color : rating.borderColor, lineWidth: isSelected ? 3 : 2)
                    )
            )
            .foregroundColor(rating.color)
            .scaleEffect(isSelected ? 1.05 : (configuration.isPressed ? 0.96 : 1.0))
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
