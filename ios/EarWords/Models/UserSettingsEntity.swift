//
//  UserSettingsEntity.swift
//  EarWords
//
//  Core Data 模型 - 用户设置实体
//

import Foundation
import CoreData

@objc(UserSettingsEntity)
public class UserSettingsEntity: NSManagedObject {
    
    // 每日学习目标
    @NSManaged public var dailyNewWordsGoal: Int16  // 默认 20
    @NSManaged public var dailyReviewGoal: Int16    // 默认 50
    
    // 学习偏好
    @NSManaged public var audioAutoPlay: Bool       // 自动播放音频
    @NSManaged public var showPhonetic: Bool        // 显示音标
    @NSManaged public var showExample: Bool         // 显示例句
    @NSManaged public var darkMode: Bool
    
    // 提醒设置
    @NSManaged public var reminderEnabled: Bool
    @NSManaged public var reminderTime: Date?       // 每日提醒时间
    
    // 音频设置
    @NSManaged public var speechRate: Double        // 0.5 - 1.0
    @NSManaged public var preferredVoice: String?   // 首选语音
    
    // 统计数据
    @NSManaged public var totalStudyDays: Int32
    @NSManaged public var currentStreak: Int32      // 连续学习天数
    @NSManaged public var longestStreak: Int32
    @NSManaged public var lastStudyDate: Date?
    
    // 同步时间戳
    @NSManaged public var lastSyncDate: Date?
    @NSManaged public var iCloudEnabled: Bool
    
    static func fetchRequest() -> NSFetchRequest<UserSettingsEntity> {
        return NSFetchRequest<UserSettingsEntity>(entityName: "UserSettingsEntity")
    }
    
    /// 获取或创建设置
    static func defaultSettings(in context: NSManagedObjectContext) -> UserSettingsEntity {
        let request = fetchRequest()
        request.fetchLimit = 1
        
        if let existing = try? context.fetch(request).first {
            return existing
        }
        
        let settings = UserSettingsEntity(context: context)
        settings.dailyNewWordsGoal = 20
        settings.dailyReviewGoal = 50
        settings.audioAutoPlay = true
        settings.showPhonetic = true
        settings.showExample = true
        settings.darkMode = false
        settings.reminderEnabled = true
        settings.speechRate = 0.8
        settings.totalStudyDays = 0
        settings.currentStreak = 0
        settings.longestStreak = 0
        settings.iCloudEnabled = true
        
        try? context.save()
        return settings
    }
}
