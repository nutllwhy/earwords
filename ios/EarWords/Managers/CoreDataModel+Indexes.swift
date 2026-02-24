//
//  CoreDataModel+Indexes.swift
//  EarWords
//
//  Core Data 索引配置 - 性能优化
//  添加关键字段索引提升查询性能
//

import Foundation
import CoreData

// MARK: - Core Data 索引配置

/// Core Data 性能优化配置
/// 为高频查询字段添加索引，显著提升大数据量下的查询性能
enum CoreDataIndexConfiguration {
    
    /// WordEntity 索引字段
    static let wordEntityIndexes: [(name: String, properties: [String])] = [
        // 主键索引 - 单词ID快速查找
        ("wordId_index", ["id"]),
        
        // 复合索引 - 复习查询优化
        ("review_query_index", ["status", "nextReviewDate"]),
        
        // 状态索引 - 快速筛选新词/学习中/已掌握
        ("status_index", ["status"]),
        
        // 章节索引 - 章节列表加载优化
        ("chapter_index", ["chapterKey"]),
        
        // 复合索引 - 章节内状态筛选
        ("chapter_status_index", ["chapterKey", "status"]),
        
        // 创建时间索引 - 统计查询优化
        ("createdAt_index", ["createdAt"]),
        
        // 复习日期索引 - 待复习查询
        ("nextReviewDate_index", ["nextReviewDate"]),
        
        // 难度索引 - 新词排序优化
        ("difficulty_index", ["difficulty"])
    ]
    
    /// ReviewLogEntity 索引字段
    static let reviewLogIndexes: [(name: String, properties: [String])] = [
        // 单词ID索引 - 快速获取单词复习历史
        ("log_wordId_index", ["wordId"]),
        
        // 复习日期索引 - 今日复习统计
        ("reviewDate_index", ["reviewDate"]),
        
        // 复合索引 - 按单词和日期查询
        ("word_date_index", ["wordId", "reviewDate"]),
        
        // 结果索引 - 正确率统计
        ("result_index", ["result"])
    ]
    
    /// 应用所有索引到模型
    static func applyIndexes(to container: NSPersistentContainer) {
        guard let model = container.managedObjectModel as? NSManagedObjectModel else {
            print("⚠️ 无法获取托管对象模型")
            return
        }
        
        // 配置 WordEntity 索引
        if let wordEntity = model.entities.first(where: { $0.name == "WordEntity" }) {
            applyIndexes(to: wordEntity, indexes: wordEntityIndexes)
        }
        
        // 配置 ReviewLogEntity 索引
        if let reviewLogEntity = model.entities.first(where: { $0.name == "ReviewLogEntity" }) {
            applyIndexes(to: reviewLogEntity, indexes: reviewLogIndexes)
        }
        
        print("✅ Core Data 索引配置完成")
    }
    
    /// 应用索引到实体
    private static func applyIndexes(
        to entity: NSEntityDescription,
        indexes: [(name: String, properties: [String])]
    ) {
        var entityIndexes: [NSFetchIndexDescription] = []
        
        for (indexName, propertyNames) in indexes {
            // 获取属性
            let properties = propertyNames.compactMap { entity.propertiesByName[$0] }
            
            guard properties.count == propertyNames.count else {
                print("⚠️ 索引 \(indexName) 部分属性未找到")
                continue
            }
            
            // 创建索引元素
            let elements = properties.map { property -> NSFetchIndexElementDescription in
                return NSFetchIndexElementDescription(
                    property: property,
                    collationType: .binary
                )
            }
            
            // 创建索引描述
            let index = NSFetchIndexDescription(name: indexName, elements: elements)
            entityIndexes.append(index)
        }
        
        // 设置实体索引
        entity.indexes = entityIndexes
        print("✅ \(entity.name ?? "Unknown") 已配置 \(entityIndexes.count) 个索引")
    }
}

// MARK: - 批处理查询优化

/// 批处理查询管理器
/// 避免 N+1 查询问题，提升大数据集处理性能
class BatchQueryManager {
    
    static let shared = BatchQueryManager()
    private let dataManager = DataManager.shared
    
    private init() {}
    
    // MARK: - 批处理查询方法
    
    /// 批量获取单词详细信息（避免 N+1）
    /// - Parameters:
    ///   - wordIds: 单词ID数组
    ///   - context: 查询上下文
    /// - Returns: ID到单词实体的映射
    func batchFetchWords(
        wordIds: [Int32],
        in context: NSManagedObjectContext
    ) async -> [Int32: WordEntity] {
        guard !wordIds.isEmpty else { return [:] }
        
        let request = WordEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "id IN %@",
            wordIds.map { NSNumber(value: $0) }
        )
        request.fetchLimit = wordIds.count
        
