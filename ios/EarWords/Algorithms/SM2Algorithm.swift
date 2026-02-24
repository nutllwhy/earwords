//
//  SM2Algorithm.swift
//  EarWords
//
//  SM-2 间隔重复算法实现 (PRD 版本)
//  参考: EarWords PRD 评分标准
//  论文参考: https://www.supermemo.com/en/archives1990-2015/english/ol/sm2
//

import Foundation

// MARK: - 算法常量

/// SM-2 算法常量定义
struct SM2Constants {
    /// 最小简易度
    static let minEaseFactor: Double = 1.3
    /// 默认简易度
    static let defaultEaseFactor: Double = 2.5
    /// 最大间隔天数
    static let maxIntervalDays: Int = 365
    /// 基础间隔倍数
    static let intervalMultiplier: Double = 1.5
    /// PRD 定义的基础间隔表
    static let prdBaseIntervals: [Int] = [0, 0, 1, 3, 7, 14]
    /// 简易度调整系数
    static let easeFactorAdjustment: Double = 0.1
    /// 简易度惩罚基数
    static let easeFactorPenaltyBase: Double = 0.08
    /// 简易度惩罚倍数
    static let easeFactorPenaltyMultiplier: Double = 0.02
}

// MARK: - 复习质量评分

/// 复习质量评分 (0-5) - PRD 标准
///
/// 评分标准:
/// - 0: 完全忘记 - 对该单词没有任何印象
/// - 1: 错误 - 有印象但回忆错误
/// - 2: 困难 - 经努力后回忆起
/// - 3: 犹豫后正确 - 稍有犹豫后正确回忆
/// - 4: 正确 - 比较流畅地回忆
/// - 5: 完美 - 瞬间正确回忆
enum ReviewQuality: Int16, CaseIterable {
    case blackOut = 0      // 完全忘记
    case incorrect = 1     // 错误
    case difficult = 2     // 困难
    case hesitation = 3    // 犹豫后正确
    case good = 4          // 正确
    case perfect = 5       // 完美
    
    var description: String {
        switch self {
        case .blackOut: return "完全忘记"
        case .incorrect: return "错误"
        case .difficult: return "困难"
        case .hesitation: return "犹豫后正确"
        case .good: return "正确"
        case .perfect: return "完美"
        }
    }
    
    /// 根据PRD的下次复习间隔（天数）
    var nextIntervalDays: Int {
        switch self {
        case .blackOut: return 0   // 当天重复
        case .incorrect: return 0  // 当天重复
        case .difficult: return 1  // 1天后
        case .hesitation: return 3 // 3天后
        case .good: return 7       // 7天后
        case .perfect: return 14   // 14天后
        }
    }
    
    /// 是否需要当天重复
    var needsSameDayRepeat: Bool {
        return self.rawValue < 2
    }
    
    /// 是否回答正确（>=3）
    var isCorrect: Bool {
        return self.rawValue >= 3
    }
}

/// SM-2 算法实现 (PRD 简化版)
///
/// 该算法根据用户的记忆表现动态调整复习间隔，
/// 在遗忘临界点安排复习，以达到最佳记忆效果。
struct SM2Algorithm {
    
    // MARK: - 算法参数 (已迁移至 SM2Constants)
    
    /// 最小简易度
    static let minEaseFactor: Double = SM2Constants.minEaseFactor
    
    /// 默认简易度
    static let defaultEaseFactor: Double = SM2Constants.defaultEaseFactor
    
    /// 最大间隔天数
    static let maxInterval: Int = SM2Constants.maxIntervalDays
    
    /// 基础间隔倍数（用于连续复习）
    static let intervalMultiplier: Double = SM2Constants.intervalMultiplier
    
    /// PRD 定义的基础间隔表
    static let prdBaseIntervals: [Int] = SM2Constants.prdBaseIntervals
    
    // MARK: - 核心算法
    
