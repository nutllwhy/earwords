//
//  StudyProgressManager.swift
//  EarWords
//
//  学习进度管理器 - 自动保存/恢复学习状态
//  P0级问题修复：防止App被杀后台后学习进度丢失
//

import Foundation
import Combine

/// 学习进度数据模型
struct StudyProgress: Codable {
    let currentIndex: Int
    let wordIds: [Int32]          // 学习队列中的单词ID
    let ratedWordIds: [Int32]     // 已评分的单词ID
    let ratings: [Int]            // 对应评分值
    let correctCount: Int
    let incorrectCount: Int
    let sessionStartTime: Date
    let lastSaveTime: Date
    let studyMode: String         // 学习模式标识
}

/// 学习会话状态
enum ProgressRecoveryState {
    case noProgress          // 无保存的进度
    case validProgress       // 有有效进度
    case expiredProgress     // 进度已过期（超过30分钟）
}

@MainActor
class StudyProgressManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = StudyProgressManager()
    
    // MARK: - 发布属性
    @Published var hasRecoveredProgress: Bool = false
    @Published var recoveredProgress: StudyProgress?
    
    // MARK: - 常量
    private let progressKey = "com.earwords.study.progress"
    private let expirationMinutes: TimeInterval = 30  // 30分钟过期时间
    
    // MARK: - 私有属性
    private var cancellables = Set<AnyCancellable>()
    private var currentProgress: StudyProgress?
    
    // MARK: - 初始化
    private init() {
        setupNotifications()
    }
    
    // MARK: - 通知监听
    private func setupNotifications() {
        // 监听App进入后台
        NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.saveCurrentProgress()
                }
            }
            .store(in: &cancellables)
        
        // 监听App即将终止
        NotificationCenter.default
            .publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.saveCurrentProgress()
                }
            }
            .store(in: &cancellables)
        
        // 监听App内存警告
        NotificationCenter.default
            .publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.saveCurrentProgress()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 进度检查
    
    /// 检查是否存在可恢复的进度
    func checkRecoveryState() -> ProgressRecoveryState {
        guard let data = UserDefaults.standard.data(forKey: progressKey) else {
            return .noProgress
        }
        
        do {
            let progress = try JSONDecoder().decode(StudyProgress.self, from: data)
            
            // 检查是否已完成
            if progress.currentIndex >= progress.wordIds.count {
                clearProgress()
                return .noProgress
            }
            
            // 检查是否过期（超过30分钟）
            let timeSinceLastSave = Date().timeIntervalSince(progress.lastSaveTime)
            if timeSinceLastSave > expirationMinutes * 60 {
                clearProgress()
                return .expiredProgress
            }
            
            recoveredProgress = progress
            return .validProgress
            
        } catch {
            print("[进度恢复] 解析进度数据失败: \(error)")
            clearProgress()
            return .noProgress
        }
    }
    
    /// 获取恢复提示信息
    func getRecoveryMessage() -> String {
        guard let progress = recoveredProgress else {
            return ""
        }
        
        let total = progress.wordIds.count
        let current = progress.currentIndex + 1
        let remaining = total - progress.currentIndex
        let timeSinceLastSave = Date().timeIntervalSince(progress.lastSaveTime)
        
        let timeString: String
        if timeSinceLastSave < 60 {
            timeString = "刚刚"
        } else if timeSinceLastSave < 3600 {
            timeString = "\(Int(timeSinceLastSave / 60))分钟前"
        } else {
            timeString = "\(Int(timeSinceLastSave / 3600))小时前"
        }
        
        return "检测到未完成的会话（\(timeString)）\n当前进度：第 \(current)/\(total) 个单词，剩余 \(remaining) 个"
    }
    
    // MARK: - 进度保存
    
    /// 保存当前学习进度
    func saveProgress(
        currentIndex: Int,
        wordIds: [Int32],
        ratedWordIds: [Int32],
        ratings: [Int],
        correctCount: Int,
        incorrectCount: Int,
        sessionStartTime: Date,
        studyMode: String = "normal"
    ) {
        let progress = StudyProgress(
            currentIndex: currentIndex,
            wordIds: wordIds,
            ratedWordIds: ratedWordIds,
            ratings: ratings,
            correctCount: correctCount,
            incorrectCount: incorrectCount,
            sessionStartTime: sessionStartTime,
            lastSaveTime: Date(),
            studyMode: studyMode
        )
        
        currentProgress = progress
        
        do {
            let data = try JSONEncoder().encode(progress)
            UserDefaults.standard.set(data, forKey: progressKey)
            print("[进度保存] 成功保存进度 - 当前索引: \(currentIndex), 单词总数: \(wordIds.count)")
        } catch {
            print("[进度保存] 保存失败: \(error)")
        }
    }
    
    /// 保存当前学习进度（使用已有数据）
    private func saveCurrentProgress() {
        guard let progress = currentProgress else { return }
        
        do {
            var updatedProgress = progress
            // 使用反射更新lastSaveTime
            let encoder = JSONEncoder()
            let data = try encoder.encode(updatedProgress)
            UserDefaults.standard.set(data, forKey: progressKey)
            print("[进度保存] 自动保存成功")
        } catch {
            print("[进度保存] 自动保存失败: \(error)")
        }
    }
    
    /// 更新当前索引（用于进度变化时快速保存）
    func updateCurrentIndex(_ index: Int) {
        guard var progress = currentProgress else { return }
        
        // 重新创建progress以更新值
        let updatedProgress = StudyProgress(
            currentIndex: index,
            wordIds: progress.wordIds,
            ratedWordIds: progress.ratedWordIds,
            ratings: progress.ratings,
            correctCount: progress.correctCount,
            incorrectCount: progress.incorrectCount,
            sessionStartTime: progress.sessionStartTime,
            lastSaveTime: Date(),
            studyMode: progress.studyMode
        )
        
        currentProgress = updatedProgress
        
        do {
            let data = try JSONEncoder().encode(updatedProgress)
            UserDefaults.standard.set(data, forKey: progressKey)
        } catch {
            print("[进度保存] 索引更新失败: \(error)")
        }
    }
    
    /// 添加评分记录
    func addRating(wordId: Int32, rating: Int) {
        guard var progress = currentProgress else { return }
        
        var ratedWordIds = progress.ratedWordIds
        var ratings = progress.ratings
        
        // 如果已经评分过，更新评分
        if let index = ratedWordIds.firstIndex(of: wordId) {
            ratings[index] = rating
        } else {
            ratedWordIds.append(wordId)
            ratings.append(rating)
        }
        
        let updatedProgress = StudyProgress(
            currentIndex: progress.currentIndex,
            wordIds: progress.wordIds,
            ratedWordIds: ratedWordIds,
            ratings: ratings,
            correctCount: progress.correctCount,
            incorrectCount: progress.incorrectCount,
            sessionStartTime: progress.sessionStartTime,
            lastSaveTime: Date(),
            studyMode: progress.studyMode
        )
        
        currentProgress = updatedProgress
        
        do {
            let data = try JSONEncoder().encode(updatedProgress)
            UserDefaults.standard.set(data, forKey: progressKey)
        } catch {
            print("[进度保存] 评分记录失败: \(error)")
        }
    }
    
    // MARK: - 进度恢复
    
    /// 恢复学习进度
    func restoreProgress() -> StudyProgress? {
        guard let progress = recoveredProgress else { return nil }
        
        hasRecoveredProgress = true
        currentProgress = progress
        
        print("[进度恢复] 成功恢复进度 - 当前索引: \(progress.currentIndex), 已评分: \(progress.ratedWordIds.count)")
        return progress
    }
    
    /// 清除保存的进度
    func clearProgress() {
        UserDefaults.standard.removeObject(forKey: progressKey)
        recoveredProgress = nil
        currentProgress = nil
        hasRecoveredProgress = false
        print("[进度管理] 已清除保存的进度")
    }
    
    /// 完成学习会话后清除进度
    func markSessionComplete() {
        clearProgress()
    }
    
    // MARK: - 工具方法
    
    /// 检查特定单词是否已评分
    func isWordRated(wordId: Int32) -> Bool {
        guard let progress = currentProgress else { return false }
        return progress.ratedWordIds.contains(wordId)
    }
    
    /// 获取单词的评分
    func getWordRating(wordId: Int32) -> Int? {
        guard let progress = currentProgress else { return nil }
        guard let index = progress.ratedWordIds.firstIndex(of: wordId) else { return nil }
        guard index < progress.ratings.count else { return nil }
        return progress.ratings[index]
    }
    
    /// 获取会话持续时间
    func getSessionDuration() -> TimeInterval {
        guard let progress = currentProgress else { return 0 }
        return Date().timeIntervalSince(progress.sessionStartTime)
    }
    
    /// 获取会话已学习单词数
    func getStudiedCount() -> Int {
        guard let progress = currentProgress else { return 0 }
        return progress.ratedWordIds.count
    }
}

