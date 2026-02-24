//
//  StudyRecord.swift
//  EarWords
//
//  学习记录数据模型 - 用于SM-2算法计算
//

import Foundation

/// 学习记录 - 独立于Core Data的算法数据结构
struct StudyRecord: Codable, Identifiable {
    let id: UUID
    var wordId: Int32
    var word: String
    
    // SM-2 算法参数
    var easeFactor: Double      // 简易度因子 (默认 2.5)
    var interval: Int           // 当前间隔天数
    var reviewCount: Int        // 已复习次数
    
    // 时间记录
    var lastReviewDate: Date?   // 上次复习时间
    var nextReviewDate: Date?   // 下次复习时间
    var createdAt: Date         // 创建时间
    
    // 状态
    var status: WordStatus      // 学习状态
    
    // 统计
    var correctCount: Int       // 正确次数
    var incorrectCount: Int     // 错误次数
    var streak: Int             // 连续正确次数
    
    // MARK: - 初始化
    
    init(
        id: UUID = UUID(),
        wordId: Int32,
        word: String,
        easeFactor: Double = 2.5,
        interval: Int = 0,
        reviewCount: Int = 0,
        lastReviewDate: Date? = nil,
        nextReviewDate: Date? = nil,
        createdAt: Date = Date(),
        status: WordStatus = .new,
        correctCount: Int = 0,
        incorrectCount: Int = 0,
        streak: Int = 0
    ) {
        self.id = id
        self.wordId = wordId
        self.word = word
        self.easeFactor = easeFactor
        self.interval = interval
        self.reviewCount = reviewCount
        self.lastReviewDate = lastReviewDate
        self.nextReviewDate = nextReviewDate
        self.createdAt = createdAt
        self.status = status
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
        self.streak = streak
    }
    
    /// 从 WordEntity 创建
    init(from entity: WordEntity) {
        self.id = UUID()
        self.wordId = entity.id
        self.word = entity.word
        self.easeFactor = entity.easeFactor
        self.interval = Int(entity.interval)
        self.reviewCount = Int(entity.reviewCount)
        self.lastReviewDate = entity.lastReviewDate
        self.nextReviewDate = entity.nextReviewDate
        self.createdAt = entity.createdAt
        self.status = WordStatus(rawValue: entity.status) ?? .new
        self.correctCount = Int(entity.correctCount)
        self.incorrectCount = Int(entity.incorrectCount)
        self.streak = Int(entity.streak)
    }
    
    // MARK: - 计算属性
    
    /// 是否为新词
    var isNew: Bool {
        reviewCount == 0
    }
    
    /// 是否需要复习
    var isDue: Bool {
        guard let nextDate = nextReviewDate else { return true }
        return nextDate <= Date()
    }
    
    /// 距离下次复习的天数
    var daysUntilReview: Int {
        guard let nextDate = nextReviewDate else { return 0 }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: nextDate)
        return components.day ?? 0
    }
    
    /// 准确率
    var accuracy: Double {
        let total = correctCount + incorrectCount
        return total > 0 ? Double(correctCount) / Double(total) : 0
    }
    
    /// 总学习次数
    var totalReviews: Int {
        correctCount + incorrectCount
    }
    
    /// 学习进度 (0.0 - 1.0)
    var progress: Double {
        switch status {
        case .new:
            return 0.0
        case .learning:
            return min(Double(reviewCount) / 3.0, 0.9)
        case .mastered:
            return 1.0
        }
    }
    
    /// 是否需要当天重复
    var needsReviewToday: Bool {
        guard let nextDate = nextReviewDate else { return true }
        let calendar = Calendar.current
        return calendar.isDateInToday(nextDate)
    }
    
    // MARK: - 方法
    
    /// 应用复习评分 (旧版)
    mutating func applyReview(quality: ReviewQuality, timeSpent: Double = 0) -> ReviewResult {
        let result = SM2Algorithm.calculateNextReview(
            quality: quality,
            currentEaseFactor: easeFactor,
            currentInterval: interval,
            reviewCount: reviewCount
        )
        
        // 更新记录
        easeFactor = result.easeFactor
        interval = result.interval
        
        if !result.shouldRepeat {
            reviewCount += 1
        }
        
        lastReviewDate = Date()
        nextReviewDate = SM2Algorithm.nextReviewDate(interval: result.interval)
        status = SM2Algorithm.wordStatus(reviewCount: reviewCount, quality: quality)
        
        if quality.isCorrect {
            correctCount += 1
            streak += 1
        } else {
            incorrectCount += 1
            if quality.rawValue < 2 {
                streak = 0
            }
        }
        
        return ReviewResult(
            quality: quality,
            previousEaseFactor: easeFactor,
            newEaseFactor: result.easeFactor,
            previousInterval: interval,
            newInterval: result.interval,
            shouldRepeat: result.shouldRepeat,
            nextReviewDate: nextReviewDate!,
            timeSpent: timeSpent
        )
    }
    
    /// 应用简化评分
    mutating func applyReview(rating: SimpleRating, timeSpent: Double = 0) -> SimpleReviewResult {
        let result = SM2Algorithm.calculateNextReview(
            from: rating,
            currentEaseFactor: easeFactor,
            currentInterval: interval,
            reviewCount: reviewCount
        )
        
        // 更新记录
        easeFactor = result.easeFactor
        interval = result.interval
        
        if !result.shouldRepeat {
            reviewCount += 1
        }
        
        lastReviewDate = Date()
        nextReviewDate = SM2Algorithm.nextReviewDate(interval: result.interval)
        
        // 根据评分更新状态
        switch rating {
        case .forgot:
            status = .learning
            incorrectCount += 1
            streak = 0
        case .vague:
            status = .learning
            correctCount += 1
            streak += 1
        case .remembered:
            status = (reviewCount >= 3) ? .mastered : .learning
            correctCount += 1
            streak += 1
        }
        
        return SimpleReviewResult(
            rating: rating,
            previousEaseFactor: easeFactor,
            newEaseFactor: result.easeFactor,
            previousInterval: interval,
            newInterval: result.interval,
            shouldRepeat: result.shouldRepeat,
            nextReviewDate: nextReviewDate!
        )
    }
    
    /// 重置记录
    mutating func reset() {
        easeFactor = 2.5
        interval = 0
        reviewCount = 0
        lastReviewDate = nil
        nextReviewDate = nil
        status = .new
        correctCount = 0
        incorrectCount = 0
        streak = 0
    }
}

