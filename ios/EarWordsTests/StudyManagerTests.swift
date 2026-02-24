//
//  StudyManagerTests.swift
//  EarWordsTests
//
//  StudyManager 单元测试
//

import XCTest
@testable import EarWords

final class StudyManagerTests: XCTestCase {
    
    var studyManager: StudyManager!
    var dataManager: DataManager!
    
    override func setUp() {
        super.setUp()
        studyManager = StudyManager.shared
        dataManager = DataManager.shared
        
        // 清理测试数据
        dataManager.deleteAllWords()
    }
    
    override func tearDown() {
        dataManager.deleteAllWords()
        super.tearDown()
    }
    
    // MARK: - 初始化测试
    
    func testDefaultSettings() {
        XCTAssertEqual(studyManager.dailyNewWordsTarget, 20)
        XCTAssertEqual(studyManager.dailyReviewLimit, 50)
        XCTAssertTrue(studyManager.enableNotifications)
    }
    
    func testSettingsPersistence() {
        // 修改设置
        studyManager.dailyNewWordsTarget = 30
        studyManager.dailyReviewLimit = 60
        studyManager.enableNotifications = false
        
        // 创建新的 manager 实例验证持久化
        let newManager = StudyManager()
        XCTAssertEqual(newManager.dailyNewWordsTarget, 30)
        XCTAssertEqual(newManager.dailyReviewLimit, 60)
        XCTAssertFalse(newManager.enableNotifications)
    }
    
    // MARK: - 学习队列测试
    
    func testGenerateTodayStudyQueue() async {
        // 创建测试单词
        await createTestWords(count: 25)
        
        let (newWords, reviewWords) = await studyManager.generateTodayStudyQueue()
        
        // 验证新词数量不超过目标
        XCTAssertLessThanOrEqual(newWords.count, studyManager.dailyNewWordsTarget)
        
        // 验证复习单词数量
        XCTAssertLessThanOrEqual(reviewWords.count, studyManager.dailyReviewLimit)
    }
    
    func testCreateStudySession() async {
        // 创建测试单词
        await createTestWords(count: 30)
        
        let session = await studyManager.createStudySession()
        
        XCTAssertNotNil(session)
        XCTAssertGreaterThan(session!.totalWords, 0)
    }
    
    func testStudySessionProgress() async {
        await createTestWords(count: 10)
        
        let session = await studyManager.createStudySession()
        XCTAssertNotNil(session)
        
        var mutableSession = session!
        
        // 验证初始进度
        XCTAssertEqual(mutableSession.progress, 0)
        XCTAssertFalse(mutableSession.isComplete)
        
        // 完成第一个单词
        mutableSession.nextWord()
        XCTAssertEqual(mutableSession.progress, 1.0 / Double(mutableSession.totalWords))
        
        // 跳过所有单词
        while !mutableSession.isComplete {
            mutableSession.nextWord()
        }
        
        XCTAssertEqual(mutableSession.progress, 1.0)
        XCTAssertTrue(mutableSession.isComplete)
    }
    
    func testStudySessionCurrentWord() async {
        await createTestWords(count: 5)
        
        let session = await studyManager.createStudySession()
        XCTAssertNotNil(session)
        
        var mutableSession = session!
        
        // 验证可以获取当前单词
        let firstWord = mutableSession.currentWord
        XCTAssertNotNil(firstWord)
        
        // 前进到下一个
        mutableSession.nextWord()
        let secondWord = mutableSession.currentWord
        
        // 如果有多于一个单词，应该不同
        if mutableSession.totalWords > 1 {
            XCTAssertNotEqual(firstWord?.id, secondWord?.id)
        }
    }
    
    // MARK: - 评分测试
    
    func testSubmitReview() async {
        await createTestWords(count: 5)
        
        let word = dataManager.fetchNewWords(limit: 1).first!
        let initialReviewCount = word.reviewCount
        
        studyManager.submitReview(
            word: word,
            quality: .good,
            timeSpent: 2.5,
            mode: .normal
        )
        
        // 验证复习计数增加
        XCTAssertEqual(word.reviewCount, initialReviewCount + 1)
        XCTAssertEqual(word.status, "learning")
    }
    
    func testRateWord() async {
        await createTestWords(count: 5)
        
        let word = dataManager.fetchNewWords(limit: 1).first!
        
        studyManager.rateWord(word: word, score: 5, timeSpent: 1.0)
        
        XCTAssertEqual(word.reviewCount, 1)
    }
    
    func testInvalidRate() async {
        await createTestWords(count: 1)
        
        let word = dataManager.fetchNewWords(limit: 1).first!
        let initialCount = word.reviewCount
        
        // 无效评分不应影响
        studyManager.rateWord(word: word, score: 10, timeSpent: 1.0)
        
        XCTAssertEqual(word.reviewCount, initialCount)
    }
    
    // MARK: - 音频复习模式测试
    
    func testStartAudioReviewSession() async {
        // 创建有学习记录的单词
        await createTestWords(count: 10, withReviewHistory: true)
        
        let session = await studyManager.startAudioReviewSession()
        
        XCTAssertNotNil(session)
        XCTAssertGreaterThan(session!.reviewWords.count, 0)
        XCTAssertEqual(session!.newWords.count, 0) // 音频复习模式只有复习词
    }
    
