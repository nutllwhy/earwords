//
//  SM2AlgorithmTests.swift
//  EarWordsTests
//
//  SM-2 算法单元测试
//

import XCTest
@testable import EarWords

final class SM2AlgorithmTests: XCTestCase {
    
    // MARK: - 复习质量评分测试
    
    func testReviewQualityRawValues() {
        XCTAssertEqual(ReviewQuality.blackOut.rawValue, 0)
        XCTAssertEqual(ReviewQuality.incorrect.rawValue, 1)
        XCTAssertEqual(ReviewQuality.difficult.rawValue, 2)
        XCTAssertEqual(ReviewQuality.hesitation.rawValue, 3)
        XCTAssertEqual(ReviewQuality.good.rawValue, 4)
        XCTAssertEqual(ReviewQuality.perfect.rawValue, 5)
    }
    
    func testReviewQualityDescriptions() {
        XCTAssertEqual(ReviewQuality.blackOut.description, "完全忘记")
        XCTAssertEqual(ReviewQuality.perfect.description, "完美")
    }
    
    func testReviewQualityNextIntervals() {
        XCTAssertEqual(ReviewQuality.blackOut.nextIntervalDays, 0)
        XCTAssertEqual(ReviewQuality.incorrect.nextIntervalDays, 0)
        XCTAssertEqual(ReviewQuality.difficult.nextIntervalDays, 1)
        XCTAssertEqual(ReviewQuality.hesitation.nextIntervalDays, 3)
        XCTAssertEqual(ReviewQuality.good.nextIntervalDays, 7)
        XCTAssertEqual(ReviewQuality.perfect.nextIntervalDays, 14)
    }
    
    func testReviewQualityNeedsSameDayRepeat() {
        XCTAssertTrue(ReviewQuality.blackOut.needsSameDayRepeat)
        XCTAssertTrue(ReviewQuality.incorrect.needsSameDayRepeat)
        XCTAssertFalse(ReviewQuality.difficult.needsSameDayRepeat)
        XCTAssertFalse(ReviewQuality.perfect.needsSameDayRepeat)
    }
    
    func testReviewQualityIsCorrect() {
        XCTAssertFalse(ReviewQuality.blackOut.isCorrect)
        XCTAssertFalse(ReviewQuality.incorrect.isCorrect)
        XCTAssertTrue(ReviewQuality.hesitation.isCorrect)
        XCTAssertTrue(ReviewQuality.good.isCorrect)
        XCTAssertTrue(ReviewQuality.perfect.isCorrect)
    }
    
    // MARK: - SM2 算法计算测试
    
    func testCalculateNextReview_FirstReviewPerfect() {
        let result = SM2Algorithm.calculateNextReview(
            quality: .perfect,
            currentEaseFactor: 2.5,
            currentInterval: 0,
            reviewCount: 0
        )
        
        XCTAssertEqual(result.interval, 14) // PRD 标准：第一次完美=14天
        XCTAssertTrue(result.easeFactor > 2.5) // 简易度应该增加
        XCTAssertFalse(result.shouldRepeat)
    }
    
    func testCalculateNextReview_FirstReviewGood() {
        let result = SM2Algorithm.calculateNextReview(
            quality: .good,
            currentEaseFactor: 2.5,
            currentInterval: 0,
            reviewCount: 0
        )
        
        XCTAssertEqual(result.interval, 7) // PRD 标准：第一次良好=7天
        XCTAssertFalse(result.shouldRepeat)
    }
    
    func testCalculateNextReview_FirstReviewHesitation() {
        let result = SM2Algorithm.calculateNextReview(
            quality: .hesitation,
            currentEaseFactor: 2.5,
            currentInterval: 0,
            reviewCount: 0
        )
        
        XCTAssertEqual(result.interval, 3) // PRD 标准：第一次犹豫=3天
        XCTAssertFalse(result.shouldRepeat)
    }
    
    func testCalculateNextReview_FirstReviewDifficult() {
        let result = SM2Algorithm.calculateNextReview(
            quality: .difficult,
            currentEaseFactor: 2.5,
            currentInterval: 0,
            reviewCount: 0
        )
        
        XCTAssertEqual(result.interval, 1) // PRD 标准：困难=1天
        XCTAssertFalse(result.shouldRepeat)
    }
    
    func testCalculateNextReview_BlackOut() {
        let result = SM2Algorithm.calculateNextReview(
            quality: .blackOut,
            currentEaseFactor: 2.5,
            currentInterval: 7,
            reviewCount: 2
        )
        
        XCTAssertEqual(result.interval, 0) // 当天重复
        XCTAssertTrue(result.shouldRepeat)
        XCTAssertTrue(result.easeFactor < 2.5) // 简易度应该降低
    }
    
    func testCalculateNextReview_Incorrect() {
        let result = SM2Algorithm.calculateNextReview(
            quality: .incorrect,
            currentEaseFactor: 2.5,
            currentInterval: 7,
            reviewCount: 2
        )
        
        XCTAssertEqual(result.interval, 0) // 当天重复
        XCTAssertTrue(result.shouldRepeat)
    }
    
