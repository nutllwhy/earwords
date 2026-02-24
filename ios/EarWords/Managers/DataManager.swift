//
//  DataManager.swift
//  EarWords
//
//  Core Data 持久化管理器 - 完善版
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
    @Published var isImporting: Bool = false
    @Published var importProgress: Double = 0
    @Published var totalWordsCount: Int = 0
    @Published var newWordsCount: Int = 0
    @Published var learningWordsCount: Int = 0
    @Published var masteredWordsCount: Int = 0
    
    // MARK: - Core Data 容器
    let persistentContainer: NSPersistentCloudKitContainer
    
    // MARK: - 导入队列
    private let importQueue = DispatchQueue(label: "com.earwords.import", qos: .background)
    
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
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    // MARK: - 词库导入
    
    /// 从 Bundle 导入词库（主入口）
    func importVocabularyFromBundle() async throws {
        guard let url = Bundle.main.url(forResource: "ielts-vocabulary-with-phonetics", withExtension: "json") else {
            // 尝试其他路径
            let possiblePaths = [
                "/Users/nutllwhy/.openclaw/workspace/plans/earwords/data/ielts-vocabulary-with-phonetics.json",
                Bundle.main.bundleURL.appendingPathComponent("ielts-vocabulary-with-phonetics.json").path,
                Bundle.main.resourceURL?.appendingPathComponent("ielts-vocabulary-with-phonetics.json").path
            ].compactMap { $0 }
            
            for path in possiblePaths {
                let fileURL = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let data = try Data(contentsOf: fileURL)
                    try await importVocabulary(from: data)
                    return
                }
            }
            
            throw ImportError.fileNotFound
        }
        
        let data = try Data(contentsOf: url)
        try await importVocabulary(from: data)
    }
    
    /// 从 JSON 数据导入词库（批量导入，避免重复）
    func importVocabulary(from jsonData: Data) async throws {
        let decoder = JSONDecoder()
        let words = try decoder.decode([WordJSON].self, from: jsonData)
        
        await MainActor.run {
            isImporting = true
            importProgress = 0
        }
        
        // 获取已存在的单词ID集合（避免重复导入）
        let existingIds = await fetchExistingWordIds()
        
        // 过滤掉已存在的单词
        let newWords = words.filter { !existingIds.contains(Int32($0.id)) }
        
        guard !newWords.isEmpty else {
            await MainActor.run {
                isImporting = false
                importProgress = 1.0
                updateStatistics()
            }
            print("所有单词已存在，无需导入")
            return
        }
        
        print("开始导入 \(newWords.count) 个新单词（已过滤 \(words.count - newWords.count) 个重复单词）")
        
        // 批量导入：每批200个，减少内存占用
        let batchSize = 200
        var importedCount = 0
        
        for batchStart in stride(from: 0, to: newWords.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, newWords.count)
            let batch = Array(newWords[batchStart..<batchEnd])
            
            try await importBatch(words: batch)
            importedCount += batch.count
            
            let progress = Double(importedCount) / Double(newWords.count)
            await MainActor.run {
                importProgress = progress
            }
            
            // 小延迟让UI有机会更新
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        await MainActor.run {
            isImporting = false
            importProgress = 1.0
            updateStatistics()
        }
        
        print("成功导入 \(importedCount) 个单词")
    }
    
    /// 批量导入一批单词
    private func importBatch(words: [WordJSON]) async throws {
        let context = newBackgroundContext()
        
        try await context.perform {
            for wordJSON in words {
                let entity = WordEntity(context: context)
                entity.populate(from: wordJSON, chapterKey: wordJSON.chapterKey)
            }
            
            try context.save()
        }
    }
    
    /// 获取已存在的单词ID集合
    private func fetchExistingWordIds() async -> Set<Int32> {
        let context = newBackgroundContext()
        
        return await context.perform {
            let request = NSFetchRequest<NSDictionary>(entityName: "WordEntity")
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["id"]
            
            do {
                let results = try context.fetch(request)
                let ids = results.compactMap { $0["id"] as? Int32 }
                return Set(ids)
            } catch {
                print("获取现有单词ID失败: \(error)")
                return Set<Int32>()
            }
        }
    }
    
    /// 检查词库是否已导入
    func isVocabularyImported() -> Bool {
        let request = WordEntity.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            return false
        }
    }
    
    /// 获取词库统计信息
    func getVocabularyStats() -> VocabularyStats {
        let totalRequest = WordEntity.fetchRequest()
        let newRequest = WordEntity.fetchRequest()
        newRequest.predicate = NSPredicate(format: "status == %@", "new")
        let learningRequest = WordEntity.fetchRequest()
        learningRequest.predicate = NSPredicate(format: "status == %@", "learning")
        let masteredRequest = WordEntity.fetchRequest()
        masteredRequest.predicate = NSPredicate(format: "status == %@", "mastered")
        
        do {
            return VocabularyStats(
                total: try context.count(for: totalRequest),
                new: try context.count(for: newRequest),
                learning: try context.count(for: learningRequest),
                mastered: try context.count(for: masteredRequest)
            )
        } catch {
            return VocabularyStats(total: 0, new: 0, learning: 0, mastered: 0)
        }
    }
    
    // MARK: - 查询方法
    
    /// 按章节获取单词
    func fetchWordsByChapter(chapterKey: String) -> [WordEntity] {
        let request = WordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "chapterKey == %@", chapterKey)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \WordEntity.id, ascending: true)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch words by chapter: \(error)")
            return []
        }
    }
    
    /// 获取所有章节列表
    func fetchAllChapters() -> [ChapterInfo] {
        let request = NSFetchRequest<NSDictionary>(entityName: "WordEntity")
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["chapter", "chapterKey"]
        request.returnsDistinctResults = true
        
        do {
            let results = try context.fetch(request)
            var chapters: [ChapterInfo] = []
            
            for dict in results {
                if let chapter = dict["chapter"] as? String,
                   let chapterKey = dict["chapterKey"] as? String {
                    let wordCount = countWordsInChapter(chapterKey: chapterKey)
                    chapters.append(ChapterInfo(
                        name: chapter,
                        key: chapterKey,
                        wordCount: wordCount
                    ))
                }
            }
            
            return chapters.sorted { $0.key < $1.key }
        } catch {
            print("Failed to fetch chapters: \(error)")
            return []
        }
    }
    
    /// 统计章节单词数
    private func countWordsInChapter(chapterKey: String) -> Int {
        let request = WordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "chapterKey == %@", chapterKey)
        
        do {
            return try context.count(for: request)
        } catch {
            return 0
        }
    }
    
    /// 按复习日期获取单词（获取某天或之前需要复习的单词）
    func fetchWordsForReview(date: Date? = nil) -> [WordEntity] {
        let targetDate = date ?? Date()
        let calendar = Calendar.current
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: targetDate) ?? targetDate
        
        let request = WordEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "(nextReviewDate <= %@ OR nextReviewDate == nil) AND status != %@",
            endOfDay as CVarArg,
            "new"
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \WordEntity.nextReviewDate, ascending: true),
            NSSortDescriptor(keyPath: \WordEntity.difficulty, ascending: true)
        ]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch words for review: \(error)")
            return []
        }
    }
    
    /// 获取新单词（未学习）
    func fetchNewWords(limit: Int = 20) -> [WordEntity] {
        let request = WordEntity.newWordsRequest(limit: limit)
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch new words: \(error)")
            return []
        }
    }
    
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
    
    /// 获取今日学习队列（新词 + 复习）
    func fetchTodayStudyQueue(newWordCount: Int = 20) -> (newWords: [WordEntity], reviewWords: [WordEntity]) {
        let newWords = fetchNewWords(limit: newWordCount)
        let reviewWords = fetchDueWords(limit: 50)
        return (newWords, reviewWords)
    }
    
    /// 获取学习记录（复习日志）
    func fetchStudyRecords(limit: Int = 100) -> [StudyRecord] {
        let request = ReviewLogEntity.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReviewLogEntity.reviewDate, ascending: false)
        ]
        request.fetchLimit = limit
        
        do {
            let logs = try context.fetch(request)
            return logs.map { StudyRecord(from: $0) }
        } catch {
            print("Failed to fetch study records: \(error)")
            return []
        }
    }
    
    /// 获取指定日期的学习记录
    func fetchStudyRecords(for date: Date) -> [StudyRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request = ReviewLogEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "reviewDate >= %@ AND reviewDate < %@",
            startOfDay as CVarArg,
            endOfDay as CVarArg
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReviewLogEntity.reviewDate, ascending: false)
        ]
        
        do {
            let logs = try context.fetch(request)
            return logs.map { StudyRecord(from: $0) }
        } catch {
            print("Failed to fetch study records for date: \(error)")
            return []
        }
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
    
    /// 搜索单词（带状态筛选）
    func searchWords(query: String, status: String? = nil) -> [WordEntity] {
        let request = WordEntity.fetchRequest()
        
        if let status = status {
            request.predicate = NSPredicate(
                format: "(word CONTAINS[cd] %@ OR meaning CONTAINS[cd] %@) AND status == %@",
                query, query, status
            )
        } else {
            request.predicate = NSPredicate(
                format: "word CONTAINS[cd] %@ OR meaning CONTAINS[cd] %@",
                query, query
            )
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WordEntity.word, ascending: true)]
        request.fetchLimit = 50
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    /// 按状态获取单词
    func fetchWordsByStatus(status: String, limit: Int = 100) -> [WordEntity] {
        let request = WordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", status)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WordEntity.word, ascending: true)]
        request.fetchLimit = limit
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    /// 获取某章节中特定状态的单词
    func fetchWordsInChapter(chapterKey: String, status: String? = nil) -> [WordEntity] {
        let request = WordEntity.fetchRequest()
        
        if let status = status {
            request.predicate = NSPredicate(
                format: "chapterKey == %@ AND status == %@",
                chapterKey, status
            )
        } else {
            request.predicate = NSPredicate(format: "chapterKey == %@", chapterKey)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WordEntity.word, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    /// 根据ID获取单词
    func fetchWord(byId id: Int32) -> WordEntity? {
        let request = WordEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %d", id)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            return nil
        }
    }
    
    // MARK: - 复习记录
    
    /// 记录复习
    func logReview(
        word: WordEntity,
        quality: ReviewQuality,
        timeSpent: Double = 0,
        mode: String = "normal"
    ) -> ReviewLogEntity {
        // 记录旧值
        let previousEaseFactor = word.easeFactor
        let previousInterval = word.interval
        
        // 应用 SM-2 算法并获取结果
        let result = word.applyReview(quality: quality, timeSpent: timeSpent)
        
        // 记录复习日志
        let log = ReviewLogEntity(context: context)
        log.id = UUID()
        log.wordId = word.id
        log.word = word.word
        log.reviewDate = Date()
        log.quality = quality.rawValue
        log.result = quality.rawValue >= 3 ? "correct" : "incorrect"
        
        // 记录 SM-2 算法变化
        log.previousEaseFactor = previousEaseFactor
        log.newEaseFactor = result.newEaseFactor
        log.previousInterval = previousInterval
        log.newInterval = Int32(result.newInterval)
        
        log.timeSpent = timeSpent
        log.studyMode = mode
        
        save()
        updateStatistics()
        
        return log
    }
    
    /// 记录复习（简化评分版本）
    func logReview(
        word: WordEntity,
        simpleRating: SimpleRating,
        timeSpent: Double = 0,
        mode: String = "normal"
    ) -> SimpleReviewResult {
        // 应用简化评分算法
        let result = word.applyReview(simpleRating: simpleRating, timeSpent: timeSpent)
        
        // 记录复习日志（映射回旧的quality值用于数据兼容）
        let log = ReviewLogEntity(context: context)
        log.id = UUID()
        log.wordId = word.id
        log.word = word.word
        log.reviewDate = Date()
        log.quality = simpleRating.reviewQuality.rawValue
        log.result = simpleRating.isCorrect ? "correct" : "incorrect"
        
        // 记录 SM-2 算法变化
        log.previousEaseFactor = result.previousEaseFactor
        log.newEaseFactor = result.newEaseFactor
        log.previousInterval = Int32(result.previousInterval)
        log.newInterval = Int32(result.newInterval)
        
        log.timeSpent = timeSpent
        log.studyMode = mode
        
        save()
        updateStatistics()
        
        return result
    }
    
    // MARK: - 统计
    
    func updateStatistics() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        // 今日新学数量
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
        
        // 更新各类单词数量
        let stats = getVocabularyStats()
        totalWordsCount = stats.total
        newWordsCount = stats.new
        learningWordsCount = stats.learning
        masteredWordsCount = stats.mastered
    }
    
    // MARK: - 今日统计
    
    /// 获取今日概览统计
    func getTodayStatistics() -> TodayStatistics {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // 今日新学单词数（从new状态变为learning的单词）
        let newWordsRequest = WordEntity.fetchRequest()
        newWordsRequest.predicate = NSPredicate(
            format: "status != %@ AND createdAt >= %@ AND createdAt < %@",
            "new",
            startOfDay as CVarArg,
            endOfDay as CVarArg
        )
        let newWords = (try? context.count(for: newWordsRequest)) ?? 0
        
        // 今日复习数（从ReviewLog统计）
        let reviewRequest = ReviewLogEntity.fetchRequest()
        reviewRequest.predicate = NSPredicate(
            format: "reviewDate >= %@ AND reviewDate < %@",
            startOfDay as CVarArg,
            endOfDay as CVarArg
        )
        let reviews = (try? context.count(for: reviewRequest)) ?? 0
        
        // 今日正确率
        let correctRequest = ReviewLogEntity.fetchRequest()
        correctRequest.predicate = NSPredicate(
            format: "reviewDate >= %@ AND reviewDate < %@ AND result == %@",
            startOfDay as CVarArg,
            endOfDay as CVarArg,
            "correct"
        )
        let correct = (try? context.count(for: correctRequest)) ?? 0
        let accuracy = reviews > 0 ? Double(correct) / Double(reviews) : 0
        
        return TodayStatistics(
            newWords: newWords,
            reviews: reviews,
            accuracy: accuracy
        )
    }
    
    // MARK: - 连续学习天数
    
    /// 计算连续学习天数（streak）
    func calculateStreak() -> (current: Int, longest: Int) {
        let logsRequest = ReviewLogEntity.fetchRequest()
        logsRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \ReviewLogEntity.reviewDate, ascending: false)
        ]
        
        guard let logs = try? context.fetch(logsRequest), !logs.isEmpty else {
            return (0, 0)
        }
        
        // 提取所有有学习记录的日期（去重）
        let calendar = Calendar.current
        var studyDates: Set<Date> = []
        for log in logs {
            if let date = log.reviewDate {
                let startOfDay = calendar.startOfDay(for: date)
                studyDates.insert(startOfDay)
            }
        }
        
        let sortedDates = studyDates.sorted(by: >)
        guard !sortedDates.isEmpty else { return (0, 0) }
        
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        // 计算当前连续天数
        var currentStreak = 0
        var checkDate = sortedDates.first!
        
        // 如果今天或昨天没有学习，当前连续为0
        if checkDate == today || checkDate == yesterday {
            currentStreak = 1
            for i in 1..<sortedDates.count {
                let expectedDate = calendar.date(byAdding: .day, value: -i, to: checkDate)!
                if sortedDates[i] == expectedDate {
                    currentStreak += 1
                } else {
                    break
                }
            }
        }
        
        // 计算最长连续天数
        var longestStreak = 1
        var currentCount = 1
        
        for i in 1..<sortedDates.count {
            let prevDate = sortedDates[i-1]
            let currDate = sortedDates[i]
            let expectedPrev = calendar.date(byAdding: .day, value: -1, to: prevDate)!
            
            if currDate == expectedPrev {
                currentCount += 1
                longestStreak = max(longestStreak, currentCount)
            } else {
                currentCount = 1
            }
        }
        
        return (currentStreak, max(longestStreak, currentStreak))
    }
    
    // MARK: - 学习趋势数据
    
    /// 获取学习趋势数据（用于图表）
    func getLearningTrendData(days: Int) -> [DailyDataPoint] {
        let calendar = Calendar.current
        var dataPoints: [DailyDataPoint] = []
        
        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            // 新学单词数
            let newWordsRequest = WordEntity.fetchRequest()
            newWordsRequest.predicate = NSPredicate(
                format: "status != %@ AND createdAt >= %@ AND createdAt < %@",
                "new",
                startOfDay as CVarArg,
                endOfDay as CVarArg
            )
            let newWords = (try? context.count(for: newWordsRequest)) ?? 0
            
            // 复习数
            let reviewRequest = ReviewLogEntity.fetchRequest()
            reviewRequest.predicate = NSPredicate(
                format: "reviewDate >= %@ AND reviewDate < %@",
                startOfDay as CVarArg,
                endOfDay as CVarArg
            )
            let reviews = (try? context.count(for: reviewRequest)) ?? 0
            
            dataPoints.append(DailyDataPoint(
                date: date,
                newWords: newWords,
                reviews: reviews
            ))
        }
        
        return dataPoints
    }
    
    // MARK: - 章节进度
    
    /// 获取所有章节的进度
    func getChapterProgress() -> [ChapterProgress] {
        let chapters = fetchAllChapters()
        var progressList: [ChapterProgress] = []
        
        for chapter in chapters {
            let words = fetchWordsByChapter(chapterKey: chapter.key)
            let total = words.count
            let mastered = words.filter { $0.status == "mastered" }.count
            let learning = words.filter { $0.status == "learning" }.count
            
            progressList.append(ChapterProgress(
                id: chapter.id,
                name: chapter.name,
                key: chapter.key,
                total: total,
                mastered: mastered,
                learning: learning
            ))
        }
        
        return progressList.sorted { $0.key < $1.key }
    }
    
    // MARK: - 词汇掌握统计
    
    /// 获取词汇掌握情况统计
    func getMasteryStats() -> MasteryStats {
        return MasteryStats(
            new: newWordsCount,
            learning: learningWordsCount,
            mastered: masteredWordsCount
        )
    }
    
    /// 获取学习统计
    func getStudyStatistics(days: Int = 7) -> [DailyStatistics] {
        let calendar = Calendar.current
        var stats: [DailyStatistics] = []
        
        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            
            // 计算当日新学单词数
            let newWordsRequest = WordEntity.fetchRequest()
            newWordsRequest.predicate = NSPredicate(
                format: "status != %@ AND createdAt >= %@ AND createdAt < %@",
                "new",
                startOfDay as CVarArg,
                calendar.date(byAdding: .day, value: 1, to: startOfDay)! as CVarArg
            )
            let newWords = (try? context.count(for: newWordsRequest)) ?? 0
            
            // 计算当日复习数
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            let reviewRequest = ReviewLogEntity.fetchRequest()
            reviewRequest.predicate = NSPredicate(
                format: "reviewDate >= %@ AND reviewDate < %@",
                startOfDay as CVarArg,
                endOfDay as CVarArg
            )
            let reviews = (try? context.count(for: reviewRequest)) ?? 0
            
            // 计算正确率
            let correctRequest = ReviewLogEntity.fetchRequest()
            correctRequest.predicate = NSPredicate(
                format: "reviewDate >= %@ AND reviewDate < %@ AND result == %@",
                startOfDay as CVarArg,
                endOfDay as CVarArg,
                "correct"
            )
            let correct = (try? context.count(for: correctRequest)) ?? 0
            let accuracy = reviews > 0 ? Double(correct) / Double(reviews) : 0
            
            stats.append(DailyStatistics(
                date: date,
                newWords: newWords,
                reviews: reviews,
                accuracy: accuracy
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
    
    /// 删除所有单词（谨慎使用）
    func deleteAllWords() {
        let request = WordEntity.fetchRequest()
        if let words = try? context.fetch(request) {
            for word in words {
                context.delete(word)
            }
        }
        
        // 同时删除复习记录
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

// MARK: - 导入错误

enum ImportError: Error {
    case fileNotFound
    case invalidJSON
    case importFailed(String)
    
    var localizedDescription: String {
        switch self {
        case .fileNotFound:
            return "找不到词库文件"
        case .invalidJSON:
            return "词库文件格式错误"
        case .importFailed(let message):
            return "导入失败: \(message)"
        }
    }
}

// MARK: - 统计模型

struct VocabularyStats {
    let total: Int
    let new: Int
    let learning: Int
    let mastered: Int
}

struct ChapterInfo: Identifiable {
    let id = UUID()
    let name: String
    let key: String
    let wordCount: Int
}

// MARK: - 统计模型扩展

struct TodayStatistics {
    let newWords: Int
    let reviews: Int
    let accuracy: Double
}

struct DailyDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let newWords: Int
    let reviews: Int
    
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

struct ChapterProgress: Identifiable {
    let id: UUID
    let name: String
    let key: String
    let total: Int
    let mastered: Int
    let learning: Int
    
    var progress: Double {
        total > 0 ? Double(mastered) / Double(total) : 0
    }
}

struct MasteryStats {
    let new: Int
    let learning: Int
    let mastered: Int
    
    var total: Int {
        new + learning + mastered
    }
}

struct StudyRecord: Identifiable {
    let id: UUID
    let wordId: Int32
    let word: String
    let reviewDate: Date
    let quality: Int
    let result: String
    let timeSpent: Double
    
    init(from log: ReviewLogEntity) {
        self.id = log.id ?? UUID()
        self.wordId = log.wordId
        self.word = log.word ?? ""
        self.reviewDate = log.reviewDate ?? Date()
        self.quality = Int(log.quality)
        self.result = log.result ?? ""
        self.timeSpent = log.timeSpent
    }
}

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

// MARK: - WordJSON 扩展

extension WordJSON {
    /// 从 chapter 字段生成 chapterKey
    var chapterKey: String {
        // 如果 chapter 格式为 "01_自然地理"，则直接使用
        // 否则生成一个安全的 key
        let sanitized = chapter
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        return sanitized
    }
}
