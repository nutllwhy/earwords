//
//  UserSettingsViewModel.swift
//  EarWords
//
//  用户设置 ViewModel - 管理设置状态与持久化
//

import Foundation
import SwiftUI
import Combine

class UserSettingsViewModel: ObservableObject {
    
    // MARK: - 单例
    static let shared = UserSettingsViewModel()
    
    // MARK: - 发布属性
    
    // 每日目标
    @Published var dailyNewWordsGoal: Int = 20 {
        didSet { saveSettings() }
    }
    
    @Published var dailyReviewGoal: Int = 50 {
        didSet { saveSettings() }
    }
    
    // 音频设置
    @Published var audioAutoPlay: Bool = true {
        didSet { saveSettings() }
    }
    
    @Published var showPhonetic: Bool = true {
        didSet { saveSettings() }
    }
    
    @Published var showExample: Bool = true {
        didSet { saveSettings() }
    }
    
    @Published var speechRate: Double = 0.8 {
        didSet { saveSettings() }
    }
    
    // 提醒设置
    @Published var reminderEnabled: Bool = true {
        didSet { 
            updateReminder()
            saveSettings() 
        }
    }
    
    @Published var reminderTime: Date = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())! {
        didSet { 
            updateReminder()
            saveSettings() 
        }
    }
    
    // iCloud 同步
    @Published var iCloudEnabled: Bool = true {
        didSet { saveSettings() }
    }
    
    @Published var syncStatus: SyncStatus = .idle
    
    // 深色模式
    @Published var useSystemAppearance: Bool = true {
        didSet { saveSettings() }
    }
    
    @Published var forceDarkMode: Bool = false {
        didSet { saveSettings() }
    }
    
    // MARK: - 私有属性
    private let dataManager = DataManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var settingsEntity: UserSettingsEntity?
    
    // MARK: - 初始化
    private init() {
        loadSettings()
        setupCloudKitObserver()
    }
    
    // MARK: - 加载设置
    
    private func loadSettings() {
        let context = dataManager.context
        settingsEntity = UserSettingsEntity.defaultSettings(in: context)
        
        guard let settings = settingsEntity else { return }
        
        dailyNewWordsGoal = Int(settings.dailyNewWordsGoal)
        dailyReviewGoal = Int(settings.dailyReviewGoal)
        audioAutoPlay = settings.audioAutoPlay
        showPhonetic = settings.showPhonetic
        showExample = settings.showExample
        speechRate = settings.speechRate
        reminderEnabled = settings.reminderEnabled
        reminderTime = settings.reminderTime ?? Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        iCloudEnabled = settings.iCloudEnabled
    }
    
    // MARK: - 保存设置
    
    private func saveSettings() {
        guard let settings = settingsEntity else { return }
        
        let context = dataManager.context
        
        context.perform { [weak self] in
            guard let self = self else { return }
            
            settings.dailyNewWordsGoal = Int16(self.dailyNewWordsGoal)
            settings.dailyReviewGoal = Int16(self.dailyReviewGoal)
            settings.audioAutoPlay = self.audioAutoPlay
            settings.showPhonetic = self.showPhonetic
            settings.showExample = self.showExample
            settings.speechRate = self.speechRate
            settings.reminderEnabled = self.reminderEnabled
            settings.reminderTime = self.reminderTime
            settings.iCloudEnabled = self.iCloudEnabled
            
            do {
                try context.save()
                
                // 发送设置变更通知
                NotificationCenter.default.post(name: .settingsChanged, object: nil)
                
                // 更新小组件
                WidgetDataProvider.shared.reloadWidgetData()
            } catch {
                print("保存设置失败: \(error)")
            }
        }
    }
    
    // MARK: - 提醒更新
    
    private func updateReminder() {
        NotificationManager.shared.scheduleDailyReminder(
            at: reminderTime,
            enabled: reminderEnabled
        )
    }
    
    // MARK: - CloudKit 同步
    
    private func setupCloudKitObserver() {
        // 监听 CloudKit 同步事件
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
                    return
                }
                
                switch event.type {
                case .setup:
                    self?.syncStatus = .syncing
                case .import:
                    self?.syncStatus = .importing
                case .export:
                    self?.syncStatus = .exporting
                @unknown default:
                    break
                }
                
                if event.endDate != nil {
                    self?.syncStatus = .completed
                    // 延迟恢复 idle 状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self?.syncStatus = .idle
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// 手动触发同步
    func triggerSync() {
        guard iCloudEnabled else {
            syncStatus = .disabled
            return
        }
        
        syncStatus = .syncing
        
        // 触发 CloudKit 同步
        dataManager.persistentContainer.publishCloudKitSynchronization()
    }
    
    /// 获取同步状态描述
    var syncStatusDescription: String {
        switch syncStatus {
        case .idle: return "已同步"
        case .syncing: return "同步中..."
        case .importing: return "下载中..."
        case .exporting: return "上传中..."
        case .completed: return "同步完成"
        case .error: return "同步失败"
        case .disabled: return "iCloud 已禁用"
        }
    }
    
    /// 获取同步状态图标
    var syncStatusIcon: String {
        switch syncStatus {
        case .idle: return "checkmark.icloud"
        case .syncing, .importing, .exporting: return "arrow.clockwise.icloud"
        case .completed: return "checkmark.icloud.fill"
        case .error: return "exclamationmark.icloud"
        case .disabled: return "icloud.slash"
        }
    }
    
    /// 获取当前外观模式
    var colorScheme: ColorScheme? {
        if useSystemAppearance {
            return nil // 使用系统设置
        }
        return forceDarkMode ? .dark : .light
    }
}

// MARK: - 同步状态

enum SyncStatus {
    case idle
    case syncing
    case importing
    case exporting
    case completed
    case error
    case disabled
}

// MARK: - 设置键值（用于 UserDefaults 轻量存储）

extension UserSettingsViewModel {
    enum Keys {
        static let useSystemAppearance = "useSystemAppearance"
        static let forceDarkMode = "forceDarkMode"
    }
}
