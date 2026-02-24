//
//  EarWordsIntegrationTests.swift
//  EarWordsTests
//
//  集成测试 - 测试完整学习流程
//

import XCTest
@testable import EarWords

final class EarWordsIntegrationTests: XCTestCase {
    
    var dataManager: DataManager!
    var studyManager: StudyManager!
    var audioManager: AudioPlayerManager!
    
    override func setUp() {
        super.setUp()
        dataManager = DataManager.shared
        studyManager = StudyManager.shared
        audioManager = AudioPlayerManager.shared
        
        // 清理测试数据
        dataManager.deleteAllWords()
        audioManager.clearQueue()
    }
    
    override func tearDown() {
        dataManager.deleteAllWords()
        audioManager.clearQueue()
        super.tearDown()
    }
    
    // MARK: - 完整学习流程测试
    
    func testCompleteStudyFlow() async throws {
        // 1. 导入词库
        let testWords = (1...30).map { i in
            WordJSON(
                id: i,
                word: "word\(i)",
                phonetic: "/wɜːd\(i)/",
                pos: "n.",
                meaning: "单词\(i)",
                example: "This is word \(i).",
                extra: nil,
                chapter: "01_测试",
                chapterKey: "01_test",
                difficulty: Int(i % 5 + 1),
                audioUrl: nil
            )
        }
        
        let jsonData = try JSONEncoder().encode(testWords)
        try await dataManager.importVocabulary(from: jsonData)
        
        // 验证导入
        let stats = dataManager.getVocabularyStats()
        XCTAssertEqual(stats.total, 30)
        XCTAssertEqual(stats.new, 30)
        
        // 2. 创建学习会话
        let session = await studyManager.createStudySession()
        XCTAssertNotNil(session)
        
        // 3. 模拟学习过程
        var studySession = session!
        var reviewedCount = 0
        
        while !studySession.isComplete {
            guard let word = studySession.currentWord else { break }
            
            // 模拟评分
            let quality = ReviewQuality(rawValue: Int16.random(in: 3...5))!
            studyManager.submitReview(
                word: word,
                quality: quality,
                timeSpent: Double.random(in: 1.0...5.0)
            )
            
            reviewedCount += 1
            studySession.completeCurrentWord()
        }
        
        // 4. 验证学习结果
        let updatedStats = dataManager.getVocabularyStats()
        XCTAssertEqual(updatedStats.learning + updatedStats.mastered, reviewedCount)
        XCTAssertEqual(studyManager.todayStats.totalCompleted, reviewedCount)
        
        // 5. 验证复习记录
        let records = dataManager.fetchStudyRecords()
        XCTAssertEqual(records.count, reviewedCount)
    }
    
    func testStudySessionWithMixedRatings() async throws {
        // 导入测试数据
        await createTestWords(count: 10)
        
        let words = dataManager.fetchNewWords(limit: 10)
        
        // 混合评分
        for (index, word) in words.enumerated() {
            let quality: ReviewQuality
            switch index % 6 {
            case 0: quality = .blackOut
            case 1: quality = .incorrect
            case 2: quality = .difficult
            case 3: quality = .hesitation
            case 4: quality = .good
            default: quality = .perfect
            }
            
            studyManager.submitReview(word: word, quality: quality)
        }
        
        // 验证不同评分的结果
        let records = dataManager.fetchStudyRecords()
        
        let correctRecords = records.filter { $0.result == "correct" }
        let incorrectRecords = records.filter { $0.result == "incorrect" }
        
        // 3分及以上为正确
        XCTAssertEqual(correctRecords.count, 4) // hesitation, good, perfect x 2
        XCTAssertEqual(incorrectRecords.count, 6) // blackOut, incorrect, difficult x 2
    }
    