    /// 计算下次复习数据 (PRD 版本)
    /// - Parameters:
    ///   - quality: 复习质量 (0-5)
    ///   - currentEaseFactor: 当前简易度
    ///   - currentInterval: 当前间隔天数
    ///   - reviewCount: 已复习次数
    /// - Returns: 新的复习参数 (interval: 间隔天数, easeFactor: 简易度, shouldRepeat: 是否当天重复)
    static func calculateNextReview(
        quality: ReviewQuality,
        currentEaseFactor: Double,
        currentInterval: Int,
        reviewCount: Int
    ) -> (interval: Int, easeFactor: Double, shouldRepeat: Bool) {
        
        // 根据 PRD 标准计算间隔
        let baseInterval = quality.nextIntervalDays
        
        // 计算新的简易度 (标准 SM-2 公式)
        let q = Double(quality.rawValue)
        var newEaseFactor = currentEaseFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        newEaseFactor = max(newEaseFactor, minEaseFactor)
        
        var newInterval: Int
        let shouldRepeat = quality.needsSameDayRepeat
        
        if quality.rawValue < 2 {
            // 0-1分: 当天重复，不增加间隔
            newInterval = 0
        } else if quality.rawValue == 2 {
            // 2分: 1天后
            newInterval = 1
        } else {
            // 3-5分: 根据复习次数调整
            if reviewCount == 0 {
                // 第一次复习使用 PRD 基础间隔
                newInterval = baseInterval
            } else if reviewCount == 1 {
                // 第二次复习
                newInterval = max(baseInterval, Int(Double(currentInterval) * newEaseFactor))
            } else {
                // 后续复习: I(n) = I(n-1) * EF
                newInterval = Int(Double(currentInterval) * newEaseFactor)
            }
        }
        
        // 限制最大间隔
        newInterval = min(newInterval, maxInterval)
        
        return (newInterval, newEaseFactor, shouldRepeat)
    }
    
    /// 计算下次复习日期
    /// - Parameters:
    ///   - quality: 复习质量评分
    ///   - currentRecord: 当前学习记录
    /// - Returns: 下次复习日期
    static func calculateNextReviewDate(
        quality: ReviewQuality,
        currentRecord: StudyRecord
    ) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // 使用 calculateNextReview 计算间隔
        let result = calculateNextReview(
            quality: quality,
            currentEaseFactor: currentRecord.easeFactor,
            currentInterval: currentRecord.interval,
            reviewCount: currentRecord.reviewCount
        )
        
        if result.shouldRepeat {
            // 当天重复（1小时后）
            return calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        } else {
            // 按计算间隔
            return calendar.date(byAdding: .day, value: result.interval, to: now) ?? now
        }
    }
    
    /// 计算下次复习日期（直接参数版本）
    static func nextReviewDate(
        from date: Date = Date(),
        interval: Int
    ) -> Date {
        let calendar = Calendar.current
        if interval == 0 {
            // 当天重复：1小时后
            return calendar.date(byAdding: .hour, value: 1, to: date) ?? date
        }
        return calendar.date(byAdding: .day, value: interval, to: date) ?? date
    }
    
    /// 获取单词状态
    static func wordStatus(
        reviewCount: Int,
        quality: ReviewQuality?
    ) -> WordStatus {
        if reviewCount == 0 {
            return .new
        }
        
        // 连续3次正确且间隔 >= 7天 视为掌握
        if let q = quality, q.rawValue >= 4 {
            return .mastered
        }
        
        return .learning
    }
    
    /// 根据准确率计算推荐评分（用于自动评估）
    static func suggestedQuality(accuracy: Double, responseTime: Double) -> ReviewQuality {
        if accuracy < 0.3 {
            return .blackOut
        } else if accuracy < 0.5 {
            return .incorrect
        } else if accuracy < 0.7 {
            return .difficult
        } else if accuracy < 0.85 {
            return .hesitation
        } else if accuracy < 0.95 || responseTime > 3.0 {
            return .good
        } else {
            return .perfect
        }
    }
}

// MARK: - 状态枚举