        return await context.perform {
            do {
                let words = try context.fetch(request)
                return Dictionary(uniqueKeysWithValues: words.map { ($0.id, $0) })
            } catch {
                print("❌ 批量获取单词失败: \(error)")
                return [:]
            }
        }
    }
    
    /// 批量获取复习记录（避免 N+1）
    /// - Parameters:
    ///   - wordIds: 单词ID数组
    ///   - context: 查询上下文
    /// - Returns: ID到复习记录数组的映射
    func batchFetchReviewLogs(
        for wordIds: [Int32],
        in context: NSManagedObjectContext
    ) async -> [Int32: [ReviewLogEntity]] {
        guard !wordIds.isEmpty else { return [:] }
        
        let request = ReviewLogEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "wordId IN %@",
            wordIds.map { NSNumber(value: $0) }
        )
        request.sortDescriptors = [
            NSSortDescriptor(key: "reviewDate", ascending: false)
        ]
        
        return await context.perform {
            do {
                let logs = try context.fetch(request)
                var groupedLogs: [Int32: [ReviewLogEntity]] = [:]
                
                for log in logs {
                    groupedLogs[log.wordId, default: []].append(log)
                }
                
                return groupedLogs
            } catch {
                print("❌ 批量获取复习记录失败: \(error)")
                return [:]
            }
        }
    }
    
    /// 批量更新单词状态（使用批处理请求）
    /// - Parameters:
    ///   - updates: 更新字典 [wordId: newStatus]
    ///   - completion: 完成回调
    func batchUpdateWordStatus(
        updates: [Int32: String],
        completion: ((Int) -> Void)? = nil
    ) {
        let context = dataManager.newBackgroundContext()
        
        context.perform {
            let batchSize = 500
            let allIds = Array(updates.keys)
            var totalUpdated = 0
            
            for batchStart in stride(from: 0, to: allIds.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, allIds.count)
                let batchIds = Array(allIds[batchStart..<batchEnd])
                
                let request = NSBatchUpdateRequest(entityName: "WordEntity")
                request.predicate = NSPredicate(
                    format: "id IN %@",
                    batchIds.map { NSNumber(value: $0) }
                )
                request.propertiesToUpdate = ["updatedAt": Date()]
                request.resultType = .updatedObjectIDsResultType
                
                do {
                    let result = try context.execute(request) as? NSBatchUpdateResult
                    let updatedCount = (result?.result as? [NSManagedObjectID])?.count ?? 0
                    totalUpdated += updatedCount
                } catch {
                    print("❌ 批量更新失败: \(error)")
                }
            }
            
            DispatchQueue.main.async {
                completion?(totalUpdated)
            }
        }
    }
    
    /// 分页获取单词列表
    /// - Parameters:
    ///   - predicate: 查询条件
    ///   - sortDescriptors: 排序规则
    ///   - pageSize: 每页大小
    ///   - page: 页码（从0开始）
    ///   - context: 查询上下文
    /// - Returns: 单词列表和总数量
    func fetchWordsPaginated(
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        pageSize: Int = 50,
        page: Int = 0,
        in context: NSManagedObjectContext
    ) async -> (words: [WordEntity], totalCount: Int) {
        let request = WordEntity.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        request.fetchLimit = pageSize
        request.fetchOffset = page * pageSize
        
        return await context.perform {
            do {
                let words = try context.fetch(request)
                
                // 获取总数（使用 count 请求优化性能）
                let countRequest = WordEntity.fetchRequest()
                countRequest.predicate = predicate
                let totalCount = try context.count(for: countRequest)
                
                return (words, totalCount)
            } catch {
                print("❌ 分页查询失败: \(error)")
                return ([], 0)
            }
        }
    }
}

// MARK: - 异步批处理扩展

extension DataManager {
    
    /// 后台异步批量导入（优化版）
    /// 使用批处理请求避免内存峰值
    func importVocabularyBatchOptimized(from jsonData: Data) async throws {
        let decoder = JSONDecoder()
        let words = try decoder.decode([WordJSON].self, from: jsonData)
        
        await MainActor.run {
            isImporting = true
            importProgress = 0
        }
        
        // 获取已存在的单词ID
        let existingIds = await fetchExistingWordIds()
        let newWords = words.filter { !existingIds.contains(Int32($0.id)) }
        
        guard !newWords.isEmpty else {
            await MainActor.run {
                isImporting = false
                importProgress = 1.0
                updateStatistics()
            }
            return
        }
        
        print("开始优化导入 \(newWords.count) 个新单词")
        
        // 使用更大的批次和批处理插入
        let batchSize = 500
        var importedCount = 0
        
        for batchStart in stride(from: 0, to: newWords.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, newWords.count)
            let batch = Array(newWords[batchStart..<batchEnd])
            
            try await importBatchOptimized(words: batch)
            importedCount += batch.count
            
            let progress = Double(importedCount) / Double(newWords.count)
            await MainActor.run {
                importProgress = progress
            }
            
            // 每批次后让出时间片
            try await Task.sleep(nanoseconds: 1_000_000) // 1ms
        }
        
