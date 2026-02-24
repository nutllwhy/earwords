//
//  StudyManager.swift
//  EarWords
//
//  学习管理器 - 管理每日学习队列和复习流程
//

import Foundation
import CoreData
import Combine

/// 学习会话
struct StudySession {
    let id = UUID()
    let date: Date
    var newWords: [WordEntity]
    var reviewWords: [WordEntity]
    var currentIndex: Int = 0
    var completedWords: [WordEntity] = []
    var skippedWords: [WordEntity] = []
    
    var totalWords: Int {
        newWords.count + reviewWords.count
    }
    
    var remainingWords: Int {
        totalWords - currentIndex
    }
    
    var progress: Double {
        guard totalWords > 0 else { return 0 }
        return Double(currentIndex) / Double(totalWords)
    }
    
    var isComplete: Bool {
        currentIndex >= totalWords
    }
    
    var currentWord: WordEntity? {
        let allWords = newWords + reviewWords
        guard currentIndex < allWords.count else { return nil }
        return allWords[currentIndex]
    }
    
    mutating func nextWord() {
        currentIndex += 1
    }
    
    mutating func completeCurrentWord() {
        if let word = currentWord {
            completedWords.append(word)
        }
        currentIndex += 1
    }
    
    mutating func skipCurrentWord() {
        if let word = currentWord {
            skippedWords.append(word)
        }
        currentIndex += 1
    }
}

/// 每日学习统计
struct DailyStudyStats {
    let date: Date
    var newWordsTarget: Int
    var newWordsCompleted: Int = 0
    var reviewWordsTarget: Int
    var reviewWordsCompleted: Int = 0
    var totalTimeSpent: TimeInterval = 0
    var averageQuality: Double = 0
    
    var totalTarget: Int {
        newWordsTarget + reviewWordsTarget
    }
    
    var totalCompleted: Int {
        newWordsCompleted + reviewWordsCompleted
    }
    
    var completionRate: Double {
        guard totalTarget > 0 else { return 0 }
        return Double(totalCompleted) / Double(totalTarget)
    }
    
    var isComplete: Bool {
        totalCompleted >= totalTarget
    }
}

