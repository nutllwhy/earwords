//
//  StudyViewModel.swift
//  EarWords
//
//  学习视图模型 - 完整版
//

import SwiftUI
import Combine

/// 今日学习统计
struct TodayStudyStats {
    let newWordsCount: Int
    let reviewWordsCount: Int
    let correctCount: Int
    let incorrectCount: Int
    let streakDays: Int
    let accuracy: Double
    let totalTime: TimeInterval
    let tomorrowPreview: [Int] // [复习数, 新词数]
}

/// 学习会话状态
enum StudySessionState {
    case idle
    case loading
    case studying
    case complete
    case error
}

@MainActor
class StudyViewModel: ObservableObject {
    
    // MARK: - 发布属性
    @Published var studyQueue: [WordEntity] = []
    @Published var currentIndex = 0
    @Published var correctCount = 0
    @Published var incorrectCount = 0
    @Published var showSettings = false
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    // MARK: - 学习统计
    @Published var todayStats: TodayStudyStats = TodayStudyStats(
        newWordsCount: 0,
        reviewWordsCount: 0,
        correctCount: 0,
        incorrectCount: 0,
        streakDays: 0,
        accuracy: 0,
        totalTime: 0,
        tomorrowPreview: []
    )
    
    // MARK: - 私有属性
    private let dataManager = DataManager.shared
    private let studyManager = StudyManager.shared
    private var startTime: Date?
    private var newWordsInQueue: [WordEntity] = []
    private var reviewWordsInQueue: [WordEntity] = []
    
    // MARK: - 计算属性
    
    var currentWord: WordEntity? {
        studyQueue.indices.contains(currentIndex) ? studyQueue[currentIndex] : nil
    }
    
    var nextWord: WordEntity? {
        let nextIndex = currentIndex + 1
        return studyQueue.indices.contains(nextIndex) ? studyQueue[nextIndex] : nil
    }
    
    var totalCount: Int {
        studyQueue.count
    }
    
    var isStudyComplete: Bool {
        studyQueue.isEmpty == false && currentIndex >= studyQueue.count
    }
    
    var newWordsCount: Int {
        newWordsInQueue.count
    }
    
    var reviewWordsCount: Int {
        reviewWordsInQueue.count
    }
    
    // MARK: - 初始化
    
    init() {
        loadTodayStats()
    }
    
    // MARK: - 数据加载
    
