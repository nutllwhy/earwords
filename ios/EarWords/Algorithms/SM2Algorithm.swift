//
//  SM2Algorithm.swift
//  EarWords
//
//  SM-2 间隔重复算法实现
//  参考: SuperMemo-2 算法 (Piotr Wozniak, 1987)
//

import Foundation

/// 复习质量评分 (0-5)
enum ReviewQuality: Int16, CaseIterable {
    case blackOut = 0      // 完全想不起来
    case incorrect = 1     // 错误，看到答案才想起
    case difficult = 2     // 困难，勉强想起
    case hesitation = 3    // 犹豫后正确
    case good = 4          // 正确
    case perfect = 5       // 完美，瞬间想起
    
    var description: String {
        switch self {
        case .blackOut: return "完全忘记"
        case .incorrect: return "错误"
        case .difficult: return "困难"
        case .hesitation: return "犹豫"
        case .good: return "良好"
        case .perfect: return "完美"
        }
    }
}

/// SM-2 算法实现
struct SM2Algorithm {
    
    // MARK: - 算法参数
    
    /// 初始间隔天数
    private static let initialIntervals: [Int] = [1, 6]  // 第1次1天，第2次6天
    
    /// 最小简易度
    private static let minEaseFactor: Double = 1.3
    
    /// 默认简易度
    private static let defaultEaseFactor: Double = 2.5
    
    // MARK: - 核心算法
    
    /// 计算下次复习数据
    /// - Parameters:
    ///   - quality: 复习质量 (0-5)
    ///   - currentEaseFactor: 当前简易度
    ///   - currentInterval: 当前间隔天数
    ///   - reviewCount: 已复习次数
    /// - Returns: 新的复习参数
    static func calculateNextReview(
        quality: ReviewQuality,
        currentEaseFactor: Double,
        currentInterval: Int,
        reviewCount: Int
    ) -> (interval: Int, easeFactor: Double, shouldRepeat: Bool) {
        
        let q = Double(quality.rawValue)
        
        // 计算新的简易度
        // EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        var newEaseFactor = currentEaseFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        
        // 确保不低于最小值
        newEaseFactor = max(newEaseFactor, minEaseFactor)
        
        var newInterval: Int
        var shouldRepeat = false
        
        // 根据质量决定是否重复
        if quality.rawValue < 3 {
            // 质量低于3，当天重复复习
            newInterval = 1  // 改为1天后复习
            shouldRepeat = true
        } else {
            // 正常复习流程
            if reviewCount == 0 {
                newInterval = 1
            } else if reviewCount == 1 {
                newInterval = 6
            } else {
                // I(n) = I(n-1) * EF
                newInterval = Int(Double(currentInterval) * newEaseFactor)
            }
        }
        
        // 限制最大间隔为365天
        newInterval = min(newInterval, 365)
        
        return (newInterval, newEaseFactor, shouldRepeat)
    }
    
    /// 计算下次复习日期
    static func nextReviewDate(
        from date: Date = Date(),
        interval: Int
    ) -> Date {
        let calendar = Calendar.current
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
        
        if let q = quality, q.rawValue >= 4 {
            return .mastered
        }
        
        return .learning
    }
}

// MARK: - 状态枚举

enum WordStatus: String {
    case new = "new"
    case learning = "learning"
    case mastered = "mastered"
}

// MARK: - 扩展支持

extension WordEntity {
    
    /// 应用复习结果
    func applyReview(quality: ReviewQuality, timeSpent: Double = 0) {
        let result = SM2Algorithm.calculateNextReview(
            quality: quality,
            currentEaseFactor: self.easeFactor,
            currentInterval: Int(self.interval),
            reviewCount: Int(self.reviewCount)
        )
        
        // 更新字段
        self.interval = Int32(result.interval)
        self.easeFactor = result.easeFactor
        self.reviewCount += 1
        self.lastReviewDate = Date()
        self.nextReviewDate = SM2Algorithm.nextReviewDate(interval: result.interval)
        self.status = SM2Algorithm.wordStatus(reviewCount: Int(self.reviewCount), quality: quality).rawValue
        
        // 统计
        if quality.rawValue >= 3 {
            self.correctCount += 1
            self.streak += 1
        } else {
            self.incorrectCount += 1
            self.streak = 0
        }
        
        self.updatedAt = Date()
    }
    
    /// 重置单词学习状态
    func reset() {
        self.status = "new"
        self.reviewCount = 0
        self.easeFactor = 2.5
        self.interval = 0
        self.nextReviewDate = nil
        self.lastReviewDate = nil
        self.correctCount = 0
        self.incorrectCount = 0
        self.streak = 0
        self.updatedAt = Date()
    }
}