    func testStartQuickReviewSession() async {
        await createTestWords(count: 15, withReviewHistory: true)
        
        let session = await studyManager.startQuickReviewSession(limit: 10)
        
        XCTAssertNotNil(session)
        XCTAssertLessThanOrEqual(session!.reviewWords.count, 10)
    }
    
    // MARK: - 学习热力图测试
    
    func testGetStudyHeatmap() async {
        // 创建单词和复习记录
        await createTestWords(count: 5)
        let words = dataManager.fetchNewWords(limit: 5)
        
        for word in words {
            studyManager.submitReview(word: word, quality: .good)
        }
        
        let heatmap = studyManager.getStudyHeatmap(days: 7)
        
        // 验证返回了7天的数据
        XCTAssertEqual(heatmap.count, 7)
        
        // 今天应该有记录
        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertGreaterThanOrEqual(heatmap[today] ?? 0, 5)
    }
    
    // MARK: - 未来复习预测测试
    
    func testPredictUpcomingReviews() async {
        await createTestWords(count: 10)
        let words = dataManager.fetchNewWords(limit: 10)
        
        // 为所有单词创建复习记录，设置不同的下次复习日期
        for (index, word) in words.enumerated() {
            word.status = "learning"
            word.nextReviewDate = Calendar.current.date(byAdding: .day, value: index % 7, to: Date())
        }
        
        dataManager.save()
        
        let predictions = studyManager.predictUpcomingReviews(for: 7)
        
        // 验证返回了7天的预测
        XCTAssertEqual(predictions.count, 7)
    }
    
    // MARK: - 今日统计测试
    
    func testTodayStats() async {
        await createTestWords(count: 10)
        
        let initialStats = studyManager.todayStats
        XCTAssertEqual(initialStats.newWordsTarget, studyManager.dailyNewWordsTarget)
        
        // 学习一些单词
        let words = dataManager.fetchNewWords(limit: 5)
        for word in words {
            studyManager.submitReview(word: word, quality: .good)
        }
        
        // 统计应该更新
        XCTAssertEqual(studyManager.todayStats.newWordsCompleted, 5)
    }
    
    // MARK: - 辅助方法
    
    private func createTestWords(count: Int, withReviewHistory: Bool = false) async {
        let context = dataManager.newBackgroundContext()
        
        await context.perform {
            for i in 0..<count {
                let entity = WordEntity(context: context)
                entity.id = Int32(i + 1)
                entity.word = "test\(i)"
                entity.meaning = "测试\(i)"
                entity.phonetic = "/test/"
                entity.pos = "n."
                entity.chapter = "测试章节"
                entity.chapterKey = "01_test"
                entity.difficulty = Int16(i % 5 + 1)
                
                if withReviewHistory {
                    entity.status = "learning"
                    entity.reviewCount = Int16.random(in: 1...5)
                    entity.nextReviewDate = Date()
                } else {
                    entity.status = "new"
                    entity.reviewCount = 0
                }
                
                entity.easeFactor = 2.5
                entity.interval = 0
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

// MARK: - StudySession 测试

final class StudySessionTests: XCTestCase {
    
    func testStudySessionProperties() {
        // 创建测试数据
        let mockNewWords: [WordEntity] = []
        let mockReviewWords: [WordEntity] = []
        
        let session = StudySession(
            date: Date(),
            newWords: mockNewWords,
            reviewWords: mockReviewWords
        )
        
        XCTAssertEqual(session.totalWords, 0)
        XCTAssertTrue(session.isComplete)
        XCTAssertNil(session.currentWord)
    }
    
    func testStudySessionCompletionRate() {
        let session = StudySession(
            date: Date(),
            newWords: [],
            reviewWords: [],
            currentIndex: 0,
            completedWords: [],
            skippedWords: []
        )
        
        var mutableSession = session
        mutableSession.completeCurrentWord()
        
        // 空会话完成率仍为0
        XCTAssertEqual(mutableSession.progress, 0)
    }
}

// MARK: - DailyStudyStats 测试

final class DailyStudyStatsTests: XCTestCase {
    
    func testCompletionRate() {
        let stats = DailyStudyStats(
            date: Date(),
            newWordsTarget: 20,
            newWordsCompleted: 10,
            reviewWordsTarget: 50,
            reviewWordsCompleted: 25
        )
        
        XCTAssertEqual(stats.totalTarget, 70)
        XCTAssertEqual(stats.totalCompleted, 35)
        XCTAssertEqual(stats.completionRate, 0.5)
    }
    
    func testIsComplete() {
        let incompleteStats = DailyStudyStats(
            date: Date(),
            newWordsTarget: 20,
            newWordsCompleted: 10,
            reviewWordsTarget: 50,
            reviewWordsCompleted: 40
        )
        XCTAssertFalse(incompleteStats.isComplete)
        
        let completeStats = DailyStudyStats(
            date: Date(),
            newWordsTarget: 20,
            newWordsCompleted: 20,
            reviewWordsTarget: 50,
            reviewWordsCompleted: 50
        )
        XCTAssertTrue(completeStats.isComplete)
    }
}
