//
//  NotificationManager.swift
//  EarWords
//
//  本地通知管理器 - 学习提醒
//

import Foundation
import UserNotifications
import UIKit
import CoreData

class NotificationManager: NSObject, ObservableObject {
    
    // MARK: - 单例
    static let shared = NotificationManager()
    
    // MARK: - 发布属性
    @Published var isAuthorized = false
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    // MARK: - 常量
    private let notificationCenter = UNUserNotificationCenter.current()
    private let dailyReminderIdentifier = "com.earwords.dailyReminder"
    
    // MARK: - 初始化
    private override init() {
        super.init()
        notificationCenter.delegate = self
        checkAuthorizationStatus()
    }
    
    // MARK: - 权限管理
    
    /// 请求通知权限
    func requestAuthorization() async -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await notificationCenter.requestAuthorization(options: options)
            
            await MainActor.run {
                self.isAuthorized = granted
            }
            
            if granted {
                // 注册远程通知（用于 CloudKit 同步推送）
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            
            return granted
        } catch {
            print("请求通知权限失败: \(error)")
            return false
        }
    }
    
    /// 检查授权状态
    func checkAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - 学习提醒
    
    /// 设置每日学习提醒
    func scheduleDailyReminder(at time: Date, enabled: Bool) {
        // 移除现有提醒
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
        
        guard enabled else {
            print("学习提醒已禁用")
            return
        }
        
        // 获取待学单词数量
        let dueCount = getTodayDueWordsCount()
        let newCount = getTodayNewWordsCount()
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = "📚 今日单词学习"
        
        if dueCount > 0 || newCount > 0 {
            content.body = "今天还有 \(dueCount) 个单词待复习，\(newCount) 个新单词待学习。开始学习吧！"
        } else {
            content.body = "今天已完成所有学习任务！继续保持 💪"
        }
        
        content.sound = .default
        content.badge = NSNumber(value: dueCount + newCount)
        
        // 设置点击动作
        content.userInfo = [
            "type": "dailyReminder",
            "dueCount": dueCount,
            "newCount": newCount
        ]
        
        // 设置触发时间（每天）
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        
        // 创建请求
        let request = UNNotificationRequest(
            identifier: dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )
        
        // 添加通知
        notificationCenter.add(request) { error in
            if let error = error {
                print("设置学习提醒失败: \(error)")
            } else {
                print("学习提醒已设置: \(components.hour ?? 0):\(components.minute ?? 0)")
            }
        }
    }
    
    /// 更新提醒内容（根据最新学习进度）
    func updateDailyReminderContent() {
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self = self,
                  let reminderRequest = requests.first(where: { $0.identifier == self.dailyReminderIdentifier }),
                  let trigger = reminderRequest.trigger as? UNCalendarNotificationTrigger else {
                return
            }
            
            // 获取当前时间组件
            let calendar = Calendar.current
            let dateComponents = trigger.dateComponents
            
            // 重新计算今天的待学数量
            let dueCount = self.getTodayDueWordsCount()
            let newCount = self.getTodayNewWordsCount()
            
            // 只更新内容，保持时间不变
            let content = UNMutableNotificationContent()
            content.title = "📚 今日单词学习"
            
            if dueCount > 0 || newCount > 0 {
                content.body = "今天还有 \(dueCount) 个单词待复习，\(newCount) 个新单词待学习。开始学习吧！"
            } else {
                content.body = "今天已完成所有学习任务！继续保持 💪"
            }
            
            content.sound = .default
            content.badge = NSNumber(value: dueCount + newCount)
            content.userInfo = [
                "type": "dailyReminder",
                "dueCount": dueCount,
                "newCount": newCount
            ]
            
            let newRequest = UNNotificationRequest(
                identifier: self.dailyReminderIdentifier,
                content: content,
                trigger: trigger
            )
            
            self.notificationCenter.add(newRequest)
        }
    }
    
    /// 移除每日提醒
    func removeDailyReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
    }
    
    // MARK: - 即时通知
    
    /// 发送学习完成通知
    func sendStudyCompletionNotification(studiedCount: Int, masteredCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🎉 学习完成！"
        content.body = "恭喜！今天学习了 \(studiedCount) 个单词，掌握了 \(masteredCount) 个新词。"
        content.sound = .default
        content.userInfo = ["type": "studyCompletion"]
        
        let request = UNNotificationRequest(
            identifier: "studyCompletion_\(UUID().uuidString)",
            content: content,
            trigger: nil // 立即发送
        )
        
        notificationCenter.add(request)
    }
    
    /// 发送连续学习 streak 通知
    func sendStreakNotification(streakDays: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🔥 连续学习 \(streakDays) 天！"
        content.body = "太棒了！你已经连续学习 \(streakDays) 天，继续保持这个好习惯！"
        content.sound = .default
        content.userInfo = ["type": "streak", "days": streakDays]
        
        let request = UNNotificationRequest(
            identifier: "streak_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - 获取待学数量
    
    private func getTodayDueWordsCount() -> Int {
        let context = DataManager.shared.context
        let request = WordEntity.dueWordsRequest()
        
        do {
            return try context.count(for: request)
        } catch {
            return 0
        }
    }
    
    private func getTodayNewWordsCount() -> Int {
        let settings = UserSettingsEntity.defaultSettings(in: DataManager.shared.context)
        let goal = settings.dailyNewWordsGoal
        
        let context = DataManager.shared.context
        let request = WordEntity.newWordsRequest(limit: Int(goal))
        
        do {
            let available = try context.count(for: request)
            return min(Int(goal), available)
        } catch {
            return 0
        }
    }
    
    // MARK: - 通知管理
    
    /// 获取所有待发送的通知
    func fetchPendingNotifications() async {
        let requests = await notificationCenter.pendingNotificationRequests()
        await MainActor.run {
            self.pendingNotifications = requests
        }
    }
    
    /// 清除所有通知
    func clearAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    /// 重置角标
    func resetBadge() {
        notificationCenter.setBadgeCount(0)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    /// 应用在前台时收到通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 允许在前台显示通知
        completionHandler([.banner, .sound, .badge])
    }
    
    /// 用户点击通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // 处理不同类型的通知
        if let type = userInfo["type"] as? String {
            switch type {
            case "dailyReminder":
                // 打开应用并导航到学习页面
                NotificationCenter.default.post(name: .openStudyTab, object: nil)
                
            case "studyCompletion":
                // 打开统计页面
                NotificationCenter.default.post(name: .openStatisticsTab, object: nil)
                
            case "streak":
                // 打开统计页面显示连续学习记录
                NotificationCenter.default.post(name: .openStatisticsTab, object: nil)
                
            default:
                break
            }
        }
        
        // 重置角标
        resetBadge()
        
        completionHandler()
    }
}

// MARK: - 通知名称扩展

extension Notification.Name {
    static let openStudyTab = Notification.Name("com.earwords.openStudyTab")
    static let openStatisticsTab = Notification.Name("com.earwords.openStatisticsTab")
    static let settingsChanged = Notification.Name("com.earwords.settingsChanged")
}
