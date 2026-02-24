//
//  SM2UsageExample.swift
//  EarWords
//
//  SM-2 算法使用示例
//

import Foundation
import CoreData

// MARK: - 基础使用示例

class SM2UsageExamples {
    
    // MARK: 1. 基础评分
    
    /// 示例：对单词进行评分
    func basicRatingExample(word: WordEntity) {
        // 用户回忆结果：犹豫后正确（3分）
        let result = word.applyReview(quality: .hesitation, timeSpent: 4.5)
        
        print("评分结果:")
        print("- 评分: \(result.quality.description)")
        print("- 是否当天重复: \(result.shouldRepeat)")
        print("- 新间隔: \(result.newInterval) 天")
        print("- 下次复习: \(result.nextReviewDate)")
        print("- 简易度变化: \(String(format: "%.2f", result.easeFactorChange))")
    }
    
    /// 示例：快速评分（使用整数0-5）
    func quickRatingExample(word: WordEntity) {
        // 使用整数评分
        if let result = word.rate(5, timeSpent: 2.0) {
            print("完美！下次复习在 \(result.newInterval) 天后")
        }
    }
    
    // MARK: 2. 学习会话
    
    /// 示例：开始每日学习
    func startDailyStudyExample() async {
        let studyManager = StudyManager.shared
        
        // 创建学习会话
        guard let session = await studyManager.createStudySession() else {
            print("今日没有需要学习的单词")
            return
        }
        
        print("今日学习队列:")
        print("- 新词: \(session.newWords.count)")
        print("- 复习: \(session.reviewWords.count)")
        
        // 遍历学习
        while let word = session.currentWord {
            // 显示单词卡片...
            
            // 用户评分后
            studyManager.submitReview(
                word: word,
                quality: .good,
                timeSpent: 3.0
            )
            
            studyManager.moveToNextWord()
        }
    }
    
    // MARK: 3. 获取学习队列
    
    /// 示例：获取今日学习队列
    func fetchTodayQueueExample() async {
        let studyManager = StudyManager.shared
        
        let queue = await studyManager.fetchStudyQueue(
            newWordCount: 20,
            reviewLimit: 50
        )
        
        print("学习队列:")
        print("- 新词: \(queue.newWords.count)")
        print("- 复习: \(queue.reviewWords.count)")
        
        // 按优先级排序后的队列
        let prioritized = queue.prioritized
        for word in prioritized.prefix(5) {
            print("- \(word.word): \(word.status)")
        }
    }
    
    // MARK: 4. 使用 StudyRecord
    
    /// 示例：使用 StudyRecord 进行算法计算
    func studyRecordExample() {
        // 创建学习记录
        var record = StudyRecord(
            wordId: 1,
            word: "abandon",
            easeFactor: 2.5,
            interval: 0,
            reviewCount: 0
        )
        
        // 第一次复习
        var result = record.applyReview(quality: .perfect, timeSpent: 2.0)
        print("第一次复习后:")
        print("- 间隔: \(result.newInterval) 天")
        print("- 下次复习: \(result.nextReviewDate)")
        
        // 第二次复习
        result = record.applyReview(quality: .good, timeSpent: 3.0)
        print("第二次复习后:")
        print("- 间隔: \(result.newInterval) 天")
        print("- 连续正确: \(record.streak)")
        
        // 忘记后重置
        result = record.applyReview(quality: .blackOut, timeSpent: 5.0)
        print("忘记后:")
        print("- 间隔重置为: \(result.newInterval)")
        print("- 连续正确重置: \(record.streak)")
    }
    
    // MARK: 5. 批量操作
    
    /// 示例：批量评分
    func batchReviewExample(words: [WordEntity]) {
        let dataManager = DataManager.shared
        
        for word in words {
            // 根据用户表现决定评分
            let quality: ReviewQuality = determineQuality(for: word)
            
            // 记录复习
            let log = dataManager.logReview(
                word: word,
                quality: quality,
                timeSpent: Double.random(in: 2...5),
                mode: "normal"
            )
            
            print("已记录: \(log.word) - \(log.quality)分")
        }
    }
    
    private func determineQuality(for word: WordEntity) -> ReviewQuality {
        // 实际应用中根据用户表现判断
        return .good
    }
    
    // MARK: 6. 学习统计
    
    /// 示例：查看学习统计
    func viewStatisticsExample() {
        let studyManager = StudyManager.shared
        
        // 今日统计
        let stats = studyManager.todayStats
        print("今日学习统计:")
        print("- 新词目标: \(stats.newWordsTarget)")
        print("- 新词完成: \(stats.newWordsCompleted)")
        print("- 复习目标: \(stats.reviewWordsTarget)")
        print("- 复习完成: \(stats.reviewWordsCompleted)")
        print("- 完成率: \(Int(stats.completionRate * 100))%")
        
        // 学习热力图
        let heatmap = studyManager.getStudyHeatmap(days: 30)
        for (date, count) in heatmap.sorted(by: { $0.key < $1.key }) {
            let dateStr = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
            print("\(dateStr): \(count) 次复习")
        }
    }
    
    // MARK: 7. 预测复习量
    