// MARK: - StudyViewModel 扩展

extension StudyViewModel {
    
    /// 检查并询问是否恢复进度
    func checkAndOfferRecovery() -> Bool {
        let state = StudyProgressManager.shared.checkRecoveryState()
        
        switch state {
        case .noProgress, .expiredProgress:
            return false
        case .validProgress:
            return true
        }
    }
    
    /// 恢复学习进度
    func restoreStudyProgress() -> Bool {
        guard let progress = StudyProgressManager.shared.restoreProgress() else {
            return false
        }
        
        // 恢复状态
        self.currentIndex = progress.currentIndex
        self.correctCount = progress.correctCount
        self.incorrectCount = progress.incorrectCount
        self.startTime = progress.sessionStartTime
        
        // 从DataManager获取单词实体
        Task {
            do {
                let allWords = try? DataManager.shared.context.fetch(WordEntity.fetchRequest())
                let wordMap = Dictionary(uniqueKeysWithValues: (allWords ?? []).map { ($0.id, $0) })
                
                // 按保存的顺序恢复单词队列
                let restoredQueue = progress.wordIds.compactMap { wordMap[$0] }
                
                await MainActor.run {
                    self.studyQueue = restoredQueue
                    
                    // 恢复已评分的统计
                    if !progress.ratedWordIds.isEmpty {
                        // 这里可以根据需要恢复更详细的统计
                        print("[进度恢复] 恢复了 \(progress.ratedWordIds.count) 个已评分单词的记录")
                    }
                    
                    self.isLoading = false
                }
            }
        }
        
        return true
    }
    