    func testCalculateNextReview_SubsequentReviews() {
        // 测试第二次及以后的复习
        let result1 = SM2Algorithm.calculateNextReview(
            quality: .good,
            currentEaseFactor: 2.5,
            currentInterval: 7,
            reviewCount: 1
        )
        
        // 第二次复习：7 * 2.5 = 17.5 ≈ 17天
        XCTAssertTrue(result1.interval > 7)
        
        let result2 = SM2Algorithm.calculateNextReview(
            quality: .good,
            currentEaseFactor: result1.easeFactor,
            currentInterval: result1.interval,
            reviewCount: 2
        )
        
        // 第三次复习：interval * easeFactor
        XCTAssertTrue(result2.interval > result1.interval)
    }
    
    func testEaseFactorMinimumBound() {
        // 测试简易度不会低于最小值 1.3
        let result = SM2Algorithm.calculateNextReview(
            quality: .blackOut,
            currentEaseFactor: 1.3,
            currentInterval: 30,
            reviewCount: 5
        )
        
        XCTAssertGreaterThanOrEqual(result.easeFactor, 1.3)
    }
    
    func testMaxIntervalBound() {
        // 测试最大间隔限制
        let result = SM2Algorithm.calculateNextReview(
            quality: .perfect,
            currentEaseFactor: 3.0,
            currentInterval: 300,
            reviewCount: 10
        )
        
        XCTAssertLessThanOrEqual(result.interval, 365)
    }
    
    // MARK: - 下次复习日期计算测试
    
    func testNextReviewDate_WithInterval() {
        let baseDate = Date()
        let result = SM2Algorithm.nextReviewDate(from: baseDate, interval: 7)
        
        // 应该比 baseDate 晚 7 天
        let daysDifference = Calendar.current.dateComponents([.day], from: baseDate, to: result).day
        XCTAssertEqual(daysDifference, 7)
    }
    
    func testNextReviewDate_SameDayRepeat() {
        let baseDate = Date()
        let result = SM2Algorithm.nextReviewDate(from: baseDate, interval: 0)
        
        // 应该比 baseDate 晚 1 小时
        let hoursDifference = Calendar.current.dateComponents([.hour], from: baseDate, to: result).hour
        XCTAssertEqual(hoursDifference, 1)
    }
    
    // MARK: - 单词状态测试
    
    func testWordStatus_New() {
        let status = SM2Algorithm.wordStatus(reviewCount: 0, quality: nil)
        XCTAssertEqual(status, .new)
    }
    
    func testWordStatus_Learning() {
        let status = SM2Algorithm.wordStatus(reviewCount: 1, quality: .good)
        XCTAssertEqual(status, .learning)
    }
    
    func testWordStatus_Mastered() {
        let status = SM2Algorithm.wordStatus(reviewCount: 5, quality: .perfect)
        XCTAssertEqual(status, .mastered)
    }
    
    // MARK: - 建议评分测试
    
    func testSuggestedQuality() {
        XCTAssertEqual(SM2Algorithm.suggestedQuality(accuracy: 0.2, responseTime: 1.0), .blackOut)
        XCTAssertEqual(SM2Algorithm.suggestedQuality(accuracy: 0.4, responseTime: 1.0), .incorrect)
        XCTAssertEqual(SM2Algorithm.suggestedQuality(accuracy: 0.6, responseTime: 1.0), .difficult)
        XCTAssertEqual(SM2Algorithm.suggestedQuality(accuracy: 0.8, responseTime: 1.0), .hesitation)
        XCTAssertEqual(SM2Algorithm.suggestedQuality(accuracy: 0.9, responseTime: 5.0), .good) // 时间长
        XCTAssertEqual(SM2Algorithm.suggestedQuality(accuracy: 0.98, responseTime: 1.0), .perfect)
    }
    
    // MARK: - 性能测试
    
    func testAlgorithmPerformance() {
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
}

// MARK: - WordEntity 扩展测试

final class WordEntityTests: XCTestCase {
    
    func testAccuracyCalculation() {
        // 这个测试需要 Core Data 上下文，在实际测试环境中创建
        // 这里仅测试计算逻辑
        let correct: Int16 = 8
        let incorrect: Int16 = 2
        let total = correct + incorrect
        let accuracy = total > 0 ? Double(correct) / Double(total) : 0
        
        XCTAssertEqual(accuracy, 0.8)
    }
    
    func testWordStatusColor() {
        XCTAssertEqual(WordStatus.new.color, "blue")
        XCTAssertEqual(WordStatus.learning.color, "orange")
        XCTAssertEqual(WordStatus.mastered.color, "green")
    }
    
    func testWordStatusDescription() {
        XCTAssertEqual(WordStatus.new.description, "新词")
        XCTAssertEqual(WordStatus.learning.description, "学习中")
        XCTAssertEqual(WordStatus.mastered.description, "已掌握")
    }
}

// MARK: - ReviewResult 测试

final class ReviewResultTests: XCTestCase {
    
    func testReviewResultProperties() {
        let result = ReviewResult(
            quality: .good,
            previousEaseFactor: 2.5,
            newEaseFactor: 2.6,
            previousInterval: 7,
            newInterval: 14,
            shouldRepeat: false,
            nextReviewDate: Date(),
            timeSpent: 2.5
        )
        
        XCTAssertTrue(result.isCorrect)
        XCTAssertEqual(result.intervalChange, 7)
        XCTAssertEqual(result.easeFactorChange, 0.1, accuracy: 0.001)
    }
}