    /// 示例：预测未来复习量
    func predictReviewsExample() {
        let studyManager = StudyManager.shared
        
        let predictions = studyManager.predictUpcomingReviews(for: 7)
        
        print("未来7天复习预测:")
        for (date, count) in predictions.sorted(by: { $0.key < $1.key }) {
            let dateStr = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .none)
            let bar = String(repeating: "█", count: min(count, 20))
            print("\(dateStr): \(bar) (\(count))")
        }
    }
    
    // MARK: 8. 音频复习模式
    
    /// 示例：音频复习模式
    func audioReviewExample() async {
        let studyManager = StudyManager.shared
        
        // 开始音频复习会话
        guard let session = await studyManager.startAudioReviewSession() else {
            print("没有需要复习的单词")
            return
        }
        
        for word in session.reviewWords {
            // 播放单词音频...
            print("播放: \(word.word)")
            
            // 用户回忆后评分
            studyManager.submitReview(
                word: word,
                quality: .good,
                timeSpent: 2.0,
                mode: .audio
            )
        }
    }
    
    // MARK: 9. 不同学习模式
    
    /// 示例：不同学习模式
    func studyModesExample() async {
        let studyManager = StudyManager.shared
        
        // 模式1: 正常学习（新词+复习）
        let normalSession = await studyManager.createStudySession()
        
        // 模式2: 快速复习（仅复习）
        let quickSession = await studyManager.startQuickReviewSession(limit: 20)
        
        // 模式3: 音频复习
        let audioSession = await studyManager.startAudioReviewSession()
        
        print("可用学习模式:")
        print("- 正常学习: \(normalSession != nil)")
        print("- 快速复习: \(quickSession != nil)")
        print("- 音频复习: \(audioSession != nil)")
    }
    
    // MARK: 10. 算法参数详解
    
    /// 示例：理解算法参数
    func algorithmParametersExample() {
        print("SM-2 算法参数:")
        print("- 默认简易度: \(SM2Algorithm.defaultEaseFactor)")
        print("- 最小简易度: \(SM2Algorithm.minEaseFactor)")
        print("- 最大间隔: \(SM2Algorithm.maxInterval) 天")
        
        print("\nPRD 评分标准:")
        for quality in ReviewQuality.allCases {
            print("- \(quality.rawValue)分 (\(quality.description)): \(quality.nextIntervalDays) 天后复习")
        }
    }
    
    // MARK: 11. 错误处理
    
    /// 示例：错误处理
    func errorHandlingExample() {
        let studyManager = StudyManager.shared
        
        // 检查错误
        if let error = studyManager.errorMessage {
            print("错误: \(error)")
        }
        
        // 检查加载状态
        if studyManager.isLoading {
            print("加载中...")
        }
    }
    
    // MARK: 12. 复习历史
    
    /// 示例：查看复习历史
    func reviewHistoryExample(wordId: Int32) {
        let studyManager = StudyManager.shared
        let logs = studyManager.getReviewHistory(for: wordId)
        
        print("复习历史:")
        for log in logs {
            let date = DateFormatter.localizedString(from: log.reviewDate, dateStyle: .short, timeStyle: .short)
            print("- \(date): \(log.quality)分, 间隔 \(log.previousInterval) → \(log.newInterval) 天")
        }
    }
}

// MARK: - SwiftUI 使用示例

/*
import SwiftUI

struct StudyView: View {
    @StateObject private var studyManager = StudyManager.shared
    @State private var currentWord: WordEntity?
    @State private var showingAnswer = false
    
    var body: some View {
        VStack {
            // 进度条
            ProgressView(value: studyManager.currentSession?.progress ?? 0)
                .padding()
            
            // 单词卡片
            if let word = currentWord {
                WordCardView(word: word, showingAnswer: $showingAnswer)
                
                if showingAnswer {
                    // 评分按钮
                    HStack(spacing: 10) {
                        ForEach(ReviewQuality.allCases, id: \.self) { quality in
                            RatingButton(quality: quality) {
                                submitReview(quality: quality)
                            }
                        }
                    }
                    .padding()
                } else {
                    Button("显示答案") {
                        showingAnswer = true
                    }
                    .padding()
                }
            } else {
                // 今日完成
                CompletionView(stats: studyManager.todayStats)
            }
        }
        .task {
            await studyManager.createStudySession()
            currentWord = studyManager.currentSession?.currentWord
        }
    }
    
    private func submitReview(quality: ReviewQuality) {
        guard let word = currentWord else { return }
        
        studyManager.submitReview(
            word: word,
            quality: quality,
            timeSpent: 3.0
        )
        
        studyManager.moveToNextWord()
        currentWord = studyManager.currentSession?.currentWord
        showingAnswer = false
    }
}

struct RatingButton: View {
    let quality: ReviewQuality
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Text("\(quality.rawValue)")
                    .font(.title2)
                    .bold()
                Text(quality.description)
                    .font(.caption)
            }
            .frame(width: 50, height: 60)
            .background(buttonColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
    }
    
    private var buttonColor: Color {
        switch quality {
        case .blackOut: return .red
        case .incorrect: return .orange
        case .difficult: return .yellow
        case .hesitation: return .blue
        case .good: return .green
        case .perfect: return .purple
        }
    }
}
*/

// MARK: - 完整学习流程示例

/*
// 在 App 启动时初始化
@main
struct EarWordsApp: App {
    let persistenceController = DataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(StudyManager.shared)
        }
    }
}

// 在学习视图中
struct DailyStudyView: View {
    @EnvironmentObject var studyManager: StudyManager
    
    var body: some View {
        NavigationView {
            VStack {
                // 今日统计卡片
                TodayStatsCard(stats: studyManager.todayStats)
                
                // 开始学习按钮
                Button("开始学习") {
                    Task {
                        await studyManager.createStudySession()
                    }
                }
                .disabled(studyManager.isLoading)
            }
            .navigationTitle("今日学习")
        }
    }
}
*/
