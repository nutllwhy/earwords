//
//  VocabularyImporter.swift
//  EarWords
//
//  词库导入工具 - 专门处理大批量数据导入
//

import Foundation
import CoreData
import Combine

/// 导入状态
enum ImportStatus: Equatable {
    case idle
    case preparing
    case importing(progress: Double, imported: Int, total: Int)
    case completed(imported: Int, skipped: Int)
    case failed(error: String)
    case skipped
    
    static func == (lhs: ImportStatus, rhs: ImportStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.preparing, .preparing), (.skipped, .skipped):
            return true
        case let (.importing(l1, l2, l3), .importing(r1, r2, r3)):
            return l1 == r1 && l2 == r2 && l3 == r3
        case let (.completed(l1, l2), .completed(r1, r2)):
            return l1 == r1 && l2 == r2
        case let (.failed(l), .failed(r)):
            return l == r
        default:
            return false
        }
    }
}

/// 词库导入工具类 - 支持后台异步导入、优先级导入、进度回调
class VocabularyImporter: ObservableObject {
    
    // MARK: - 配置
    
    struct ImportConfig {
        var batchSize: Int = 200
        var saveThreshold: Int = 1000
        var priorityCount: Int = 100  // 优先导入前N个单词
        var reportProgress: (Int, Int) -> Void = { _, _ in }
        var onStatusChange: (ImportStatus) -> Void = { _ in }
    }
    
    // MARK: - 属性
    
    private let context: NSManagedObjectContext
    private var config: ImportConfig
    private var importTask: Task<Void, Never>?
    private let logger = ImportLogger.shared
    
    @Published var status: ImportStatus = .idle
    
    /// 是否正在导入中
    var isImporting: Bool {
        if case .importing = status { return true }
        return false
    }
    
    /// 是否已完成导入
    var isCompleted: Bool {
        if case .completed = status { return true }
        return false
    }
    
    /// 导入进度（0.0 - 1.0）
    var progress: Double {
        switch status {
        case .importing(let progress, _, _):
            return progress
        case .completed:
            return 1.0
        default:
            return 0.0
        }
    }
    
    init(context: NSManagedObjectContext, config: ImportConfig = ImportConfig()) {
        self.context = context
        self.config = config
    }
    
    // MARK: - 导入方法
    
    /// 后台异步导入词库（带优先级处理）
    /// - Parameters:
    ///   - words: 要导入的单词列表
    ///   - priorityFirst: 是否优先导入前N个单词
    /// - Returns: 导入结果
    @discardableResult
    func importVocabularyAsync(words: [WordJSON], priorityFirst: Bool = true) async -> ImportResult {
        updateStatus(.preparing)
        logger.log("开始导入词库，共 \(words.count) 个单词")
        
        let existingIds = await fetchExistingWordIds()
        let newWords = words.filter { !existingIds.contains(Int32($0.id)) }
        
        logger.log("需要导入新单词: \(newWords.count)，已存在: \(words.count - newWords.count)")
        
        guard !newWords.isEmpty else {
            let result = ImportResult(
                total: words.count,
                imported: 0,
                skipped: words.count,
                errors: []
            )
            updateStatus(.completed(imported: 0, skipped: words.count))
            logger.log("词库已是最新，无需导入")
            return result
        }
        
        var importedCount = 0
        var errors: [ImportError] = []
        let totalCount = newWords.count
        
        do {
            // 优先处理前N个单词（让用户可以立即开始学习）
            if priorityFirst && newWords.count > config.priorityCount {
                let priorityWords = Array(newWords.prefix(config.priorityCount))
                let remainingWords = Array(newWords.suffix(from: config.priorityCount))
                
                logger.log("开始优先导入前 \(config.priorityCount) 个单词")
                
                // 导入优先单词
                (importedCount, errors) = try await importWordsBatch(
                    priorityWords,
                    startCount: importedCount,
                    totalCount: totalCount
                )
                
                // 更新状态为可学习
                updateStatus(.completed(imported: importedCount, skipped: words.count - newWords.count))
                logger.log("优先单词导入完成，用户可以开始学习")
                
                // 后台继续导入剩余单词
                if !remainingWords.isEmpty {
                    logger.log("后台继续导入剩余 \(remainingWords.count) 个单词")
                    importTask = Task {
                        _ = try? await importWordsBatch(
                            remainingWords,
                            startCount: importedCount,
                            totalCount: totalCount
                        )
                    }
                }
            } else {
                // 正常批量导入
                (importedCount, errors) = try await importWordsBatch(
                    newWords,
                    startCount: 0,
                    totalCount: totalCount
                )
                updateStatus(.completed(imported: importedCount, skipped: words.count - newWords.count))
            }
            
            // 最终保存
            try await saveContext()
            
            let result = ImportResult(
                total: words.count,
                imported: importedCount,
                skipped: words.count - newWords.count,
                errors: errors
            )
            
            logger.log("词库导入完成: 成功 \(importedCount)，跳过 \(result.skipped)，错误 \(errors.count)")
            return result
            
        } catch {
            let errorMsg = "导入失败: \(error.localizedDescription)"
            updateStatus(.failed(error: errorMsg))
            logger.log(errorMsg, level: .error)
            
            return ImportResult(
                total: words.count,
                imported: importedCount,
                skipped: words.count - newWords.count,
                errors: errors + [ImportError(batchIndex: -1, wordIds: [], error: error)]
            )
        }
    }
    
