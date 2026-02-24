//
//  DataManagerTests.swift
//  EarWordsTests
//
//  DataManager 单元测试
//

import XCTest
import CoreData
@testable import EarWords

final class DataManagerTests: XCTestCase {
    
    var dataManager: DataManager!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        // 使用内存存储进行测试
        dataManager = DataManager.shared
        context = dataManager.newBackgroundContext()
    }
    
    override func tearDown() {
        // 清理测试数据
        dataManager.deleteAllWords()
        super.tearDown()
    }
    
    // MARK: - 词库导入测试
    
    func testImportVocabulary() async throws {
        // 准备测试数据
        let testWords = [
            WordJSON(
                id: 1,
                word: "test",
                phonetic: "/test/",
                pos: "n.",
                meaning: "测试",
                example: "This is a test.",
                extra: nil,
                chapter: "01_测试章节",
                chapterKey: "01_test",
                difficulty: 1,
                audioUrl: nil
            ),
            WordJSON(
                id: 2,
                word: "example",
                phonetic: "/ɪɡˈzæmpl/",
                pos: "n.",
                meaning: "例子",
                example: "For example...",
                extra: nil,
                chapter: "01_测试章节",
                chapterKey: "01_test",
                difficulty: 2,
                audioUrl: nil
            )
        ]
        
        let jsonData = try JSONEncoder().encode(testWords)
        
        // 执行导入
        try await dataManager.importVocabulary(from: jsonData)
        
        // 验证结果
        let stats = dataManager.getVocabularyStats()
        XCTAssertEqual(stats.total, 2)
        XCTAssertEqual(stats.new, 2)
    }
    
    func testDuplicateImportPrevention() async throws {
        // 先导入一次
        let testWord = WordJSON(
            id: 1,
            word: "unique",
            phonetic: "/juˈniːk/",
            pos: "adj.",
            meaning: "独特的",
            example: "Each item is unique.",
            extra: nil,
            chapter: "01_测试",
            chapterKey: "01_test",
            difficulty: 3,
            audioUrl: nil
        )
        
        let jsonData = try JSONEncoder().encode([testWord])
        try await dataManager.importVocabulary(from: jsonData)
        
        // 再次导入相同数据
        try await dataManager.importVocabulary(from: jsonData)
        
        // 验证没有重复
        let stats = dataManager.getVocabularyStats()
        XCTAssertEqual(stats.total, 1)
    }
    
    // MARK: - 查询测试
    
    func testFetchWordsByChapter() {
        // 创建测试单词
        let word1 = createTestWord(id: 1, word: "apple", chapterKey: "01_fruits")
        let word2 = createTestWord(id: 2, word: "banana", chapterKey: "01_fruits")
        let word3 = createTestWord(id: 3, word: "car", chapterKey: "02_vehicles")
        
        dataManager.save()
        
        // 测试按章节查询
        let fruits = dataManager.fetchWordsByChapter(chapterKey: "01_fruits")
        XCTAssertEqual(fruits.count, 2)
        
        let vehicles = dataManager.fetchWordsByChapter(chapterKey: "02_vehicles")
        XCTAssertEqual(vehicles.count, 1)
    }
    
    func testFetchNewWords() {
        // 创建新单词和已学习单词
        let newWord = createTestWord(id: 1, word: "new", status: "new")
        let learningWord = createTestWord(id: 2, word: "learning", status: "learning")
        
        dataManager.save()
        
        // 测试获取新单词
        let newWords = dataManager.fetchNewWords(limit: 10)
        XCTAssertEqual(newWords.count, 1)
        XCTAssertEqual(newWords.first?.word, "new")
    }
    
    func testFetchDueWords() {
        // 创建需要复习的单词
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        
        let dueWord = createTestWord(id: 1, word: "due")
        dueWord.status = "learning"
        dueWord.nextReviewDate = yesterday
        
        let notDueWord = createTestWord(id: 2, word: "notdue")
        notDueWord.status = "learning"
        notDueWord.nextReviewDate = tomorrow
        
        dataManager.save()
        
        // 测试获取待复习单词
        let dueWords = dataManager.fetchDueWords(limit: 10)
        XCTAssertEqual(dueWords.count, 1)
        XCTAssertEqual(dueWords.first?.word, "due")
    }
    
    func testSearchWords() {
        // 创建测试单词
        let word1 = createTestWord(id: 1, word: "abandon", meaning: "放弃")
        let word2 = createTestWord(id: 2, word: "ability", meaning: "能力")
        let word3 = createTestWord(id: 3, word: "test", meaning: "测试")
        
        dataManager.save()
        
        // 测试搜索
        let results1 = dataManager.searchWords(query: "aba")
        XCTAssertEqual(results1.count, 2)
        
        let results2 = dataManager.searchWords(query: "能力")
        XCTAssertEqual(results2.count, 1)
        XCTAssertEqual(results2.first?.word, "ability")
    }
    
    // MARK: - 复习记录测试
    
    func testLogReview() {
        let word = createTestWord(id: 1, word: "review")
        dataManager.save()
        
        // 记录复习
        let log = dataManager.logReview(
            word: word,
            quality: .good,
            timeSpent: 3.5,
            mode: "normal"
        )
        
        // 验证
        XCTAssertEqual(log.quality, 4)
        XCTAssertEqual(log.word, "review")
        XCTAssertEqual(log.timeSpent, 3.5)
        XCTAssertEqual(word.reviewCount, 1)
        XCTAssertEqual(word.status, "learning")
    }
    
    func testLogReview_PerfectScore() {
        let word = createTestWord(id: 1, word: "master")
        word.reviewCount = 5
        word.correctCount = 5
        dataManager.save()
        
        // 记录完美评分
        _ = dataManager.logReview(word: word, quality: .perfect)
        
        // 验证状态变为已掌握
        XCTAssertEqual(word.status, "mastered")
    }
    
    // MARK: - 统计测试
    
    func testGetVocabularyStats() {
        // 创建不同状态的单词
        _ = createTestWord(id: 1, word: "new1", status: "new")
        _ = createTestWord(id: 2, word: "new2", status: "new")
        _ = createTestWord(id: 3, word: "learning1", status: "learning")
        _ = createTestWord(id: 4, word: "mastered1", status: "mastered")
        
        dataManager.save()
        
        let stats = dataManager.getVocabularyStats()
        XCTAssertEqual(stats.total, 4)
        XCTAssertEqual(stats.new, 2)
        XCTAssertEqual(stats.learning, 1)
        XCTAssertEqual(stats.mastered, 1)
    }
    
    func testGetStudyStatistics() {
        // 创建复习记录
        let word = createTestWord(id: 1, word: "stats")
        
        // 创建几条复习记录
        for i in 0..<5 {
            let log = ReviewLogEntity(context: dataManager.context)
            log.id = UUID()
            log.wordId = 1
            log.word = "stats"
            log.reviewDate = Calendar.current.date(byAdding: .day, value: -i, to: Date())
            log.quality = 4
            log.result = "correct"
        }
        
        dataManager.save()
        
        let stats = dataManager.getStudyStatistics(days: 7)
        XCTAssertEqual(stats.count, 7)
        XCTAssertTrue(stats[6].reviews >= 1) // 今天
    }
    
    // MARK: - 重置测试
    
    func testResetAllProgress() {
        // 创建有学习进度的单词
        let word = createTestWord(id: 1, word: "reset")
        word.status = "mastered"
        word.reviewCount = 10
        word.interval = 30
        
        // 创建复习记录
        let log = ReviewLogEntity(context: dataManager.context)
        log.id = UUID()
        log.wordId = 1
        log.word = "reset"
        
        dataManager.save()
        
        // 重置进度
        dataManager.resetAllProgress()
        
        // 验证
        XCTAssertEqual(word.status, "new")
        XCTAssertEqual(word.reviewCount, 0)
        XCTAssertEqual(word.interval, 0)
        
        let logs = dataManager.fetchStudyRecords()
        XCTAssertEqual(logs.count, 0)
    }
    
    // MARK: - 辅助方法
    
    private func createTestWord(
        id: Int32,
        word: String,
        chapterKey: String = "01_test",
        status: String = "new",
        meaning: String = "测试"
    ) -> WordEntity {
        let entity = WordEntity(context: dataManager.context)
        entity.id = id
        entity.word = word
        entity.meaning = meaning
        entity.phonetic = "/test/"
        entity.pos = "n."
        entity.chapter = "测试章节"
        entity.chapterKey = chapterKey
        entity.difficulty = 1
        entity.status = status
        entity.easeFactor = 2.5
        entity.interval = 0
        entity.reviewCount = 0
        entity.correctCount = 0
        entity.incorrectCount = 0
        entity.streak = 0
        entity.createdAt = Date()
        entity.updatedAt = Date()
        return entity
    }
}