// MARK: - 学习记录比较

extension StudyRecord: Equatable {
    static func == (lhs: StudyRecord, rhs: StudyRecord) -> Bool {
        lhs.id == rhs.id
    }
}

extension StudyRecord: Comparable {
    static func < (lhs: StudyRecord, rhs: StudyRecord) -> Bool {
        // 优先级：先到期的优先
        let lhsDue = lhs.nextReviewDate ?? Date.distantPast
        let rhsDue = rhs.nextReviewDate ?? Date.distantPast
        return lhsDue < rhsDue
    }
}

// MARK: - 批量操作

extension Array where Element == StudyRecord {
    /// 获取需要复习的记录
    func dueRecords() -> [StudyRecord] {
        filter { $0.isDue }
    }
    
    /// 获取今日需要复习的记录
    func dueToday() -> [StudyRecord] {
        let calendar = Calendar.current
        return filter {
            guard let nextDate = $0.nextReviewDate else { return true }
            return nextDate <= Date() || calendar.isDateInToday(nextDate)
        }
    }
    
    /// 按状态分组
    func groupedByStatus() -> [WordStatus: [StudyRecord]] {
        Dictionary(grouping: self, by: { $0.status })
    }
    
    /// 获取新词
    var newWords: [StudyRecord] {
        filter { $0.status == .new }
    }
    
    /// 获取学习中的词
    var learningWords: [StudyRecord] {
        filter { $0.status == .learning }
    }
    
    /// 获取已掌握的词
    var masteredWords: [StudyRecord] {
        filter { $0.status == .mastered }
    }
    
    /// 平均准确率
    var averageAccuracy: Double {
        guard !isEmpty else { return 0 }
        return map { $0.accuracy }.reduce(0, +) / Double(count)
    }
    
    /// 平均简易度
    var averageEaseFactor: Double {
        guard !isEmpty else { return 2.5 }
        return map { $0.easeFactor }.reduce(0, +) / Double(count)
    }
}

// MARK: - 学习记录缓存

class StudyRecordCache {
    static let shared = StudyRecordCache()
    
    private var cache: [Int32: StudyRecord] = [:]
    private let queue = DispatchQueue(label: "com.earwords.studyrecord.cache")
    
    private init() {}
    
    /// 获取记录
    func get(wordId: Int32) -> StudyRecord? {
        queue.sync {
            cache[wordId]
        }
    }
    
    /// 设置记录
    func set(_ record: StudyRecord) {
        queue.async {
            self.cache[record.wordId] = record
        }
    }
    
    /// 批量设置
    func set(_ records: [StudyRecord]) {
        queue.async {
            for record in records {
                self.cache[record.wordId] = record
            }
        }
    }
    
    /// 移除记录
    func remove(wordId: Int32) {
        queue.async {
            self.cache.removeValue(forKey: wordId)
        }
    }
    
    /// 清空缓存
    func clear() {
        queue.async {
            self.cache.removeAll()
        }
    }
    
    /// 获取所有缓存
    func allRecords() -> [StudyRecord] {
        queue.sync {
            Array(cache.values)
        }
    }
    
    /// 获取需要复习的记录
    func dueRecords() -> [StudyRecord] {
        queue.sync {
            cache.values.filter { $0.isDue }
        }
    }
}
