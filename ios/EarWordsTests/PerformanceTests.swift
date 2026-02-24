//
//  PerformanceTests.swift
//  EarWordsTests
//
//  性能测试
//

import XCTest
@testable import EarWords

final class PerformanceTests: XCTestCase {
    
    var dataManager: DataManager!
    
    override func setUp() {
        super.setUp()
        dataManager = DataManager.shared
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - 启动性能测试
    
    func testLaunchTime() {
        measure {
            // 模拟应用启动时的核心操作
            let expectation = expectation(description: "Launch")
            
            Task {
                // 1. 初始化 Core Data
                _ = DataManager.shared
                
                // 2. 检查词库状态
                _ = DataManager.shared.isVocabularyImported()
                
                // 3. 更新统计
                DataManager.shared.updateStatistics()
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - 词库操作性能测试
    
    func testFetchNewWordsPerformance() {
        measure {
            _ = dataManager.fetchNewWords(limit: 20)
        }
    }
    
    func testFetchDueWordsPerformance() {
        measure {
            _ = dataManager.fetchDueWords(limit: 50)
        }
    }
    
    func testSearchWordsPerformance() {
        measure {
            _ = dataManager.searchWords(query: "ab")
        }
    }
    
    func testGetVocabularyStatsPerformance() {
        measure {
            _ = dataManager.getVocabularyStats()
        }
    }
    
    // MARK: - 批量操作性能测试
    
    func testBatchWordOperations() {
        let words = (1...100).map { i in
            WordJSON(
                id: Int32(i),
                word: "perf\(i)",
                phonetic: "/pɜːf\(i)/",
                pos: "n.",
                meaning: "性能\(i)",
                example: "Performance test \(i).",
                extra: nil,
                chapter: "01_性能测试",
                chapterKey: "01_perf",
                difficulty: Int(i % 5 + 1),
                audioUrl: nil
            )
        }
        
        measure {
            let expectation = expectation(description: "BatchInsert")
            
            Task {
                let jsonData = try! JSONEncoder().encode(words)
                try? await dataManager.importVocabulary(from: jsonData)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - 算法性能测试
    
    func testSM2AlgorithmPerformance() {
        measure {
            for _ in 0..<10000 {
                _ = SM2Algorithm.calculateNextReview(
                    quality: .good,
                    currentEaseFactor: 2.5,
                    currentInterval: 7,
                    reviewCount: 5
                )
            }
        }
    }
    
    func testReviewQualityLookupPerformance() {
        measure {
            for i in 0..<100000 {
                let quality = ReviewQuality(rawValue: Int16(i % 6))!
                _ = quality.nextIntervalDays
                _ = quality.isCorrect
                _ = quality.needsSameDayRepeat
            }
        }
    }
    
    // MARK: - 内存性能测试
    
    func testMemoryUsageWithLargeWordSet() {
        measure {
            autoreleasepool {
                // 获取大量单词
                _ = dataManager.fetchNewWords(limit: 500)
            }
        }
    }
    
    // MARK: - UI 性能测试
    
    func testOnboardingViewPerformance() {
        measure {
            // 创建引导页视图的性能
            let view = OnboardingView()
            _ = view.body
        }
    }
    
    func testWordCardViewPerformance() {
        // 注意：这里需要实际的 WordEntity，简化测试
        measure {
            // 模拟创建单词卡片视图
            for _ in 0..<100 {
                _ = WordCardView_Previews.previews
            }
        }
    }
}

// MARK: - 压力测试

final class StressTests: XCTestCase {
    
    var dataManager: DataManager!
    var studyManager: StudyManager!
    
    override func setUp() {
        super.setUp()
        dataManager = DataManager.shared
        studyManager = StudyManager.shared
    }
    
    // MARK: - 高并发测试
    
    func testConcurrentReviewLogging() async throws {
        await createTestWords(count: 100)
        let words = dataManager.fetchNewWords(limit: 100)
        
        let expectation = expectation(description: "ConcurrentReviews")
        expectation.expectedFulfillmentCount = 100
        
        // 并发提交复习记录
        await withTaskGroup(of: Void.self) { group in
            for (index, word) in words.enumerated() {
                group.addTask {
                    let quality = ReviewQuality(rawValue: Int16(index % 6)) ?? .good
                    self.studyManager.submitReview(word: word, quality: quality)
                    expectation.fulfill()
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 30.0)
        
        // 验证所有记录都已保存
        let records = dataManager.fetchStudyRecords(limit: 200)
        XCTAssertEqual(records.count, 100)
    }
    
    // MARK: - 大数据集测试
    
    func testLargeDatasetQueryPerformance() async {
        // 创建大量单词
        await createTestWords(count: 1000)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 执行多次查询
        for _ in 0..<10 {
            _ = dataManager.fetchNewWords(limit: 20)
            _ = dataManager.fetchDueWords(limit: 50)
            _ = dataManager.getVocabularyStats()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("1000词数据集查询耗时: \(timeElapsed) 秒")
        
        // 应该在合理时间内完成
        XCTAssertLessThan(timeElapsed, 5.0)
    }
    
    // MARK: - 辅助方法
    
    private func createTestWords(count: Int) async {
        let context = dataManager.newBackgroundContext()
        
        await context.perform {
            for i in 0..<count {
                let entity = WordEntity(context: context)
                entity.id = Int32(i + 1)
                entity.word = "stress\(i + 1)"
                entity.meaning = "压力测试\(i + 1)"
                entity.phonetic = "/stres/"
                entity.pos = "n."
                entity.chapter = "压力测试"
                entity.chapterKey = "01_stress"
                entity.difficulty = Int16(i % 5 + 1)
                entity.status = "new"
                entity.easeFactor = 2.5
                entity.interval = 0
                entity.reviewCount = 0
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
