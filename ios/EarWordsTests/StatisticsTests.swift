//
//  StatisticsTests.swift
//  EarWordsTests
//
//  统计功能测试
//

import XCTest
import CoreData
@testable import EarWords

class StatisticsTests: XCTestCase {
    
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
    
    func createTestWord(id: Int32, word: String, status: String = "new", chapterKey: String = "01_test") -> WordEntity {
        let entity = WordEntity(context: context)
        entity.id = id
        entity.word = word
        entity.meaning = "测试释义 \(word)"
        entity.phonetic = "/test/"
        entity.chapter = "测试章节"
        entity.chapterKey = chapterKey
        entity.status = status
        entity.easeFactor = 2.5
        entity.interval = 0
        entity.createdAt = Date()
        entity.updatedAt = Date()
        return entity
    }
    
    func createTestReviewLog(wordId: Int32, word: String, result: String, date: Date) -> ReviewLogEntity {
        let log = ReviewLogEntity(context: context)
        log.id = UUID()
        log.wordId = wordId
        log.word = word
        log.reviewDate = date
        log.result = result
        log.quality = result == "correct" ? 4 : 1
        return log
    }
    
    // MARK: - 今日统计测试
    
    func testTodayStatistics() {
        let calendar = Calendar.current
        let today = Date()
        
        // 创建今天的学习记录
        let word1 = createTestWord(id: 1, word: "test1", status: "learning")
        word1.createdAt = today
        
        let word2 = createTestWord(id: 2, word: "test2", status: "learning")
        word2.createdAt = today
        
        // 创建复习记录
        createTestReviewLog(wordId: 1, word: "test1", result: "correct", date: today)
        createTestReviewLog(wordId: 2, word: "test2", result: "correct", date: today)
        createTestReviewLog(wordId: 1, word: "test1", result: "incorrect", date: today)
        
        dataManager.save()
        
        let stats = dataManager.getTodayStatistics()
        
        XCTAssertEqual(stats.newWords, 2, "今日新学单词数应该为2")
        XCTAssertEqual(stats.reviews, 3, "今日复习次数应该为3")
        XCTAssertEqual(stats.accuracy, 2.0/3.0, accuracy: 0.01, "今日正确率应该是2/3")
    }
    
    // MARK: - 连续学习天数测试
    
    func testCalculateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 模拟连续3天的学习记录
        for i in 0..<3 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            createTestReviewLog(wordId: Int32(i), word: "word\(i)", result: "correct", date: date)
        }
        
        dataManager.save()
        
        let streak = dataManager.calculateStreak()
        
        XCTAssertEqual(streak.current, 3, "当前连续天数应该是3天")
        XCTAssertEqual(streak.longest, 3, "最长连续天数应该是3天")
    }
    
    func testStreakBreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 今天和3天前有学习，中间断了
        createTestReviewLog(wordId: 1, word: "word1", result: "correct", date: today)
        
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        createTestReviewLog(wordId: 2, word: "word2", result: "correct", date: threeDaysAgo)
        
        dataManager.save()
        
        let streak = dataManager.calculateStreak()
        
        XCTAssertEqual(streak.current, 1, "当前连续天数应该是1天（因为昨天没学习）")
        XCTAssertEqual(streak.longest, 1, "最长连续天数应该是1天")
    }
    
    // MARK: - 学习趋势测试
    
    func testLearningTrendData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // 创建7天的数据
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            
            // 每天学习i个新词
            for j in 0..<(i+1) {
                let word = createTestWord(id: Int32(i * 10 + j), word: "day\(i)_word\(j)", status: "learning")
                word.createdAt = date
            }
            
            // 每天复习i*2次
            for j in 0..<(i*2) {
                createTestReviewLog(wordId: Int32(j), word: "word\(j)", result: "correct", date: date)
            }
        }
        
        dataManager.save()
        
        let trendData = dataManager.getLearningTrendData(days: 7)
        
        XCTAssertEqual(trendData.count, 7, "应该有7天的数据")
        XCTAssertEqual(trendData[6].newWords, 1, "最后一天应该有1个新词")
        XCTAssertEqual(trendData[6].reviews, 0, "最后一天应该有0次复习")
        XCTAssertEqual(trendData[0].newWords, 7, "第一天应该有7个新词")
        XCTAssertEqual(trendData[0].reviews, 12, "第一天应该有12次复习")
    }
    
    // MARK: - 词汇掌握统计测试
    
    func testMasteryStats() {
        // 创建不同状态的单词
        for i in 0..<10 {
            createTestWord(id: Int32(i), word: "new\(i)", status: "new")
        }
        
        for i in 10..<20 {
            createTestWord(id: Int32(i), word: "learning\(i)", status: "learning")
        }
        
        for i in 20..<30 {
            createTestWord(id: Int32(i), word: "mastered\(i)", status: "mastered")
        }
        
        dataManager.save()
        dataManager.updateStatistics()
        
        let stats = dataManager.getMasteryStats()
        
        XCTAssertEqual(stats.new, 10, "未学习单词应该是10个")
        XCTAssertEqual(stats.learning, 10, "学习中单词应该是10个")
        XCTAssertEqual(stats.mastered, 10, "已掌握单词应该是10个")
        XCTAssertEqual(stats.total, 30, "总单词数应该是30个")
    }
    
    // MARK: - 章节进度测试
    
    func testChapterProgress() {
        // 创建两个章节的单词
        for i in 0..<10 {
            let word = createTestWord(id: Int32(i), word: "chapter1_\(i)", status: i < 5 ? "mastered" : "learning", chapterKey: "01_test")
            if i >= 5 {
                word.status = i < 8 ? "learning" : "new"
            }
        }
        
        for i in 10..<20 {
            let word = createTestWord(id: Int32(i), word: "chapter2_\(i)", status: i < 15 ? "mastered" : "new", chapterKey: "02_test")
        }
        
        dataManager.save()
        
        let progress = dataManager.getChapterProgress()
        
        XCTAssertEqual(progress.count, 2, "应该有2个章节")
        
        if let chapter1 = progress.first(where: { $0.key == "01_test" }) {
            XCTAssertEqual(chapter1.total, 10, "第一章节应该有10个单词")
            XCTAssertEqual(chapter1.mastered, 5, "第一章节应该掌握5个")
            XCTAssertEqual(chapter1.learning, 3, "第一章节应该学习中3个")
            XCTAssertEqual(chapter1.progress, 0.5, accuracy: 0.01, "第一章节进度应该是50%")
        } else {
            XCTFail("找不到第一章节")
        }
        
        if let chapter2 = progress.first(where: { $0.key == "02_test" }) {
            XCTAssertEqual(chapter2.total, 10, "第二章节应该有10个单词")
            XCTAssertEqual(chapter2.mastered, 5, "第二章节应该掌握5个")
            XCTAssertEqual(chapter2.progress, 0.5, accuracy: 0.01, "第二章节进度应该是50%")
        } else {
            XCTFail("找不到第二章节")
        }
    }
}
