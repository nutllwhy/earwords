//
//  EarWordsApp.swift
//  EarWords
//
//  应用入口 - 支持深色模式、小组件与深度链接
//

import SwiftUI
import UserNotifications
import WidgetKit

@main
struct EarWordsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = UserSettingsViewModel.shared
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme ?? settings.colorScheme)
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
        }
    }
    
    // MARK: - 处理深度链接
    private func handleDeepLink(url: URL) {
        guard let host = url.host else { return }
        
        switch host {
        case "study":
            NotificationCenter.default.post(name: .openStudyPage, object: nil)
        case "audio":
            NotificationCenter.default.post(name: .openAudioReviewPage, object: nil)
        case "stats":
            NotificationCenter.default.post(name: .openStatisticsTab, object: nil)
        case "settings":
            NotificationCenter.default.post(name: .openSettingsPage, object: nil)
        default:
            break
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        // 启动时间测量开始
        LaunchTimeProfiler.shared.start()
        
        // 配置通知
        configureNotifications()
        
        // 配置音频会话（延迟初始化避免阻塞）
        DispatchQueue.main.async {
            _ = AudioPlayerManager.shared
        }
        
        // 初始化小组件数据（延迟）
        DispatchQueue.main.async {
            WidgetDataProvider.shared.reloadWidgetData()
        }
        
        // 设置后台刷新
        setupBackgroundRefresh()
        
        // 检查并请求通知权限（如果用户之前已启用）
        checkNotificationPermission()
        
        // 配置内存管理
        setupMemoryManagement()
        
        // 配置音频缓存
        setupAudioCache()
        
        // 记录初始化完成
        LaunchTimeProfiler.shared.record(phase: .initialized)
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // 重置角标
        NotificationManager.shared.resetBadge()
        
        // 更新小组件数据
        WidgetDataProvider.shared.reloadWidgetData()
        
        // 更新通知内容
        NotificationManager.shared.updateDailyReminderContent()
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        print("成功注册远程通知")
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("注册远程通知失败: \(error)")
    }
    
    // MARK: - 后台任务
    
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // 后台刷新小组件数据
        WidgetDataProvider.shared.reloadWidgetData()
        completionHandler(.newData)
    }
    
    // MARK: - 配置
    
    private func configureNotifications() {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
    }
    
    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .authorized {
                DispatchQueue.main.async {
                    // 重新调度提醒
                    let settings = UserSettingsViewModel.shared
                    NotificationManager.shared.scheduleDailyReminder(
                        at: settings.reminderTime,
                        enabled: settings.reminderEnabled
                    )
                }
            }
        }
    }
    
    private func setupBackgroundRefresh() {
        // 每小时自动刷新小组件
        WidgetDataProvider.shared.scheduleBackgroundRefresh()
    }
    
    // MARK: - 性能优化配置
    
    private func setupMemoryManagement() {
        // 注册音频缓存到内存管理器
        MemoryManager.shared.registerCache(
            AudioCacheManager.shared,
            forKey: "audio"
        )
        
        // 配置内存限制
        MemoryManager.shared.audioPlayerMemoryLimitMB = 100
        MemoryManager.shared.imageCacheLimitMB = 50
        MemoryManager.shared.viewCacheLimit = 20
    }
    
    private func setupAudioCache() {
        // 配置音频缓存
        AudioCacheManager.shared.configureCache(
            memoryLimitMB: 50,
            diskLimitMB: 200,
            preloadCount: 3,
            expirationDays: 30
        )
    }
}

// MARK: - 内容视图

struct ContentView: View {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var launchManager = LazyDataManager.shared
    @State private var selectedTab = 0
    @State private var showStudySheet = false
    @State private var showAudioSheet = false
    @State private var showSettingsSheet = false
    
    var body: some View {
        MainTabView(selectedTab: $selectedTab)
            .environmentObject(dataManager)
            .environmentObject(launchManager)
            // 监听标签切换通知
            .onReceive(NotificationCenter.default.publisher(for: .openStudyTab)) { _ in
                selectedTab = 0
            }
            .onReceive(NotificationCenter.default.publisher(for: .openStatisticsTab)) { _ in
                selectedTab = 2
            }
            // 监听小组件和深度链接跳转
            .onReceive(NotificationCenter.default.publisher(for: .openStudyPage)) { _ in
                selectedTab = 0
                showStudySheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openAudioReviewPage)) { _ in
                showAudioSheet = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsPage)) { _ in
                selectedTab = 3
            }
            // 跳转页面 Sheet
            .sheet(isPresented: $showStudySheet) {
                StudyView()
                    .environmentObject(dataManager)
            }
            .sheet(isPresented: $showAudioSheet) {
                AudioReviewView()
                    .environmentObject(dataManager)
            }
            .task {
                // 执行快速启动流程
                await launchManager.performFastLaunch()
            }
    }
}
