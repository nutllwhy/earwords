//
//  VocabularyImporter.swift
//  EarWords
//
//  词库导入工具 - 专门处理大批量数据导入
//

import Foundation
import CoreData

/// 词库导入工具类
class VocabularyImporter {
    
    // MARK: - 配置
    
    struct ImportConfig {
        var batchSize: Int = 200
        var saveThreshold: Int = 1000
        var reportProgress: (Int, Int) -> Void = { _, _ in }
    }
    
    // MARK: - 属性
    
    private let context: NSManagedObjectContext
    private var config: ImportConfig
    
    init(context: NSManagedObjectContext, config: ImportConfig = ImportConfig()) {
        self.context = context
        self.config = config
    }
    
    // MARK: - 导入方法
    
    /// 导入词库（高性能版本）
    func importVocabulary(words: [WordJSON]) async throws -> ImportResult {
        let existingIds = await fetchExistingWordIds()
        let newWords = words.filter { !existingIds.contains(Int32($0.id)) }
        
        guard !newWords.isEmpty else {
            return ImportResult(
                total: words.count,
                imported: 0,
                skipped: words.count,
                errors: []
            )
        }
        
        var importedCount = 0
        var errors: [ImportError] = []
        let batchSize = config.batchSize
        
        // 批量处理
        for batchStart in stride(from: 0, to: newWords.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, newWords.count)
            let batch = Array(newWords[batchStart..<batchEnd])
            
            do {
                try await importBatch(batch)
                importedCount += batch.count
                config.reportProgress(importedCount, newWords.count)
            } catch {
                errors.append(ImportError(
                    batchIndex: batchStart / batchSize,
                    wordIds: batch.map { $0.id },
                    error: error
                ))
            }
            
            // 每处理一定数量保存一次
            if importedCount % config.saveThreshold == 0 {
                try? await saveContext()
            }
        }
        
        // 最终保存
        try await saveContext()
        
        return ImportResult(
            total: words.count,
            imported: importedCount,
            skipped: words.count - newWords.count,
            errors: errors
        )
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

// MARK: - 使用示例

extension VocabularyImporter {
    /// 快速导入词库
    static func quickImport(context: NSManagedObjectContext, jsonData: Data) async throws -> ImportResult {
        let decoder = JSONDecoder()
        let words = try decoder.decode([WordJSON].self, from: jsonData)
        
        let importer = VocabularyImporter(context: context)
        return try await importer.importVocabulary(words: words)
    }
    
    /// 验证并导入
    static func validateAndImport(
        context: NSManagedObjectContext,
        jsonData: Data,
        onProgress: @escaping (Int, Int) -> Void
    ) async throws -> (validation: ValidationResult, importResult: ImportResult) {
        let decoder = JSONDecoder()
        let words = try decoder.decode([WordJSON].self, from: jsonData)
        
        let importer = VocabularyImporter(context: context, config: ImportConfig(
            reportProgress: onProgress
        ))
        
        // 先验证
        let validation = importer.validateVocabulary(words: words)
        
        // 再导入
        let result = try await importer.importVocabulary(words: words)
        
        return (validation, result)
    }
}
