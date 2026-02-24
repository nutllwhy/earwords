//
//  WidgetDataProvider.swift
//  EarWords
//
//  小组件数据提供器
//

import Foundation
import WidgetKit
import CoreData

class WidgetDataProvider: ObservableObject {
    
    // MARK: - 单例
    static let shared = WidgetDataProvider()
    
    // MARK: - 数据模型
    struct TodayProgress {
        let studiedCount: Int
        let newWordsGoal: Int
        let reviewCount: Int
        let reviewGoal: Int
        let dueCount: Int
        let streakDays: Int
        
        var newWordsProgress: Double {
            guard newWordsGoal > 0 else { return 0 }
            return min(Double(studiedCount) / Double(newWordsGoal), 1.0)
        }
        
        var reviewProgress: Double {
            guard reviewGoal > 0 else { return 0 }
            return min(Double(reviewCount) / Double(reviewGoal), 1.0)
        }
        
        var overallProgress: Double {
            let totalGoal = newWordsGoal + reviewGoal
            let totalDone = studiedCount + reviewCount
            guard totalGoal > 0 else { return 0 }
            return min(Double(totalDone) / Double(totalGoal), 1.0)
        }
        
        var isGoalCompleted: Bool {
            studiedCount >= newWordsGoal && reviewCount >= reviewGoal
        }
    }
    
    // MARK: - 私有属性
    private let dataManager = DataManager.shared
    
    // MARK: - 初始化
    private init() {
        setupObservers()
    }
    
    // MARK: - 设置观察者
    private func setupObservers() {
        // 监听学习完成通知，自动刷新小组件
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStudyCompleted),
            name: .studySessionCompleted,
            object: nil
        )
        
        // 监听设置变更
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: .settingsChanged,
            object: nil
        )
    }
    
    @objc private func handleStudyCompleted() {
        reloadWidgetData()
    }
    
    @objc private func handleSettingsChanged() {
        reloadWidgetData()
    }
    
    // MARK: - 获取今日进度
    
    func getTodayProgress() -> TodayProgress {
        let context = dataManager.context
        let settings = UserSettingsEntity.defaultSettings(in: context)
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        // 今日新学单词数
        let newWordsRequest = WordEntity.fetchRequest()
        newWordsRequest.predicate = NSPredicate(
            format: "status != %@ AND createdAt >= %@",
            "new",
            startOfDay as CVarArg
        )
        let studiedCount = (try? context.count(for: newWordsRequest)) ?? 0
        
        // 今日复习数
        let reviewRequest = ReviewLogEntity.fetchRequest()
        reviewRequest.predicate = NSPredicate(
            format: "reviewDate >= %@",
            startOfDay as CVarArg
        )
        let reviewCount = (try? context.count(for: reviewRequest)) ?? 0
        
        // 待复习单词数
        let dueCount = dataManager.dueWordsCount
        
        // 连续学习天数
        let streakDays = Int(settings.currentStreak)
        
        return TodayProgress(
            studiedCount: studiedCount,
            newWordsGoal: Int(settings.dailyNewWordsGoal),
            reviewCount: reviewCount,
            reviewGoal: Int(settings.dailyReviewGoal),
            dueCount: dueCount,
            streakDays: streakDays
        )
    }
    
    // MARK: - 获取本周统计
    
    func getWeeklyStats() -> (totalStudied: Int, totalReviews: Int, averageAccuracy: Double) {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        
        let context = dataManager.context
        
        // 本周新学
        let newRequest = WordEntity.fetchRequest()
        newRequest.predicate = NSPredicate(format: "status != %@ AND createdAt >= %@", "new", startOfWeek as CVarArg)
        let totalStudied = (try? context.count(for: newRequest)) ?? 0
        
        // 本周复习
        let reviewRequest = ReviewLogEntity.fetchRequest()
        reviewRequest.predicate = NSPredicate(format: "reviewDate >= %@", startOfWeek as CVarArg)
        let totalReviews = (try? context.count(for: reviewRequest)) ?? 0
        
        // 正确率
        let correctRequest = ReviewLogEntity.fetchRequest()
        correctRequest.predicate = NSPredicate(format: "reviewDate >= %@ AND result == %@", startOfWeek as CVarArg, "correct")
        let correct = (try? context.count(for: correctRequest)) ?? 0
        let averageAccuracy = totalReviews > 0 ? Double(correct) / Double(totalReviews) : 0
        
        return (totalStudied, totalReviews, averageAccuracy)
    }
    
    // MARK: - 刷新小组件
    
    func reloadWidgetData() {
        // 保存数据到共享 UserDefaults（供小组件使用）
        saveWidgetData()
        
        // 触发小组件刷新
        WidgetCenter.shared.reloadTimelines(ofKind: "com.earwords.widget.today")
        WidgetCenter.shared.reloadTimelines(ofKind: "com.earwords.widget.lockscreen")
        WidgetCenter.shared.reloadTimelines(ofKind: "com.earwords.widget.streak")
        
        // 发送数据更新通知
        NotificationCenter.default.post(name: .widgetDataUpdated, object: nil)
    }
    
    // MARK: - 定时刷新（后台任务调用）
    
    func scheduleBackgroundRefresh() {
        // 每小时刷新一次
        let calendar = Calendar.current
        let nextHour = calendar.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + nextHour.timeIntervalSinceNow) { [weak self] in
            self?.reloadWidgetData()
            self?.scheduleBackgroundRefresh()
        }
    }
    
    // MARK: - 保存小组件数据
    
    private func saveWidgetData() {
        let progress = getTodayProgress()
        
        // 使用 App Group 共享数据
        guard let defaults = UserDefaults(suiteName: "group.com.lidengdeng.earwords") else {
            print("[Widget] Failed to access App Group UserDefaults")
            return
        }
        
        defaults.set(progress.studiedCount, forKey: "studiedCount")
        defaults.set(progress.newWordsGoal, forKey: "newWordsGoal")
        defaults.set(progress.reviewCount, forKey: "reviewCount")
        defaults.set(progress.reviewGoal, forKey: "reviewGoal")
        defaults.set(progress.dueCount, forKey: "dueCount")
        defaults.set(progress.streakDays, forKey: "streakDays")
        defaults.set(Date(), forKey: "lastUpdate")
        
        // 保存本周统计
        let weeklyStats = getWeeklyStats()
        defaults.set(weeklyStats.totalStudied, forKey: "weeklyStudied")
        defaults.set(weeklyStats.totalReviews, forKey: "weeklyReviews")
        defaults.set(weeklyStats.averageAccuracy, forKey: "weeklyAccuracy")
        
        defaults.synchronize()
        
        print("[Widget] Data saved: studied=\(progress.studiedCount)/\(progress.newWordsGoal), streak=\(progress.streakDays)")
    }
}

