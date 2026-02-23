//
//  ReviewLogEntity.swift
//  EarWords
//
//  Core Data 模型 - 复习记录实体
//

import Foundation
import CoreData

@objc(ReviewLogEntity)
public class ReviewLogEntity: NSManagedObject, Identifiable {
    
    @NSManaged public var id: UUID
    @NSManaged public var wordId: Int32
    @NSManaged public var word: String
    
    // 复习详情
    @NSManaged public var reviewDate: Date
    @NSManaged public var quality: Int16  // 0-5 评分 (SM-2)
    @NSManaged public var result: String  // correct, incorrect, hint
    
    // SM-2 算法记录
    @NSManaged public var previousEaseFactor: Double
    @NSManaged public var newEaseFactor: Double
    @NSManaged public var previousInterval: Int32
    @NSManaged public var newInterval: Int32
    @NSManaged public var timeSpent: Double  // 秒
    
    // 设备信息
    @NSManaged public var deviceType: String?
    @NSManaged public var studyMode: String  // normal, audio, quick
    
    static func fetchRequest() -> NSFetchRequest<ReviewLogEntity> {
        return NSFetchRequest<ReviewLogEntity>(entityName: "ReviewLogEntity")
    }
    
    /// 获取某单词的复习历史
    static func logsForWord(wordId: Int32) -> NSFetchRequest<ReviewLogEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "wordId == %d", wordId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ReviewLogEntity.reviewDate, ascending: false)]
        return request
    }
    
    /// 获取今日复习统计
    static func todayLogsRequest() -> NSFetchRequest<ReviewLogEntity> {
        let request = fetchRequest()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        request.predicate = NSPredicate(format: "reviewDate >= %@", startOfDay as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ReviewLogEntity.reviewDate, ascending: false)]
        return request
    }
}

// MARK: - 统计扩展
extension ReviewLogEntity {
    /// 计算某时间段内的学习统计
    static func statistics(since date: Date, context: NSManagedObjectContext) -> StudyStatistics {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "reviewDate >= %@", date as CVarArg)
        
        do {
            let logs = try context.fetch(request)
            return StudyStatistics(
                totalReviews: logs.count,
                correctCount: logs.filter { $0.result == "correct" }.count,
                averageQuality: logs.isEmpty ? 0 : Double(logs.map { $0.quality }.reduce(0, +)) / Double(logs.count),
                totalTime: logs.map { $0.timeSpent }.reduce(0, +)
            )
        } catch {
            return StudyStatistics()
        }
    }
}

struct StudyStatistics {
    var totalReviews: Int = 0
    var correctCount: Int = 0
    var averageQuality: Double = 0
    var totalTime: Double = 0
    
    var accuracy: Double {
        return totalReviews > 0 ? Double(correctCount) / Double(totalReviews) : 0
    }
    
    var averageTimePerCard: Double {
        return totalReviews > 0 ? totalTime / Double(totalReviews) : 0
    }
}