        await MainActor.run {
            isImporting = false
            importProgress = 1.0
            updateStatistics()
        }
        
        print("成功优化导入 \(importedCount) 个单词")
    }
    
    /// 优化批次导入（使用 NSBatchInsertRequest）
    private func importBatchOptimized(words: [WordJSON]) async throws {
        let context = newBackgroundContext()
        
        try await context.perform {
            let batchInsert = NSBatchInsertRequest(
                entity: WordEntity.entity(),
                objects: words.map { wordJSON in
                    [
                        "id": Int32(wordJSON.id),
                        "word": wordJSON.word,
                        "phonetic": wordJSON.phonetic ?? "",
                        "pos": wordJSON.pos ?? "",
                        "meaning": wordJSON.meaning,
                        "example": wordJSON.example ?? "",
                        "extra": wordJSON.extra ?? "",
                        "chapter": wordJSON.chapter,
                        "chapterKey": wordJSON.chapterKey,
                        "difficulty": Int16(wordJSON.difficulty),
                        "audioUrl": wordJSON.audioUrl ?? "",
                        "status": "new",
                        "reviewCount": Int16(0),
                        "easeFactor": 2.5,
                        "interval": Int32(0),
                        "correctCount": Int16(0),
                        "incorrectCount": Int16(0),
                        "streak": Int16(0),
                        "createdAt": Date(),
                        "updatedAt": Date()
                    ]
                }
            )
            
            batchInsert.resultType = .count
            
            do {
                let result = try context.execute(batchInsert) as? NSBatchInsertResult
                print("✅ 批处理插入 \(result?.result ?? 0) 条记录")
            } catch {
                print("❌ 批处理插入失败: \(error)")
                throw error
            }
        }
    }
}

// MARK: - 性能监控

/// Core Data 查询性能监控
class CoreDataPerformanceMonitor {
    
    static let shared = CoreDataPerformanceMonitor()
    
    private var queryMetrics: [String: [TimeInterval]] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    /// 测量查询执行时间
    func measure<T>(
        queryName: String,
        operation: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let executionTime = CFAbsoluteTimeGetCurrent() - startTime
            recordMetric(queryName: queryName, executionTime: executionTime)
        }
        
        return try operation()
    }
    
    /// 记录性能指标
    private func recordMetric(queryName: String, executionTime: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        
        queryMetrics[queryName, default: []].append(executionTime)
        
        // 只保留最近100次记录
        if queryMetrics[queryName]!.count > 100 {
            queryMetrics[queryName]!.removeFirst()
        }
        
        // 记录慢查询（超过100ms）
        if executionTime > 0.1 {
            print("⚠️ 慢查询 [\(queryName)]: \(String(format: "%.3f", executionTime))s")
        }
    }
    
    /// 获取查询统计
    func getStatistics() -> [String: (avg: TimeInterval, max: TimeInterval, count: Int)] {
        lock.lock()
        defer { lock.unlock() }
        
        var stats: [String: (avg: TimeInterval, max: TimeInterval, count: Int)] = [:]
        
        for (queryName, times) in queryMetrics {
            let avg = times.reduce(0, +) / Double(times.count)
            let max = times.max() ?? 0
            stats[queryName] = (avg, max, times.count)
        }
        
        return stats
    }
    
    /// 打印性能报告
    func printPerformanceReport() {
        let stats = getStatistics()
        
        print("\n=== Core Data 性能报告 ===")
        print("查询名称\t\t平均耗时\t最大耗时\t执行次数")
        print("-".repeat(60))
        
        for (name, stat) in stats.sorted(by: { $0.value.avg > $1.value.avg }) {
            let nameDisplay = name.count > 20 ? String(name.prefix(17)) + "..." : name
            print("\(nameDisplay.padding(toLength: 20, withPad: " ", startingAt: 0))\t" +
                  "\(String(format: "%.3f", stat.avg))s\t" +
                  "\(String(format: "%.3f", stat.max))s\t" +
                  "\(stat.count)")
        }
        print("=".repeat(60) + "\n")
    }
}

// MARK: - String 扩展

private extension String {
    func repeat(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}