    /// 取消导入任务
    func cancelImport() {
        importTask?.cancel()
        importTask = nil
        logger.log("导入任务已取消")
    }
    
    /// 重试导入（用于失败后重试）
    func retryImport(words: [WordJSON]) async -> ImportResult {
        logger.log("用户触发重试导入")
        updateStatus(.idle)
        return await importVocabularyAsync(words: words, priorityFirst: true)
    }
    
    /// 跳过导入
    func skipImport() {
        cancelImport()
        updateStatus(.skipped)
        logger.log("用户跳过导入")
    }
    
    // MARK: - 批量导入内部方法
    
    private func importWordsBatch(
        _ words: [WordJSON],
        startCount: Int,
        totalCount: Int
    ) async throws -> (imported: Int, errors: [ImportError]) {
        var importedCount = startCount
        var errors: [ImportError] = []
        let batchSize = config.batchSize
        
        for batchStart in stride(from: 0, to: words.count, by: batchSize) {
            // 检查取消状态
            if Task.isCancelled {
                logger.log("导入任务被取消")
                break
            }
            
            let batchEnd = min(batchStart + batchSize, words.count)
            let batch = Array(words[batchStart..<batchEnd])
            
            do {
                try await importBatch(batch)
                importedCount += batch.count
                
                let progress = Double(importedCount) / Double(totalCount)
                updateStatus(.importing(
                    progress: progress,
                    imported: importedCount,
                    total: totalCount
                ))
                config.reportProgress(importedCount, totalCount)
                
            } catch {
                errors.append(ImportError(
                    batchIndex: batchStart / batchSize,
                    wordIds: batch.map { $0.id },
                    error: error
                ))
                logger.log("批次 \(batchStart/batchSize) 导入失败: \(error)", level: .error)
            }
            
            // 每处理一定数量保存一次
            if importedCount % config.saveThreshold == 0 {
                try? await saveContext()
            }
        }
        
        return (importedCount, errors)
    }
    
    /// 导入词库（高性能版本）- 兼容旧版本
    func importVocabulary(words: [WordJSON]) async throws -> ImportResult {
        await importVocabularyAsync(words: words, priorityFirst: false)
    }
    
    // MARK: - 状态管理
    
    private func updateStatus(_ newStatus: ImportStatus) {
        DispatchQueue.main.async {
            self.status = newStatus
            self.config.onStatusChange(newStatus)
        }
    }
    
    /// 验证词库数据
    func validateVocabulary(words: [WordJSON]) -> ValidationResult {
        var issues: [ValidationIssue] = []
        var chapterSet = Set<String>()
        var idSet = Set<Int>()
        
        for (index, word) in words.enumerated() {
            // 检查必填字段
            if word.word.isEmpty {
                issues.append(ValidationIssue(
                    index: index,
                    wordId: word.id,
                    field: "word",
                    message: "单词不能为空"
                ))
            }
            
            if word.meaning.isEmpty {
                issues.append(ValidationIssue(
                    index: index,
                    wordId: word.id,
                    field: "meaning",
                    message: "释义不能为空"
                ))
            }
            
            if word.chapter.isEmpty {
                issues.append(ValidationIssue(
                    index: index,
                    wordId: word.id,
                    field: "chapter",
                    message: "章节不能为空"
                ))
            }
            
            // 检查ID重复
            if idSet.contains(word.id) {
                issues.append(ValidationIssue(
                    index: index,
                    wordId: word.id,
                    field: "id",
                    message: "ID重复: \(word.id)"
                ))
            }
            idSet.insert(word.id)
            
            // 收集章节
            chapterSet.insert(word.chapter)
        }
        
        return ValidationResult(
            totalWords: words.count,
            validWords: words.count - issues.count,
            issues: issues,
            chapters: Array(chapterSet).sorted()
        )
    }
    
    // MARK: - 私有方法
    
    private func fetchExistingWordIds() async -> Set<Int32> {
        await context.perform {
            let request = NSFetchRequest<NSDictionary>(entityName: "WordEntity")
            request.resultType = .dictionaryResultType
            request.propertiesToFetch = ["id"]
            
            do {
                let results = try self.context.fetch(request)
                return Set(results.compactMap { $0["id"] as? Int32 })
            } catch {
                print("获取现有单词ID失败: \(error)")
                return Set<Int32>()
            }
        }
    }
    