    /// 开始新的学习会话（清除旧进度）
    func startNewStudySession() {
        StudyProgressManager.shared.clearProgress()
        loadStudyQueue()
    }
    
    /// 保存当前进度（用于View调用）
    func saveCurrentStudyProgress() {
        guard !studyQueue.isEmpty else { return }
        
        let wordIds = studyQueue.map { $0.id }
        let ratedWordIds: [Int32] = [] // 可以根据需要记录已评分的单词
        let ratings: [Int] = []
        
        StudyProgressManager.shared.saveProgress(
            currentIndex: currentIndex,
            wordIds: wordIds,
            ratedWordIds: ratedWordIds,
            ratings: ratings,
            correctCount: correctCount,
            incorrectCount: incorrectCount,
            sessionStartTime: startTime ?? Date()
        )
    }
}

// MARK: - 便捷方法

extension StudyProgressManager {
    
    /// 快速保存方法（供StudyViewModel使用）
    func quickSave(
        studyQueue: [WordEntity],
        currentIndex: Int,
        correctCount: Int,
        incorrectCount: Int,
        startTime: Date?
    ) {
        let wordIds = studyQueue.map { $0.id }
        
        saveProgress(
            currentIndex: currentIndex,
            wordIds: wordIds,
            ratedWordIds: [],
            ratings: [],
            correctCount: correctCount,
            incorrectCount: incorrectCount,
            sessionStartTime: startTime ?? Date()
        )
    }
}
