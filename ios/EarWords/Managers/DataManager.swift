//
//  DataManager.swift
//  EarWords
//
//  Core Data 持久化管理器
//

import Foundation
import CoreData
import CloudKit

class DataManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = DataManager()
    
    // MARK: - 发布属性
    @Published var todayNewWordsCount: Int = 0
    @Published var todayReviewCount: Int = 0
    @Published var dueWordsCount: Int = 0
    
    // MARK: - Core Data 容器
    let persistentContainer: NSPersistentCloudKitContainer
    
    private init() {
        persistentContainer = NSPersistentCloudKitContainer(name: "EarWords")
        
        // 配置 CloudKit 同步
        guard let description = persistentContainer.persistentStoreDescriptions.first else {
            fatalError("Failed to get store description")
        }
        
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.lidengdeng.earwords")
        
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // 更新统计
        updateStatistics()
    }
    
    // MARK: - 上下文访问
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        persistentContainer.newBackgroundContext()
    }
    
    // MARK: - 数据导入
    
    /// 从 JSON 导入词库
    func importVocabulary(from jsonData: Data) async throws {
        let decoder = JSONDecoder()
        let words = try decoder.decode([WordJSON].self, from: jsonData)
        
        let context = newBackgroundContext()
        
        try await context.perform {
            for wordJSON in words {
                let entity = WordEntity(context: context)
                entity.populate(from: wordJSON)
            }
            try context.save()
        }
        
        await MainActor.run {
            self.updateStatistics()
        }
    }
    
    // MARK: - 查询方法
    
    /// 获取今日待复习单词
    func fetchDueWords(limit: Int = 50) -> [WordEntity] {
        let request = WordEntity.dueWordsRequest()
        request.fetchLimit = limit
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch due words: \(error)")
            return []
        }
    }
    
    /// 获取新单词
    func fetchNewWords(limit: Int = 20) -> [WordEntity] {
        let request = WordEntity.newWordsRequest(limit: limit)
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch new words: \(error)")
            return []
        }
    }
    
    /// 获取今日学习队列（新词 + 复习）
    func fetchTodayStudyQueue(newWordCount: Int = 20) -> (newWords: [WordEntity], reviewWords: [WordEntity]) {
        let newWords = fetchNewWords(limit: newWordCount)
        let reviewWords = fetchDueWords(limit: 50)
        return (newWords, reviewWords)
    }
    
    /// 搜索单词
    func searchWords(query: String) -> [WordEntity] {
        let request = WordEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "word CONTAINS[cd] %@ OR meaning CONTAINS[cd] %@",
            query, query
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WordEntity.word, ascending: true)]
        request.fetchLimit = 20
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    // MARK: - 复习记录
    
    /// 记录复习
    func logReview(
        word: WordEntity,
        quality: ReviewQuality,
        timeSpent: Double = 0,
        mode: String = "normal"
    ) {
        // 记录复习日志
        let log = ReviewLogEntity(context: context)
        log.id = UUID()
        log.wordId = word.id
        log.word = word.word
        log.reviewDate = Date()
        log.quality = quality.rawValue
        log.result = quality.rawValue >= 3 ? "correct" : "incorrect"
        log.previousEaseFactor = word.easeFactor
        log.previousInterval = word.interval
        log.timeSpent = timeSpent
        log.studyMode = mode
        
        // 应用 SM-2 算法
        word.applyReview(quality: quality, timeSpent: timeSpent)
        log.newEaseFactor = word.easeFactor
        log.newInterval = word.interval
        
        save()
        updateStatistics()
    }
    
    // MARK: - 统计
    
    func updateStatistics() {
        // 今日新学数量
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        let newWordsRequest = WordEntity.fetchRequest()
        newWordsRequest.predicate = NSPredicate(
            format: "createdAt >= %@ AND status != %@",
            startOfDay as CVarArg, "new"
        )
        todayNewWordsCount = (try? context.count(for: newWordsRequest)) ?? 0
        
        // 今日复习数量
        let reviewRequest = ReviewLogEntity.todayLogsRequest()
        todayReviewCount = (try? context.count(for: reviewRequest)) ?? 0
        
        // 待复习数量
        let dueRequest = WordEntity.dueWordsRequest()
        dueWordsCount = (try? context.count(for: dueRequest)) ?? 0
    }
    
    /// 获取学习统计
    func getStudyStatistics(days: Int = 7) -> [DailyStatistics] {
        let calendar = Calendar.current
        var stats: [DailyStatistics] = []
        
        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            
            let stat = ReviewLogEntity.statistics(since: startOfDay, context: context)
            stats.append(DailyStatistics(
                date: date,
                newWords: 0,  // 需要单独计算
                reviews: stat.totalReviews,
                accuracy: stat.accuracy
            ))
        }
        
        return stats
    }
    
    // MARK: - 工具方法
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
    
    /// 重置所有学习进度
    func resetAllProgress() {
        let request = WordEntity.fetchRequest()
        if let words = try? context.fetch(request) {
            for word in words {
                word.reset()
            }
        }
        
        // 清空复习记录
        let logRequest = ReviewLogEntity.fetchRequest()
        if let logs = try? context.fetch(logRequest) {
            for log in logs {
                context.delete(log)
            }
        }
        
        save()
        updateStatistics()
    }
}

// MARK: - 统计模型

struct DailyStatistics: Identifiable {
    let id = UUID()
    let date: Date
    let newWords: Int
    let reviews: Int
    let accuracy: Double
    
    var totalStudyItems: Int {
        newWords + reviews
    }
}