enum WordStatus: String, CaseIterable {
    case new = "new"           // 新词
    case learning = "learning" // 学习中
    case mastered = "mastered" // 已掌握
    
    var description: String {
        switch self {
        case .new: return "新词"
        case .learning: return "学习中"
        case .mastered: return "已掌握"
        }
    }
    
    var color: String {
        switch self {
        case .new: return "blue"
        case .learning: return "orange"
        case .mastered: return "green"
        }
    }
}

// MARK: - WordEntity 扩展

extension WordEntity {
    
    /// 应用复习结果 (更新版本)
    /// - Parameters:
    ///   - quality: 复习质量评分
    ///   - timeSpent: 花费时间（秒）
    /// - Returns: 复习结果信息
    @discardableResult
    func applyReview(quality: ReviewQuality, timeSpent: Double = 0) -> ReviewResult {
        // 保存旧值
        let previousEaseFactor = self.easeFactor
        let previousInterval = Int(self.interval)
        let previousReviewCount = Int(self.reviewCount)
        
        // 计算新的复习参数
        let result = SM2Algorithm.calculateNextReview(
            quality: quality,
            currentEaseFactor: previousEaseFactor,
            currentInterval: previousInterval,
            reviewCount: previousReviewCount
        )
        
        // 更新字段
        self.interval = Int32(result.interval)
        self.easeFactor = result.easeFactor
        
        // 只有在非当天重复的情况下才增加复习计数
        if !result.shouldRepeat {
            self.reviewCount += 1
        }
        
        self.lastReviewDate = Date()
        self.nextReviewDate = SM2Algorithm.nextReviewDate(interval: result.interval)
        self.status = SM2Algorithm.wordStatus(
            reviewCount: Int(self.reviewCount),
            quality: quality
        ).rawValue
        
        // 更新统计
        if quality.isCorrect {
            self.correctCount += 1
            self.streak += 1
        } else {
            self.incorrectCount += 1
            // 忘记或错误时重置连续正确次数
            if quality.rawValue < 2 {
                self.streak = 0
            }
        }
        
        self.updatedAt = Date()
        
        return ReviewResult(
            quality: quality,
            previousEaseFactor: previousEaseFactor,
            newEaseFactor: result.easeFactor,
            previousInterval: previousInterval,
            newInterval: result.interval,
            shouldRepeat: result.shouldRepeat,
            nextReviewDate: self.nextReviewDate!,
            timeSpent: timeSpent
        )
    }
    
    /// 快速评分方法
    func rate(_ score: Int, timeSpent: Double = 0) -> ReviewResult? {
        guard let quality = ReviewQuality(rawValue: Int16(score)) else { return nil }
        return applyReview(quality: quality, timeSpent: timeSpent)
    }
    
    /// 重置单词学习状态
    func reset() {
        self.status = WordStatus.new.rawValue
        self.reviewCount = 0
        self.easeFactor = SM2Algorithm.defaultEaseFactor
        self.interval = 0
        self.nextReviewDate = nil
        self.lastReviewDate = nil
        self.correctCount = 0
        self.incorrectCount = 0
        self.streak = 0
        self.updatedAt = Date()
    }
    
    /// 标记为已掌握
    func markAsMastered() {
        self.status = WordStatus.mastered.rawValue
        self.reviewCount += 1
        self.interval = 30
        self.nextReviewDate = SM2Algorithm.nextReviewDate(interval: 30)
        self.updatedAt = Date()
    }
}

// MARK: - 复习结果

struct ReviewResult {
    let quality: ReviewQuality
    let previousEaseFactor: Double
    let newEaseFactor: Double
    let previousInterval: Int
    let newInterval: Int
    let shouldRepeat: Bool
    let nextReviewDate: Date
    let timeSpent: Double
    
    var isCorrect: Bool {
        quality.isCorrect
    }
    
    var intervalChange: Int {
        newInterval - previousInterval
    }
    
    var easeFactorChange: Double {
        newEaseFactor - previousEaseFactor
    }
}
