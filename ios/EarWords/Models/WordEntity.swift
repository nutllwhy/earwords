//
//  WordEntity.swift
//  EarWords
//
//  Core Data 模型 - 单词实体
//

import Foundation
import CoreData

@objc(WordEntity)
public class WordEntity: NSManagedObject, Identifiable {
    
    // MARK: - 基础字段
    @NSManaged public var id: Int32
    @NSManaged public var word: String
    @NSManaged public var phonetic: String?
    @NSManaged public var pos: String?  // part of speech
    @NSManaged public var meaning: String
    @NSManaged public var example: String?
    @NSManaged public var extra: String?
    
    // MARK: - 分类字段
    @NSManaged public var chapter: String
    @NSManaged public var chapterKey: String
    @NSManaged public var difficulty: Int16  // 1-5 难度等级
    
    // MARK: - 学习状态字段 (SM-2算法)
    @NSManaged public var status: String  // new, learning, mastered
    @NSManaged public var reviewCount: Int16
    @NSManaged public var nextReviewDate: Date?
    @NSManaged public var lastReviewDate: Date?
    @NSManaged public var easeFactor: Double  // 默认 2.5
    @NSManaged public var interval: Int32  // 间隔天数
    
    // MARK: - 音频字段
    @NSManaged public var audioUrl: String?  // 在线音标音频
    @NSManaged public var exampleAudioPath: String?  // 本地例句音频路径
    
    // MARK: - 统计字段
    @NSManaged public var correctCount: Int16
    @NSManaged public var incorrectCount: Int16
    @NSManaged public var streak: Int16  // 连续正确次数
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    
    // MARK: - 计算属性
    
    /// 判断单词是否到期需要复习
    /// - Returns: 如果 `nextReviewDate` 为空或已过当前时间，返回 `true`
    /// - Note: 新单词（nextReviewDate 为 nil）默认视为到期
    var isDue: Bool {
        guard let nextDate = nextReviewDate else { return true }
        return nextDate <= Date()
    }
    
    /// 计算单词的记忆准确率
    /// - Returns: 正确次数占总复习次数的比例，范围 0.0-1.0
    /// - Note: 从未复习过的单词返回 0.0
    var accuracy: Double {
        let total = correctCount + incorrectCount
        return total > 0 ? Double(correctCount) / Double(total) : 0
    }
    
    // MARK: - 便捷方法
    static func fetchRequest() -> NSFetchRequest<WordEntity> {
        return NSFetchRequest<WordEntity>(entityName: "WordEntity")
    }
    
    /// 获取今日待复习单词
    static func dueWordsRequest() -> NSFetchRequest<WordEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(
            format: "nextReviewDate <= %@ OR nextReviewDate == nil",
            Date() as CVarArg
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \WordEntity.nextReviewDate, ascending: true),
            NSSortDescriptor(keyPath: \WordEntity.difficulty, ascending: true)
        ]
        return request
    }
    
    /// 获取新单词（未学习）
    static func newWordsRequest(limit: Int = 20) -> NSFetchRequest<WordEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", "new")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \WordEntity.difficulty, ascending: true),
            NSSortDescriptor(keyPath: \WordEntity.id, ascending: true)
        ]
        request.fetchLimit = limit
        return request
    }
    
    /// 按章节获取单词
    static func wordsInChapter(_ chapterKey: String) -> NSFetchRequest<WordEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "chapterKey == %@", chapterKey)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WordEntity.id, ascending: true)]
        return request
    }
}

// MARK: - 初始化扩展
extension WordEntity {
    func populate(from json: WordJSON, chapterKey: String? = nil) {
        self.id = Int32(json.id)
        self.word = json.word
        self.phonetic = json.phonetic
        self.pos = json.pos
        self.meaning = json.meaning
        self.example = json.example
        self.extra = json.extra
        self.chapter = json.chapter
        self.chapterKey = chapterKey ?? json.chapterKey
        self.difficulty = Int16(json.difficulty)
        self.audioUrl = json.audioUrl
        
        // 初始化学习状态
        self.status = "new"
        self.reviewCount = 0
        self.easeFactor = 2.5
        self.interval = 0
        self.correctCount = 0
        self.incorrectCount = 0
        self.streak = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - JSON 数据模型
struct WordJSON: Codable {
    let id: Int
    let word: String
    let phonetic: String?
    let pos: String?
    let meaning: String
    let example: String?
    let extra: String?
    let chapter: String
    let chapterKey: String
    let difficulty: Int
    let audioUrl: String?
}
