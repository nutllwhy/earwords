//
//  WordListTests.swift
//  EarWordsTests
//
//  词库浏览功能测试
//

import XCTest
import CoreData
@testable import EarWords

class WordListTests: XCTestCase {
    
    var dataManager: DataManager!
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        dataManager = DataManager.shared
        context = dataManager.context
        
        // 清理测试数据
        clearTestData()
    }
    
    override func tearDown() {
        clearTestData()
        super.tearDown()
    }
    
    // MARK: - 测试数据准备
    
    func clearTestData() {
        let wordRequest = WordEntity.fetchRequest()
        let words = try? context.fetch(wordRequest)
        words?.forEach { context.delete($0) }
        
        let logRequest = ReviewLogEntity.fetchRequest()
        let logs = try? context.fetch(logRequest)
        logs?.forEach { context.delete($0) }
        
        dataManager.save()
    }
    
    func createTestWord(
        id: Int32,
        word: String,
        meaning: String = "",
        status: String = "new",
        chapterKey: String = "01_test"
    ) -> WordEntity {
        let entity = WordEntity(context: context)
        entity.id = id
        entity.word = word
        entity.meaning = meaning.isEmpty ? "测试释义 \(word)" : meaning
        entity.phonetic = "/test/"
        entity.pos = "n."
        entity.chapter = "测试章节"
        entity.chapterKey = chapterKey
        entity.status = status
        entity.easeFactor = 2.5
        entity.interval = 0
        entity.createdAt = Date()
        entity.updatedAt = Date()
        return entity
    }
    
    // MARK: - 章节列表测试
    
    func testFetchAllChapters() {
        // 创建不同章节的单词
        createTestWord(id: 1, word: "apple", chapterKey: "01_nature")
        createTestWord(id: 2, word: "banana", chapterKey: "01_nature")
        createTestWord(id: 3, word: "car", chapterKey: "02_technology")
        createTestWord(id: 4, word: "dog", chapterKey: "02_technology")
        createTestWord(id: 5, word: "elephant", chapterKey: "03_animals")
        
        dataManager.save()
        
        let chapters = dataManager.fetchAllChapters()
        
        XCTAssertEqual(chapters.count, 3, "应该有3个章节")
        XCTAssertTrue(chapters.contains { $0.key == "01_nature" && $0.wordCount == 2 })
        XCTAssertTrue(chapters.contains { $0.key == "02_technology" && $0.wordCount == 2 })
        XCTAssertTrue(chapters.contains { $0.key == "03_animals" && $0.wordCount == 1 })
    }
    
    func testFetchWordsByChapter() {
        // 创建测试数据
        createTestWord(id: 1, word: "apple", status: "new", chapterKey: "01_test")
        createTestWord(id: 2, word: "banana", status: "learning", chapterKey: "01_test")
        createTestWord(id: 3, word: "car", status: "mastered", chapterKey: "01_test")
        createTestWord(id: 4, word: "dog", status: "new", chapterKey: "02_test")
        
        dataManager.save()
        
        let words = dataManager.fetchWordsByChapter(chapterKey: "01_test")
        
        XCTAssertEqual(words.count, 3, "第一章节应该有3个单词")
        XCTAssertTrue(words.contains { $0.word == "apple" && $0.status == "new" })
        XCTAssertTrue(words.contains { $0.word == "banana" && $0.status == "learning" })
        XCTAssertTrue(words.contains { $0.word == "car" && $0.status == "mastered" })
    }
    
    // MARK: - 单词搜索测试
    
    func testSearchWordsByEnglish() {
        createTestWord(id: 1, word: "apple", meaning: "苹果")
        createTestWord(id: 2, word: "application", meaning: "应用")
        createTestWord(id: 3, word: "banana", meaning: "香蕉")
        createTestWord(id: 4, word: "apricot", meaning: "杏子")
        
        dataManager.save()
        
        let results = dataManager.searchWords(query: "app")
        
        XCTAssertEqual(results.count, 3, "搜索 'app' 应该找到3个单词")
        XCTAssertTrue(results.contains { $0.word == "apple" })
        XCTAssertTrue(results.contains { $0.word == "application" })
        XCTAssertTrue(results.contains { $0.word == "apricot" })
    }
    
    func testSearchWordsByChinese() {
        createTestWord(id: 1, word: "apple", meaning: "苹果;苹果树")
        createTestWord(id: 2, word: "pineapple", meaning: "菠萝")
        createTestWord(id: 3, word: "banana", meaning: "香蕉")
        
        dataManager.save()
        
        let results = dataManager.searchWords(query: "果")
        
        XCTAssertEqual(results.count, 3, "搜索 '果' 应该找到3个单词")
        XCTAssertTrue(results.contains { $0.word == "apple" })
        XCTAssertTrue(results.contains { $0.word == "pineapple" })
        XCTAssertTrue(results.contains { $0.word == "banana" })
    }
    
    func testSearchWordsWithStatus() {
        createTestWord(id: 1, word: "apple", status: "new")
        createTestWord(id: 2, word: "banana", status: "learning")
        createTestWord(id: 3, word: "cherry", status: "mastered")
        createTestWord(id: 4, word: "date", status: "new")
        
        dataManager.save()
        
        let newResults = dataManager.searchWords(query: "a", status: "new")
        XCTAssertEqual(newResults.count, 2, "搜索新单词应该有2个结果")
        XCTAssertTrue(newResults.allSatisfy { $0.status == "new" })
    }
    
    func testSearchWordsEmptyQuery() {
        createTestWord(id: 1, word: "apple")
        createTestWord(id: 2, word: "banana")
        
        dataManager.save()
        
        let results = dataManager.searchWords(query: "")
        
        // 空搜索应该返回空结果或限制的结果
        XCTAssertLessThanOrEqual(results.count, 20, "空搜索应该限制返回数量")
    }
    
    func testSearchWordsCaseInsensitive() {
        createTestWord(id: 1, word: "Apple")
        createTestWord(id: 2, word: "APPLE")
        createTestWord(id: 3, word: "apple")
        
        dataManager.save()
        
        let results = dataManager.searchWords(query: "apple")
        
        XCTAssertEqual(results.count, 3, "大小写不敏感搜索应该找到3个结果")
    }
    
    // MARK: - 状态筛选测试
    
    func testFetchWordsByStatus() {
        // 创建不同状态的单词
        for i in 0..<5 {
            createTestWord(id: Int32(i), word: "new\(i)", status: "new")
        }
        
        for i in 5..<10 {
            createTestWord(id: Int32(i), word: "learning\(i)", status: "learning")
        }
        
        for i in 10..<15 {
            createTestWord(id: Int32(i), word: "mastered\(i)", status: "mastered")
        }
        
        dataManager.save()
        
        let newWords = dataManager.fetchWordsByStatus(status: "new", limit: 100)
        let learningWords = dataManager.fetchWordsByStatus(status: "learning", limit: 100)
        let masteredWords = dataManager.fetchWordsByStatus(status: "mastered", limit: 100)
        
        XCTAssertEqual(newWords.count, 5, "应该有5个新单词")
        XCTAssertEqual(learningWords.count, 5, "应该有5个学习中单词")
        XCTAssertEqual(masteredWords.count, 5, "应该有5个已掌握单词")
        
        XCTAssertTrue(newWords.allSatisfy { $0.status == "new" })
        XCTAssertTrue(learningWords.allSatisfy { $0.status == "learning" })
        XCTAssertTrue(masteredWords.allSatisfy { $0.status == "mastered" })
    }
    
    func testFetchWordsInChapterWithStatus() {
        // 第一章节
        createTestWord(id: 1, word: "apple", status: "new", chapterKey: "01_test")
        createTestWord(id: 2, word: "banana", status: "learning", chapterKey: "01_test")
        createTestWord(id: 3, word: "cherry", status: "mastered", chapterKey: "01_test")
        
        // 第二章节
        createTestWord(id: 4, word: "dog", status: "new", chapterKey: "02_test")
        
        dataManager.save()
        
        let chapter1New = dataManager.fetchWordsInChapter(chapterKey: "01_test", status: "new")
        let chapter1Learning = dataManager.fetchWordsInChapter(chapterKey: "01_test", status: "learning")
        let chapter1Mastered = dataManager.fetchWordsInChapter(chapterKey: "01_test", status: "mastered")
        
        XCTAssertEqual(chapter1New.count, 1, "第一章节应该有1个新单词")
        XCTAssertEqual(chapter1Learning.count, 1, "第一章节应该有1个学习中单词")
        XCTAssertEqual(chapter1Mastered.count, 1, "第一章节应该有1个已掌握单词")
    }
    
    // MARK: - 单词详情测试
    
    func testFetchWordById() {
        let word = createTestWord(id: 100, word: "special", meaning: "特殊的")
        dataManager.save()
        
        let fetched = dataManager.fetchWord(byId: 100)
        
        XCTAssertNotNil(fetched, "应该能根据ID找到单词")
        XCTAssertEqual(fetched?.word, "special")
        XCTAssertEqual(fetched?.meaning, "特殊的")
    }
    
    func testFetchWordByIdNotFound() {
        let fetched = dataManager.fetchWord(byId: 99999)
        XCTAssertNil(fetched, "不存在的ID应该返回nil")
    }
    
    // MARK: - 综合功能测试
    
    func testChapterProgressAggregation() {
        // 创建多个章节的单词，模拟真实数据分布
        let chapters = [
            (key: "01_nature", total: 10),
            (key: "02_tech", total: 15),
            (key: "03_social", total: 8)
        ]
        
        var id: Int32 = 1
        for chapter in chapters {
            for i in 0..<chapter.total {
                let status: String
                if i < chapter.total / 3 {
                    status = "mastered"
                } else if i < chapter.total * 2 / 3 {
                    status = "learning"
                } else {
                    status = "new"
                }
                createTestWord(id: id, word: "\(chapter.key)_\(i)", status: status, chapterKey: chapter.key)
                id += 1
            }
        }
        
        dataManager.save()
        
        let progress = dataManager.getChapterProgress()
        
        XCTAssertEqual(progress.count, 3, "应该有3个章节")
        
        for chapterProgress in progress {
            let total = chapterProgress.total
            let expectedMastered = total / 3
            let expectedLearning = total / 3
            let expectedNew = total - expectedMastered - expectedLearning
            
            XCTAssertEqual(chapterProgress.mastered, expectedMastered)
            XCTAssertEqual(chapterProgress.learning, expectedLearning)
            // new = total - mastered - learning
            XCTAssertEqual(total - chapterProgress.mastered - chapterProgress.learning, expectedNew)
        }
    }
    
    func testSearchAndFilterCombination() {
        // 创建测试数据
        createTestWord(id: 1, word: "application", meaning: "应用程序", status: "new")
        createTestWord(id: 2, word: "apply", meaning: "申请", status: "learning")
        createTestWord(id: 3, word: "apple", meaning: "苹果", status: "mastered")
        createTestWord(id: 4, word: "banana", meaning: "香蕉", status: "new")
        
        dataManager.save()
        
        // 搜索 "app" 且状态为 "new"
        let results = dataManager.searchWords(query: "app", status: "new")
        
        XCTAssertEqual(results.count, 1, "应该只有1个结果")
        XCTAssertEqual(results.first?.word, "application")
        XCTAssertEqual(results.first?.status, "new")
    }
}