/// 学习管理器
class StudyManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = StudyManager()
    
    // MARK: - 发布属性
    @Published var currentSession: StudySession?
    @Published var todayStats: DailyStudyStats
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - 设置
    @Published var dailyNewWordsTarget: Int = 20 {
        didSet {
            UserDefaults.standard.set(dailyNewWordsTarget, forKey: "dailyNewWordsTarget")
        }
    }
    
    @Published var dailyReviewLimit: Int = 50 {
        didSet {
            UserDefaults.standard.set(dailyReviewLimit, forKey: "dailyReviewLimit")
        }
    }
    
    @Published var enableNotifications: Bool = true {
        didSet {
            UserDefaults.standard.set(enableNotifications, forKey: "enableStudyNotifications")
        }
    }
    
    // MARK: - 私有属性
    private let dataManager: DataManager
    private var cancellables = Set<AnyCancellable>()
    private var reviewLogs: [ReviewLogEntry] = []
    
    // MARK: - 初始化
    
    private init(dataManager: DataManager = .shared) {
        self.dataManager = dataManager
        
        // 加载设置
        self.dailyNewWordsTarget = UserDefaults.standard.integer(forKey: "dailyNewWordsTarget")
        if self.dailyNewWordsTarget == 0 { self.dailyNewWordsTarget = 20 }
        
        self.dailyReviewLimit = UserDefaults.standard.integer(forKey: "dailyReviewLimit")
        if self.dailyReviewLimit == 0 { self.dailyReviewLimit = 50 }
        
        self.enableNotifications = UserDefaults.standard.bool(forKey: "enableStudyNotifications")
        
        // 初始化今日统计
        self.todayStats = DailyStudyStats(
            date: Date(),
            newWordsTarget: self.dailyNewWordsTarget,
            reviewWordsTarget: 0
        )
        
        // 加载今日统计
        loadTodayStats()
    }
    
    // MARK: - 每日学习任务生成
    
    /// 生成今日学习队列
    /// - Returns: (新词列表, 复习列表)
    func generateTodayStudyQueue() async -> (newWords: [WordEntity], reviewWords: [WordEntity]) {
        await MainActor.run { isLoading = true }
        
        // 1. 获取今日需要复习的单词
        let dueWords = await fetchDueWords()
        
        // 2. 计算还需要多少新词
        let learnedToday = await countNewWordsLearnedToday()
        let remainingNewTarget = max(0, dailyNewWordsTarget - learnedToday)
        
        // 3. 获取新词
        let newWords = await fetchNewWords(limit: remainingNewTarget)
        
        // 4. 更新统计
        await MainActor.run {
            todayStats.newWordsTarget = dailyNewWordsTarget
            todayStats.newWordsCompleted = learnedToday
            todayStats.reviewWordsTarget = dueWords.count
            todayStats.reviewWordsCompleted = countReviewsCompletedToday()
            isLoading = false
        }
        
        return (newWords, dueWords)
    }
    
    /// 创建学习会话
    func createStudySession() async -> StudySession? {
        let (newWords, reviewWords) = await generateTodayStudyQueue()
        
        guard !newWords.isEmpty || !reviewWords.isEmpty else {
            await MainActor.run {
                errorMessage = "今日没有需要学习的单词"
            }
            return nil
        }
        
        let session = StudySession(
            date: Date(),
            newWords: newWords,
            reviewWords: reviewWords
        )
        
        await MainActor.run {
            currentSession = session
        }
        
        return session
    }
    
    /// 获取智能排序的学习队列
    /// 排序策略: 复习词优先，按间隔时间升序
    func getPrioritizedStudyQueue() async -> [WordEntity] {
        let (newWords, reviewWords) = await generateTodayStudyQueue()
        
        // 复习词按紧急程度排序（即将到期的优先）
        let sortedReviews = reviewWords.sorted { word1, word2 in
            let date1 = word1.nextReviewDate ?? Date.distantPast
            let date2 = word2.nextReviewDate ?? Date.distantPast
            return date1 < date2
        }
        
        // 新词按难度排序（简单优先）
        let sortedNewWords = newWords.sorted { $0.difficulty < $1.difficulty }
        
        // 复习词优先，然后新词
        return sortedReviews + sortedNewWords
    }
    
    // MARK: - 单词获取
    
    /// 获取需要复习的单词
    private func fetchDueWords() async -> [WordEntity] {
        await dataManager.fetchDueWords(limit: dailyReviewLimit)
    }
    
    /// 获取新单词
    private func fetchNewWords(limit: Int) async -> [WordEntity] {
        await dataManager.fetchNewWords(limit: limit)
    }
    
    /// 获取指定数量的学习队列
    func fetchStudyQueue(newWordCount: Int? = nil, reviewLimit: Int? = nil) async -> StudyQueue {
        let newCount = newWordCount ?? dailyNewWordsTarget
        let reviewCount = reviewLimit ?? dailyReviewLimit
        
        let newWords = await dataManager.fetchNewWords(limit: newCount)
        let reviewWords = await dataManager.fetchDueWords(limit: reviewCount)
        
        return StudyQueue(
            newWords: newWords,
            reviewWords: reviewWords,
            generatedAt: Date()
        )
    }
    
    // MARK: - 评分与学习记录
    
    /// 提交评分并记录学习
    func submitReview(
        word: WordEntity,
        quality: ReviewQuality,
        timeSpent: TimeInterval = 0,
        mode: StudyMode = .normal
    ) {
        // 1. 记录复习日志
        dataManager.logReview(
            word: word,
            quality: quality,
            timeSpent: timeSpent,
            mode: mode.rawValue
        )
        
        // 2. 更新本地统计
        updateStatsAfterReview(word: word, quality: quality, timeSpent: timeSpent)
        
        // 3. 添加到复习记录
        let logEntry = ReviewLogEntry(
            wordId: word.id,
            word: word.word,
            quality: quality,
            timestamp: Date(),
            timeSpent: timeSpent,
            mode: mode
        )
        reviewLogs.append(logEntry)
        
        // 4. 更新今日统计
        if word.reviewCount == 1 {
            // 新词第一次复习
            todayStats.newWordsCompleted += 1
        } else {
            todayStats.reviewWordsCompleted += 1
        }
        todayStats.totalTimeSpent += timeSpent
    }
    
    /// 提交简化评分并记录学习
    func submitReview(
        word: WordEntity,
        simpleRating: SimpleRating,
        timeSpent: TimeInterval = 0,
        mode: StudyMode = .normal
    ) {
        // 1. 记录复习日志（使用简化评分）
        let result = dataManager.logReview(
            word: word,
            simpleRating: simpleRating,
            timeSpent: timeSpent,
            mode: mode.rawValue
        )
        
        // 2. 更新本地统计（映射回 ReviewQuality 用于统计计算）
        let quality = simpleRating.reviewQuality
        updateStatsAfterReview(word: word, quality: quality, timeSpent: timeSpent)
        
        // 3. 添加到复习记录
        let logEntry = ReviewLogEntry(
            wordId: word.id,
            word: word.word,
            quality: quality,
            timestamp: Date(),
            timeSpent: timeSpent,
            mode: mode
        )
        reviewLogs.append(logEntry)
        
        // 4. 更新今日统计
        if result.previousInterval == 0 {
            // 新词第一次复习
            todayStats.newWordsCompleted += 1
        } else {
            todayStats.reviewWordsCompleted += 1
        }
        todayStats.totalTimeSpent += timeSpent
    }
    
    /// 快速评分 (使用0-5的整数)
    func rateWord(
        word: WordEntity,
        score: Int,
        timeSpent: TimeInterval = 0,
        mode: StudyMode = .normal
    ) {
        guard let quality = ReviewQuality(rawValue: Int16(score)) else { return }
        submitReview(word: word, quality: quality, timeSpent: timeSpent, mode: mode)
    }
    
    // MARK: - 统计与进度
    
    /// 加载今日统计
    private func loadTodayStats() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        // 获取今日复习记录
        let request = ReviewLogEntity.todayLogsRequest()
        if let logs = try? dataManager.context.fetch(request) {
            // 计算新词数（第一次复习）
            let newWordsCompleted = logs.filter { log in
                let wordRequest = WordEntity.fetchRequest()
                wordRequest.predicate = NSPredicate(format: "id == %d AND reviewCount == 1", log.wordId)
                return (try? dataManager.context.count(for: wordRequest)) ?? 0 > 0
            }.count
            
            // 计算复习词数
            let reviewWordsCompleted = logs.count - newWordsCompleted
            
            // 计算平均质量
            let avgQuality = logs.isEmpty ? 0.0 : Double(logs.map { $0.quality }.reduce(0, Int(+))) / Double(logs.count)
            
            // 计算总时间
            let totalTime = logs.map { $0.timeSpent }.reduce(0, +)
            
            todayStats = DailyStudyStats(
                date: Date(),
                newWordsTarget: dailyNewWordsTarget,
                newWordsCompleted: newWordsCompleted,
                reviewWordsTarget: dataManager.dueWordsCount,
                reviewWordsCompleted: reviewWordsCompleted,
                totalTimeSpent: totalTime,
                averageQuality: avgQuality
            )
        }
    }
    
    /// 更新统计
    private func updateStatsAfterReview(word: WordEntity, quality: ReviewQuality, timeSpent: TimeInterval) {
        // 更新平均质量
        let totalReviews = todayStats.totalCompleted + 1
        let newTotalQuality = todayStats.averageQuality * Double(todayStats.totalCompleted) + Double(quality.rawValue)
        todayStats.averageQuality = newTotalQuality / Double(totalReviews)
    }
    
    /// 统计今日新学单词数
    private func countNewWordsLearnedToday() async -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        let request = WordEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "status != %@ AND lastReviewDate >= %@",
            "new", startOfDay as CVarArg
        )
        
        return (try? dataManager.context.count(for: request)) ?? 0
    }
    
    /// 统计今日已完成复习数
    private func countReviewsCompletedToday() -> Int {
        let request = ReviewLogEntity.todayLogsRequest()
        return (try? dataManager.context.count(for: request)) ?? 0
    }
    
    // MARK: - 学习模式
    
    /// 进入音频复习模式
    func startAudioReviewSession() async -> StudySession? {
        let words = await fetchDueWords()
        guard !words.isEmpty else { return nil }
        
        let session = StudySession(
            date: Date(),
            newWords: [],
            reviewWords: words
        )
        
        await MainActor.run {
            currentSession = session
        }
        
        return session
    }
    
    /// 快速复习模式（仅复习）
    func startQuickReviewSession(limit: Int = 20) async -> StudySession? {
        let words = await dataManager.fetchDueWords(limit: limit)
        guard !words.isEmpty else { return nil }
        
        let session = StudySession(
            date: Date(),
            newWords: [],
            reviewWords: words
        )
        
        await MainActor.run {
            currentSession = session
        }
        
        return session
    }
    
    // MARK: - 工具方法
    
    /// 获取某单词的复习历史
    func getReviewHistory(for wordId: Int32) -> [ReviewLogEntity] {
        let request = ReviewLogEntity.logsForWord(wordId: wordId)
        return (try? dataManager.context.fetch(request)) ?? []
    }
    
    /// 获取学习热力图数据（最近30天）
    func getStudyHeatmap(days: Int = 30) -> [Date: Int] {
        let calendar = Calendar.current
        var heatmap: [Date: Int] = [:]
        
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            
            let request = ReviewLogEntity.fetchRequest()
            request.predicate = NSPredicate(format: "reviewDate >= %@ AND reviewDate < %@",
                startOfDay as CVarArg,
                calendar.date(byAdding: .day, value: 1, to: startOfDay)! as CVarArg
            )
            
            let count = (try? dataManager.context.count(for: request)) ?? 0
            heatmap[startOfDay] = count
        }
        
        return heatmap
    }
    
    /// 预测未来复习量
    func predictUpcomingReviews(for days: Int = 7) -> [Date: Int] {
        let calendar = Calendar.current
        var predictions: [Date: Int] = [:]
        
        let allWords = try? dataManager.context.fetch(WordEntity.fetchRequest())
        
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let count = allWords?.filter { word in
                guard let nextReview = word.nextReviewDate else { return false }
                return nextReview >= startOfDay && nextReview < endOfDay
            }.count ?? 0
            
            predictions[startOfDay] = count
        }
        
        return predictions
    }
    
    /// 重置当前会话
    func resetSession() {
        currentSession = nil
    }
    
    /// 跳过当前单词
    func skipCurrentWord() {
        guard var session = currentSession else { return }
        session.skipCurrentWord()
        currentSession = session
    }
    
    /// 前进到下一个单词
    func moveToNextWord() {
        guard var session = currentSession else { return }
        session.nextWord()
        currentSession = session
    }
}

// MARK: - 辅助类型

/// 学习队列
struct StudyQueue {
    let newWords: [WordEntity]
    let reviewWords: [WordEntity]
    let generatedAt: Date
    
    var totalCount: Int {
        newWords.count + reviewWords.count
    }
    
    var isEmpty: Bool {
        newWords.isEmpty && reviewWords.isEmpty
    }
    
    /// 合并队列（复习优先）
    var prioritized: [WordEntity] {
        reviewWords + newWords
    }
}

/// 学习模式
enum StudyMode: String {
    case normal = "normal"   // 正常学习
    case audio = "audio"     // 音频复习
    case quick = "quick"     // 快速复习
    case test = "test"       // 测试模式
}

/// 复习日志条目（内存中）
struct ReviewLogEntry: Identifiable {
    let id = UUID()
    let wordId: Int32
    let word: String
    let quality: ReviewQuality
    let timestamp: Date
    let timeSpent: TimeInterval
    let mode: StudyMode
}