    private func importBatch(_ words: [WordJSON]) async throws {
        try await context.perform {
            for wordJSON in words {
                let entity = WordEntity(context: self.context)
                entity.populate(from: wordJSON, chapterKey: wordJSON.chapterKey)
            }
        }
    }
    
    private func saveContext() async throws {
        try await context.perform {
            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }
}

// MARK: - 结果类型

struct ImportResult {
    let total: Int
    let imported: Int
    let skipped: Int
    let errors: [ImportError]
    
    var successRate: Double {
        guard imported > 0 else { return 0 }
        let success = imported - errors.count
        return Double(success) / Double(imported)
    }
    
    var isSuccess: Bool {
        errors.isEmpty && imported > 0
    }
}

struct ImportError {
    let batchIndex: Int
    let wordIds: [Int]
    let error: Error
}

struct ValidationResult {
    let totalWords: Int
    let validWords: Int
    let issues: [ValidationIssue]
    let chapters: [String]
    
    var isValid: Bool {
        issues.isEmpty
    }
    
    var validityRate: Double {
        Double(validWords) / Double(totalWords)
    }
}

struct ValidationIssue {
    let index: Int
    let wordId: Int
    let field: String
    let message: String
}

// MARK: - 导入日志记录器

class ImportLogger {
    static let shared = ImportLogger()
    
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
    }
    
    private var logs: [(timestamp: Date, level: LogLevel, message: String)] = []
    private let maxLogs = 500
    
    func log(_ message: String, level: LogLevel = .info) {
        let entry = (Date(), level, message)
        logs.append(entry)
        
        // 限制日志数量
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
        
        // 打印到控制台
        print("[ImportLogger][\(level.rawValue)] \(message)")
    }
    
    /// 获取最近的日志
    func recentLogs(count: Int = 50) -> [String] {
        return logs.suffix(count).map { entry in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return "[\(formatter.string(from: entry.timestamp))][\(entry.level.rawValue)] \(entry.message)"
        }
    }
    
    /// 导出日志用于排查
    func exportLogs() -> String {
        return logs.map { entry in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return "[\(formatter.string(from: entry.timestamp))][\(entry.level.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }
    
    func clear() {
        logs.removeAll()
    }
}

// MARK: - 使用示例

extension VocabularyImporter {
    /// 快速导入词库
    static func quickImport(context: NSManagedObjectContext, jsonData: Data) async throws -> ImportResult {
        let decoder = JSONDecoder()
        let words = try decoder.decode([WordJSON].self, from: jsonData)
        
        let importer = VocabularyImporter(context: context)
        return try await importer.importVocabulary(words: words)
    }
    
    /// 验证并导入（带状态回调）
    static func validateAndImport(
        context: NSManagedObjectContext,
        jsonData: Data,
        onProgress: @escaping (Int, Int) -> Void,
        onStatusChange: @escaping (ImportStatus) -> Void
    ) async throws -> (validation: ValidationResult, importResult: ImportResult) {
        let decoder = JSONDecoder()
        let words = try decoder.decode([WordJSON].self, from: jsonData)
        
        let importer = VocabularyImporter(context: context, config: ImportConfig(
            reportProgress: onProgress,
            onStatusChange: onStatusChange
        ))
        
        // 先验证
        let validation = importer.validateVocabulary(words: words)
        
        // 再导入（使用新的异步方法）
        let result = await importer.importVocabularyAsync(words: words, priorityFirst: true)
        
        return (validation, result)
    }
    
    /// 从Bundle导入词库（用于首次启动）
    static func importFromBundle(
        context: NSManagedObjectContext,
        bundle: Bundle = .main,
        fileName: String = "ielts-vocabulary",
        onStatusChange: @escaping (ImportStatus) -> Void
    ) async -> ImportResult {
        guard let url = bundle.url(forResource: fileName, withExtension: "json") else {
            let error = "找不到词库文件: \(fileName).json"
            onStatusChange(.failed(error: error))
            return ImportResult(total: 0, imported: 0, skipped: 0, errors: [])
        }
        
        do {
            let data = try Data(contentsOf: url)
            let words = try JSONDecoder().decode([WordJSON].self, from: data)
            
            let importer = VocabularyImporter(context: context, config: ImportConfig(
                onStatusChange: onStatusChange
            ))
            
            return await importer.importVocabularyAsync(words: words, priorityFirst: true)
            
        } catch {
            let errorMsg = "读取词库文件失败: \(error.localizedDescription)"
            onStatusChange(.failed(error: errorMsg))
            return ImportResult(total: 0, imported: 0, skipped: 0, errors: [])
        }
    }
}
