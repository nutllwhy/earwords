//
//  StudyFlowTests.swift
//  EarWordsTests
//
//  学习流程测试 - 验证学习功能完整集成
//

import XCTest
import CoreData
@testable import EarWords

@MainActor
final class StudyFlowTests: XCTestCase {
    
    var dataManager: DataManager!
    var studyManager: StudyManager!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        dataManager = DataManager.shared
        studyManager = StudyManager.shared
        context = dataManager.context
        
        // 清理测试数据
        cleanTestData()
    }
    
    override func tearDown() {
        cleanTestData()
        super.tearDown()
    }
    
    // MARK: - 测试数据准备
    
    private func cleanTestData() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = WordEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try? context.execute(deleteRequest)
        
        let logFetch: NSFetchRequest<NSFetchRequestResult> = ReviewLogEntity.fetchRequest()
        let logDelete = NSBatchDeleteRequest(fetchRequest: logFetch)
        try? context.execute(logDelete)
        
        try? context.save()
    }
    
    private func createTestWord(id: Int32, word: String, status: String = "new") -> WordEntity {
        let entity = WordEntity(context: context)
        entity.id = id
        entity.word = word
        entity.phonetic = "/test/"
        entity.pos = "n."
        entity.meaning = "测试释义 \(word)"
        entity.example = "This is a test example for \(word)."
        entity.chapter = "TestChapter"
        entity.chapterKey = "test_chapter"
        entity.difficulty = 1
        entity.status = status
        entity.reviewCount = 0
        entity.easeFactor = 2.5
        entity.interval = 0
        entity.createdAt = Date()
        entity.updatedAt = Date()
        return entity
    }
    
    // MARK: - 1. 数据层连接测试
    
    func testFetchTodayStudyQueue() async {
        // 准备：创建测试单词
        let newWord1 = createTestWord(id: 1, word: "test1")
        let newWord2 = createTestWord(id: 2, word: "test2")
        
        let reviewWord = createTestWord(id: 3, word: "test3", status: "learning")
        reviewWord.nextReviewDate = Date() // 今天到期
        reviewWord.interval = 1
        
        try? context.save()
        
        // 执行：获取学习队列
        let queue = await studyManager.fetchStudyQueue(newWordCount: 2, reviewLimit: 10)
        
        // 验证
        XCTAssertEqual(queue.newWords.count, 2, "应该有2个新词")
        XCTAssertEqual(queue.reviewWords.count, 1, "应该有1个复习词")
        XCTAssertEqual(queue.totalCount, 3, "总共应该有3个单词")
    }
    
    func testStudyQueuePrioritization() async {
        // 准备：创建多个单词
        let newWord = createTestWord(id: 1, word: "new")
        
        let reviewWord1 = createTestWord(id: 2, word: "review1", status: "learning")
        reviewWord1.nextReviewDate = Date().addingTimeInterval(-3600) // 1小时前到期
        
        let reviewWord2 = createTestWord(id: 3, word: "review2", status: "learning")
        reviewWord2.nextReviewDate = Date().addingTimeInterval(3600) // 1小时后到期
        
        try? context.save()
        
        // 执行
        let queue = await studyManager.fetchStudyQueue()
        let prioritized = queue.prioritized
        
        // 验证：复习词应该优先
        XCTAssertEqual(prioritized.first?.word, "review1", "先到期的复习词应该排在前面")
    }
    
    // MARK: - 2. SM-2 算法测试
    
    func testSM2AlgorithmPerfectScore() {
        // 准备：新单词
        let word = createTestWord(id: 1, word: "algorithm_test")
        
        // 执行：完美评分（5分）
        let result = word.applyReview(quality: .perfect, timeSpent: 2.0)
        
        // 验证
        XCTAssertEqual(result.quality, .perfect)
        XCTAssertEqual(result.newInterval, 14, "完美评分应该设置14天间隔")
        XCTAssertTrue(result.newEaseFactor >= 2.5, "简易度应该保持或提高")
        XCTAssertEqual(word.status, "learning", "第一次复习后状态为学习中")
        XCTAssertEqual(word.reviewCount, 1, "复习计数应该为1")
        
        // 验证下次复习日期
        let daysUntilReview = Calendar.current.dateComponents(
            [.day],
            from: Date(),
            to: word.nextReviewDate!
        ).day
        XCTAssertEqual(daysUntilReview, 14, "下次复习应该是14天后")
    }
    
    func testSM2AlgorithmBlackOut() {
        // 准备
        let word = createTestWord(id: 2, word: "blackout_test")
        word.reviewCount = 5
        word.interval = 30
        word.easeFactor = 2.5
        
        // 执行：完全忘记（0分）
        let result = word.applyReview(quality: .blackOut, timeSpent: 1.0)
        
        // 验证
        XCTAssertEqual(result.quality, .blackOut)
        XCTAssertEqual(result.newInterval, 0, "忘记应该设置0天间隔（当天重复）")
        XCTAssertTrue(result.newEaseFactor < 2.5, "简易度应该降低")
        XCTAssertEqual(word.streak, 0, "连续正确次数应该重置")
    }
    
    func testSM2AlgorithmProgressiveLearning() {
        // 准备
        let word = createTestWord(id: 3, word: "progressive_test")
        
        // 第一次复习：3分
        var result = word.applyReview(quality: .hesitation, timeSpent: 2.0)
        XCTAssertEqual(result.newInterval, 3, "3分应该设置3天间隔")
        
        // 模拟时间过去，第二次复习：4分
        word.nextReviewDate = Date() // 今天到期
        result = word.applyReview(quality: .good, timeSpent: 1.5)
        XCTAssertTrue(result.newInterval > 3, "4分应该增加间隔")
        
        // 第三次复习：5分
        word.nextReviewDate = Date()
        result = word.applyReview(quality: .perfect, timeSpent: 1.0)
        XCTAssertTrue(result.newInterval > result.previousInterval, "5分应该继续增加间隔")
        
        // 验证状态变为已掌握
        if word.reviewCount >= 3 && word.streak >= 2 {
            XCTAssertEqual(word.status, "mastered")
        }
    }
    
    func testSM2AlgorithmEaseFactorAdjustment() {
        // 准备
        let word = createTestWord(id: 4, word: "ease_test")
        let initialEF = 2.5
        word.easeFactor = initialEF
        
        // 多次完美评分应该增加简易度
        for i in 0..<3 {
            word.nextReviewDate = Date()
            let result = word.applyReview(quality: .perfect, timeSpent: 1.0)
            print("Review \(i+1): EF = \(result.newEaseFactor)")
        }
        
        // 验证简易度增加
        XCTAssertTrue(word.easeFactor > initialEF, "连续正确应该增加简易度")
        
        // 一次错误应该降低简易度
        let efBefore = word.easeFactor
        word.nextReviewDate = Date()
        word.applyReview(quality: .incorrect, timeSpent: 1.0)
        
        XCTAssertTrue(word.easeFactor < efBefore, "错误应该降低简易度")
    }
    
    // MARK: - 3. 学习记录测试
    
    func testReviewLogCreation() {
        // 准备
        let word = createTestWord(id: 5, word: "log_test")
        word.easeFactor = 2.5
        word.interval = 7
        
        // 执行
        let log = dataManager.logReview(
            word: word,
            quality: .good,
            timeSpent: 2.5,
            mode: "normal"
        )
        
        // 验证
        XCTAssertEqual(log.wordId, word.id)
        XCTAssertEqual(log.word, word.word)
        XCTAssertEqual(log.quality, 4)
        XCTAssertEqual(log.result, "correct")
        XCTAssertEqual(log.previousEaseFactor, 2.5)
        XCTAssertEqual(log.previousInterval, 7)
        XCTAssertEqual(log.timeSpent, 2.5)
        XCTAssertEqual(log.studyMode, "normal")
        XCTAssertNotNil(log.reviewDate)
        
        // 验证新值已更新
        XCTAssertNotEqual(log.newEaseFactor, log.previousEaseFactor)
        XCTAssertNotEqual(log.newInterval, log.previousInterval)
    }
    
    func testStudyRecordsPersistence() {
        // 准备
        let word1 = createTestWord(id: 6, word: "record_test1")
        let word2 = createTestWord(id: 7, word: "record_test2")
        
        // 执行多次学习记录
        dataManager.logReview(word: word1, quality: .good, timeSpent: 1.0)
        dataManager.logReview(word: word2, quality: .perfect, timeSpent: 2.0)
        dataManager.logReview(word: word1, quality: .hesitation, timeSpent: 1.5)
        
        // 验证
        let records = dataManager.fetchStudyRecords(limit: 10)
        XCTAssertEqual(records.count, 3, "应该有3条学习记录")
        
        // 验证今日记录
        let todayRecords = dataManager.fetchStudyRecords(for: Date())
        XCTAssertEqual(todayRecords.count, 3, "今日应该有3条记录")
    }
    
    // MARK: - 4. 学习流程集成测试
    
    func testCompleteStudyFlow() async {
        // 准备：创建学习队列
        let word1 = createTestWord(id: 10, word: "flow1")
        let word2 = createTestWord(id: 11, word: "flow2")
        let word3 = createTestWord(id: 12, word: "flow3")
        try? context.save()
        
        // 模拟完整学习流程
        let viewModel = StudyViewModel()
        await MainActor.run {
            viewModel.studyQueue = [word1, word2, word3]
            viewModel.currentIndex = 0
        }
        
        // 学习第一个单词（完美）
        viewModel.rateCurrentWord(quality: .perfect)
        XCTAssertEqual(viewModel.correctCount, 1)
        XCTAssertEqual(viewModel.currentIndex, 1)
        
        // 学习第二个单词（困难）
        viewModel.rateCurrentWord(quality: .difficult)
        XCTAssertEqual(viewModel.correctCount, 1)
        XCTAssertEqual(viewModel.incorrectCount, 1)
        XCTAssertEqual(viewModel.currentIndex, 2)
        
        // 学习第三个单词（忘记）
        viewModel.rateCurrentWord(quality: .blackOut)
        XCTAssertEqual(viewModel.incorrectCount, 2)
        XCTAssertTrue(viewModel.isStudyComplete)
        
        // 验证学习记录
        let records = dataManager.fetchStudyRecords(for: Date())
        XCTAssertEqual(records.count, 3)
    }
    
    func testWordStatusUpdate() {
        // 准备
        let word = createTestWord(id: 20, word: "status_test")
        XCTAssertEqual(word.status, "new")
        
        // 第一次复习
        word.applyReview(quality: .good, timeSpent: 1.0)
        XCTAssertEqual(word.status, "learning")
        
        // 多次正确复习
        for _ in 0..<3 {
            word.nextReviewDate = Date()
            word.applyReview(quality: .perfect, timeSpent: 1.0)
        }
        
        // 验证变为已掌握
        XCTAssertEqual(word.status, "mastered")
    }
    
    // MARK: - 5. 明日预览测试
    
    func testTomorrowPreview() async {
        // 准备：设置明天到期的单词
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let startOfTomorrow = calendar.startOfDay(for: tomorrow)
        
        let word1 = createTestWord(id: 30, word: "tomorrow1", status: "learning")
        word1.nextReviewDate = startOfTomorrow.addingTimeInterval(3600) // 明天早上
        
        let word2 = createTestWord(id: 31, word: "tomorrow2", status: "learning")
        word2.nextReviewDate = startOfTomorrow.addingTimeInterval(7200) // 明天下午
        
        // 创建一个今天到期的单词（不应该出现在明天预览中）
        let word3 = createTestWord(id: 32, word: "today", status: "learning")
        word3.nextReviewDate = Date()
        
        try? context.save()
        
        // 获取所有单词
        let allWords = try? context.fetch(WordEntity.fetchRequest())
        let dueTomorrow = allWords?.filter { word in
            guard let nextReview = word.nextReviewDate else { return false }
            return nextReview >= startOfTomorrow && 
                   nextReview < calendar.date(byAdding: .day, value: 1, to: startOfTomorrow)!
        }
        
        XCTAssertEqual(dueTomorrow?.count, 2, "应该有2个单词明天到期")
    }
    
    // MARK: - 6. 性能测试
    
    func testStudyQueuePerformance() async {
        // 准备：创建大量单词
        for i in 0..<100 {
            let word = createTestWord(id: Int32(100 + i), word: "perf\(i)")
            if i < 50 {
                word.status = "learning"
                word.nextReviewDate = Date()
            }
        }
        try? context.save()
        
        // 测量获取队列性能
        measure {
            let expectation = expectation(description: "Fetch queue")
            Task {
                let queue = await studyManager.fetchStudyQueue(newWordCount: 20, reviewLimit: 50)
                XCTAssertFalse(queue.isEmpty)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testReviewLogPerformance() {
        // 准备
        let word = createTestWord(id: 999, word: "perf_word")
        
        // 测量记录复习性能
        measure {
            for i in 0..<100 {
                word.nextReviewDate = Date()
                dataManager.logReview(
                    word: word,
                    quality: ReviewQuality(rawValue: Int16(i % 6)) ?? .good,
                    timeSpent: Double(i)
                )
            }
        }
    }
}

// MARK: - 辅助断言

extension XCTestCase {
    func XCTAssertDateEqual(_ date1: Date?, _ date2: Date?, accuracy: TimeInterval = 1.0, file: StaticString = #file, line: UInt = #line) {
        guard let d1 = date1, let d2 = date2 else {
            XCTFail("Dates should not be nil", file: file, line: line)
            return
        }
        XCTAssertEqual(d1.timeIntervalSince1970, d2.timeIntervalSince1970, accuracy: accuracy, file: file, line: line)
    }
}