    func testDailyProgressAccumulation() async throws {
        // 导入数据
        await createTestWords(count: 50)
        
        // 分批次学习
        var totalReviewed = 0
        
        for batch in 0..<3 {
            let session = await studyManager.createStudySession()
            XCTAssertNotNil(session)
            
            var studySession = session!
            var batchCount = 0
            
            // 每批学10个或直到完成
            while !studySession.isComplete && batchCount < 10 {
                guard let word = studySession.currentWord else { break }
                studyManager.submitReview(word: word, quality: .good)
                batchCount += 1
                totalReviewed += 1
                studySession.nextWord()
            }
            
            print("批次 \(batch + 1): 学习了 \(batchCount) 个单词")
        }
        
        // 验证累计进度
        XCTAssertEqual(studyManager.todayStats.totalCompleted, totalReviewed)
    }
    
    // MARK: - 磨耳朵播放测试
    
    func testAudioReviewFlow() async throws {
        // 创建有学习记录的单词
        await createTestWords(count: 20, withReviewHistory: true)
        
        // 启动音频复习会话
        let session = await studyManager.startAudioReviewSession()
        XCTAssertNotNil(session)
        
        // 设置播放列表
        let reviewWords = session!.reviewWords
        audioManager.setPlaylist(words: reviewWords, mode: .spaced)
        
        // 验证播放队列
        XCTAssertEqual(audioManager.queue.count, reviewWords.count)
        XCTAssertEqual(audioManager.playbackMode, .spaced)
        
        // 模拟播放流程
        var playedCount = 0
        let maxPlays = min(5, reviewWords.count)
        
        while playedCount < maxPlays {
            audioManager.nextTrack()
            playedCount += 1
        }
        
        // 验证播放统计
        let playedItems = audioManager.queue.filter { $0.playCount > 0 }
        XCTAssertGreaterThanOrEqual(playedItems.count, 1)
    }
    
    func testAudioPlaybackModes() async throws {
        await createTestWords(count: 15)
        let words = dataManager.fetchNewWords(limit: 15)
        
        // 测试顺序播放
        audioManager.setPlaylist(words: words, mode: .sequential)
        XCTAssertEqual(audioManager.playbackMode, .sequential)
        
        // 测试随机播放
        audioManager.setPlaybackMode(.random)
        XCTAssertEqual(audioManager.playbackMode, .random)
        
        // 测试间隔重复
        audioManager.setPlaybackMode(.spaced)
        XCTAssertEqual(audioManager.playbackMode, .spaced)
    }
    
    func testBackgroundAudioPlayback() async throws {
        await createTestWords(count: 10)
        let words = dataManager.fetchNewWords(limit: 10)
        
        audioManager.setPlaylist(words: words, mode: .sequential)
        
        // 验证可以正常设置播放列表，后台播放由系统管理
        XCTAssertEqual(audioManager.queue.count, 10)
        XCTAssertNotNil(audioManager.currentItem)
    }
    
    // MARK: - 数据同步测试
    
    func testCloudKitSyncSetup() {
        // 验证 CloudKit 容器配置
        let container = dataManager.persistentContainer
        XCTAssertNotNil(container)
        
        // 验证 CloudKit 选项已设置
        let description = container.persistentStoreDescriptions.first
        XCTAssertNotNil(description?.cloudKitContainerOptions)
    }
    
    func testDataPersistenceAcrossSessions() async throws {
        // 导入数据
        await createTestWords(count: 10)
        let words = dataManager.fetchNewWords(limit: 5)
        
        // 学习一些单词
        for word in words {
            studyManager.submitReview(word: word, quality: .good)
        }
        
        // 验证数据已保存
        let records = dataManager.fetchStudyRecords()
        XCTAssertEqual(records.count, 5)
        
        // 模拟应用重启后的状态
        let newDataManager = DataManager.shared
        let newRecords = newDataManager.fetchStudyRecords()
        XCTAssertEqual(newRecords.count, 5)
    }
    
    // MARK: - 离线模式测试
    