// MARK: - 小组件数据读取辅助方法

struct WidgetDataReader {
    static func read() -> WidgetDataProvider.TodayProgress? {
        guard let defaults = UserDefaults(suiteName: "group.com.lidengdeng.earwords") else {
            return nil
        }
        
        let studiedCount = defaults.integer(forKey: "studiedCount")
        let newWordsGoal = defaults.integer(forKey: "newWordsGoal")
        let reviewCount = defaults.integer(forKey: "reviewCount")
        let reviewGoal = defaults.integer(forKey: "reviewGoal")
        let dueCount = defaults.integer(forKey: "dueCount")
        let streakDays = defaults.integer(forKey: "streakDays")
        
        return WidgetDataProvider.TodayProgress(
            studiedCount: studiedCount,
            newWordsGoal: newWordsGoal,
            reviewCount: reviewCount,
            reviewGoal: reviewGoal,
            dueCount: dueCount,
            streakDays: streakDays
        )
    }
    
    static var lastUpdate: Date? {
        guard let defaults = UserDefaults(suiteName: "group.com.lidengdeng.earwords") else {
            return nil
        }
        return defaults.object(forKey: "lastUpdate") as? Date
    }
    
    static var weeklyStats: (studied: Int, reviews: Int, accuracy: Double)? {
        guard let defaults = UserDefaults(suiteName: "group.com.lidengdeng.earwords") else {
            return nil
        }
        let studied = defaults.integer(forKey: "weeklyStudied")
        let reviews = defaults.integer(forKey: "weeklyReviews")
        let accuracy = defaults.double(forKey: "weeklyAccuracy")
        return (studied, reviews, accuracy)
    }
}

// MARK: - 通知名称扩展

extension Notification.Name {
    static let studySessionCompleted = Notification.Name("studySessionCompleted")
}