    /// 加载今日学习队列
    func loadStudyQueue() {
        isLoading = true
        showError = false
        
        Task {
            do {
                // 获取今日学习队列
                let queue = await studyManager.fetchStudyQueue()
                
                guard !queue.isEmpty else {
                    await MainActor.run {
                        self.isLoading = false
                        self.studyQueue = []
                        self.currentIndex = 0
                    }
                    return
                }
                
                // 保存分类
                self.newWordsInQueue = queue.newWords
                self.reviewWordsInQueue = queue.reviewWords
                
                // 合并队列：复习词优先，然后新词
                let combinedQueue = queue.prioritized
                
                await MainActor.run {
                    self.studyQueue = combinedQueue
                    self.currentIndex = 0
                    self.correctCount = 0
                    self.incorrectCount = 0
                    self.startTime = Date()
                    self.isLoading = false
                    
                    // 更新今日统计
                    self.updateTodayStats()
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "加载学习队列失败: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    /// 刷新学习队列（保留当前进度）
    func refreshQueue() {
        Task {
            let queue = await studyManager.fetchStudyQueue()
            await MainActor.run {
                self.newWordsInQueue = queue.newWords
                self.reviewWordsInQueue = queue.reviewWords
                self.studyQueue = queue.prioritized
            }
        }
    }
    
    // MARK: - 评分与学习记录
    
    /// 对当前单词评分
    func rateCurrentWord(quality: ReviewQuality) {
        guard let word = currentWord else { return }
        
        // 计算学习耗时
        let timeSpent: TimeInterval
        if let start = startTime {
            timeSpent = Date().timeIntervalSince(start)
        } else {
            timeSpent = 0
        }
        
        // 1. 记录评分统计
        if quality.isCorrect {
            correctCount += 1
        } else {
            incorrectCount += 1
        }
        
        // 2. 应用 SM-2 算法并保存到 Core Data
        let result = dataManager.logReview(
            word: word,
            quality: quality,
            timeSpent: timeSpent,
            mode: "normal"
        )
        
        // 3. 记录到 StudyManager
        studyManager.submitReview(
            word: word,
            quality: quality,
            timeSpent: timeSpent,
            mode: .normal
        )
        
        // 4. 打印日志（调试用）
        print("""
        [学习记录] \(word.word)
        - 评分: \(quality.rawValue) (\(quality.description))
        - 结果: \(quality.isCorrect ? "正确" : "错误")
        - 旧间隔: \(result.previousInterval) 天
        - 新间隔: \(result.newInterval) 天
        - 旧简易度: \(String(format: "%.2f", result.previousEaseFactor))
        - 新简易度: \(String(format: "%.2f", result.newEaseFactor))
        - 下次复习: \(formatDate(result.nextReviewDate))
        - 耗时: \(String(format: "%.1f", timeSpent)) 秒
        """)
        
        // 5. 移动到下一个单词
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentIndex < studyQueue.count - 1 {
                currentIndex += 1
                startTime = Date() // 重置计时
            } else {
                // 学习完成
                completeStudySession()
            }
        }
    }
    
    /// 跳过当前单词
    func skipCurrentWord() {
        guard currentWord != nil else { return }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentIndex < studyQueue.count - 1 {
                currentIndex += 1
                startTime = Date()
            } else {
                completeStudySession()
            }
        }
    }
    
    // MARK: - 学习完成
    
    /// 完成学习会话
    private func completeStudySession() {
        currentIndex = studyQueue.count // 标记为完成
        
        // 生成今日统计
        generateTodayStats()
        
        // 生成明日预览
        generateTomorrowPreview()
        
        print("[学习完成] 今日学习了 \(correctCount + incorrectCount) 个单词")
    }
    
    /// 生成今日统计
    private func generateTodayStats() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        // 获取今日学习记录
        let logs = dataManager.fetchStudyRecords(for: Date())
        
        let correct = logs.filter { $0.result == "correct" }.count
        let incorrect = logs.filter { $0.result == "incorrect" }.count
        let total = logs.count
        let accuracy = total > 0 ? Double(correct) / Double(total) : 0
        
        // 计算连续打卡天数（简化版）
        let streakDays = calculateStreakDays()
        
        // 总学习时间
        let totalTime = logs.map { $0.timeSpent }.reduce(0, +)
        
        todayStats = TodayStudyStats(
            newWordsCount: newWordsInQueue.count,
            reviewWordsCount: reviewWordsInQueue.count,
            correctCount: correct,
            incorrectCount: incorrect,
            streakDays: streakDays,
            accuracy: accuracy,
            totalTime: totalTime,
            tomorrowPreview: generateTomorrowPreview()
        )
    }
    
    /// 生成明日学习预览
    private func generateTomorrowPreview() -> [Int] {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) else {
            return [0, 0]
        }
        
        let startOfTomorrow = calendar.startOfDay(for: tomorrow)
        let endOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfTomorrow)!
        
        // 获取明天需要复习的单词
        let allWords = try? dataManager.context.fetch(WordEntity.fetchRequest())
        let dueTomorrow = allWords?.filter { word in
            guard let nextReview = word.nextReviewDate else { return false }
            return nextReview >= startOfTomorrow && nextReview < endOfTomorrow
        }.count ?? 0
        
        // 明日新词数量（剩余目标）
        let dailyTarget = UserDefaults.standard.integer(forKey: "dailyNewWordsTarget")
        let learnedToday = newWordsInQueue.filter { $0.status != "new" }.count
        let remainingNew = max(0, dailyTarget - learnedToday)
        
        return [dueTomorrow, remainingNew]
    }
    
    // MARK: - 统计计算
    
    /// 加载今日统计
    private func loadTodayStats() {
        updateTodayStats()
    }
    
    /// 更新今日统计
    private func updateTodayStats() {
        // 这里可以根据需要实时更新统计
        // 目前主要在完成时生成完整统计
    }
    
    /// 计算连续打卡天数
    private func calculateStreakDays() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()
        
        // 倒序检查每天是否有学习记录
        while true {
            let startOfDay = calendar.startOfDay(for: checkDate)
            let logs = dataManager.fetchStudyRecords(for: startOfDay)
            
            if !logs.isEmpty {
                streak += 1
                // 往前推一天
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    break
                }
                checkDate = previousDay
            } else {
                // 如果今天还没学习，不中断连续天数
                if calendar.isDateInToday(checkDate) && streak == 0 {
                    guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                        break
                    }
                    checkDate = previousDay
                    continue
                }
                break
            }
        }
        
        return streak
    }
    
    // MARK: - 工具方法
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