    func testOfflineModeWordStudy() async throws {
        // 导入数据（假设离线前已完成）
        await createTestWords(count: 20)
        
        // 验证可以在离线模式下获取单词
        let newWords = dataManager.fetchNewWords(limit: 10)
        XCTAssertEqual(newWords.count, 10)
        
        // 验证可以在离线模式下学习
        for word in newWords.prefix(5) {
            studyManager.submitReview(word: word, quality: .good)
        }
        
        let stats = dataManager.getVocabularyStats()
        XCTAssertEqual(stats.learning, 5)
    }
    
    func testOfflineModeAudioPlayback() async throws {
        await createTestWords(count: 10)
        let words = dataManager.fetchNewWords(limit: 10)
        
        // 设置播放列表（使用本地音频）
        audioManager.setPlaylist(words: words)
        
        // 验证播放队列可用
        XCTAssertFalse(audioManager.queue.isEmpty)
    }
    
    func testOfflineStudyProgressTracking() async throws {
        await createTestWords(count: 15)
        
        // 学习单词
        let words = dataManager.fetchNewWords(limit: 10)
        for word in words {
            studyManager.submitReview(word: word, quality: .perfect)
        }
        
        // 验证统计正确
        let todayStats = studyManager.todayStats
        XCTAssertEqual(todayStats.newWordsCompleted, 10)
        XCTAssertEqual(todayStats.accuracy, 5.0) // 全部是 perfect = 5分
        
        // 验证热力图
        let heatmap = studyManager.getStudyHeatmap(days: 1)
        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(heatmap[today], 10)
    }
    
    // MARK: - 边界情况测试
    
    func testEmptyVocabularyStudy() async {
        // 不导入任何数据
        let session = await studyManager.createStudySession()
        XCTAssertNil(session)
    }
    
    func testAllWordsMastered() async throws {
        // 创建已掌握的单词
        await createTestWords(count: 10, status: "mastered")
        
        // 尝试获取新词
        let newWords = dataManager.fetchNewWords(limit: 20)
        XCTAssertEqual(newWords.count, 0)
        
        // 获取复习词
        let reviewWords = dataManager.fetchDueWords(limit: 20)
        // 已掌握的单词应该有未来的复习日期
        XCTAssertEqual(reviewWords.count, 0)
    }
    
    func testRapidReviewSubmission() async throws {
        await createTestWords(count: 5)
        let words = dataManager.fetchNewWords(limit: 5)
        
        // 快速提交评分
        for word in words {
            studyManager.submitReview(word: word, quality: .good, timeSpent: 0.1)
        }
        
        // 验证所有记录都已保存
        let records = dataManager.fetchStudyRecords()
        XCTAssertEqual(records.count, 5)
    }
    
    // MARK: - 辅助方法
    
    private func createTestWords(
        count: Int,
        withReviewHistory: Bool = false,
        status: String = "new"
    ) async {
        let context = dataManager.newBackgroundContext()
        
        await context.perform {
            for i in 0..<count {
                let entity = WordEntity(context: context)
                entity.id = Int32(i + 1)
                entity.word = "integration\(i + 1)"
                entity.meaning = "集成测试\(i + 1)"
                entity.phonetic = "/ɪntɪˈɡreɪʃn/"
                entity.pos = "n."
                entity.chapter = "集成测试"
                entity.chapterKey = "01_integration"
                entity.difficulty = Int16(i % 5 + 1)
                entity.status = status
                
                if withReviewHistory {
                    entity.reviewCount = Int16.random(in: 1...10)
                    entity.nextReviewDate = Date()
                    entity.lastReviewDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
                } else {
                    entity.reviewCount = 0
                }
                
                entity.easeFactor = 2.5
                entity.interval = withReviewHistory ? Int32.random(in: 1...30) : 0
                entity.correctCount = 0
                entity.incorrectCount = 0
                entity.streak = 0
                entity.createdAt = Date()
                entity.updatedAt = Date()
            }
            
            try? context.save()
        }
    }
}
