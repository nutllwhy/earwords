//
//  MemoryManager.swift
//  EarWords
//
//  内存管理器 - 内存警告处理 + 缓存限制 + 性能监控
//  管理音频播放器、图片/视图缓存的内存上限
//

import Foundation
import SwiftUI
import Combine

// MARK: - 内存状态

/// 应用内存状态
enum MemoryStatus {
    case normal       // 正常
    case warning      // 警告（需要清理）
    case critical     // 严重（必须立即清理）
    
    var shouldCleanup: Bool {
        self != .normal
    }
    
    var shouldAggressiveCleanup: Bool {
        self == .critical
    }
}

// MARK: - 内存使用统计

/// 内存使用统计
struct MemoryUsage {
    let usedMB: Double
    let availableMB: Double
    let totalMB: Double
    let usagePercentage: Double
    
    var status: MemoryStatus {
        switch usagePercentage {
        case 0..0.7:
            return .normal
        case 0.7..0.85:
            return .warning
        default:
            return .critical
        }
    }
    
    var description: String {
        return "内存使用: \(String(format: "%.1f", usedMB))MB / \(String(format: "%.1f", totalMB))MB (\(String(format: "%.1f", usagePercentage * 100))%)"
    }
}

// MARK: - 内存管理器

@MainActor
class MemoryManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = MemoryManager()
    
    // MARK: - 发布属性
    @Published var currentUsage: MemoryUsage?
    @Published var memoryStatus: MemoryStatus = .normal
    @Published var lastCleanupTime: Date?
    @Published var cleanupCount: Int = 0
    
    // MARK: - 内存限制配置
    
    /// 音频播放器内存上限（MB）
    var audioPlayerMemoryLimitMB: Double = 100 {
        didSet { updateLimits() }
    }
    
    /// 图片缓存内存上限（MB）
    var imageCacheLimitMB: Double = 50 {
        didSet { updateLimits() }
    }
    
    /// 视图缓存限制（视图数量）
    var viewCacheLimit: Int = 20 {
        didSet { updateLimits() }
    }
    
    /// Core Data 缓存上限（MB）
    var coreDataCacheLimitMB: Double = 80 {
        didSet { updateLimits() }
    }
    
    /// 总内存限制（MB）
    var totalMemoryLimitMB: Double = 300
    
    // MARK: - 私有属性
    
    /// 内存监控定时器
    private var monitorTimer: Timer?
    
    /// 内存警告通知观察者
    private var memoryWarningObserver: NSObjectProtocol?
    
    /// 应用进入后台通知观察者
    private var backgroundObserver: NSObjectProtocol?
    
    /// 取消订阅集合
    private var cancellables = Set<AnyCancellable>()
    
    /// 缓存引用
    private var registeredCaches: [String: MemoryCacheable] = [:]
    private let cacheLock = NSLock()
    
    /// 内存使用历史
    private var usageHistory: [MemoryUsage] = []
    private let historyLimit = 100
    
    // MARK: - 初始化
    
    private init() {
        setupNotifications()
        startMonitoring()
        updateCurrentMemoryUsage()
    }
    
    deinit {
        monitorTimer?.invalidate()
        
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - 设置
    
    private func setupNotifications() {
        // 内存警告通知
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        
        // 进入后台通知
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleEnterBackground()
        }
        
        // 进入前台通知
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleEnterForeground()
        }
    }
    
    /// 开始内存监控
    private func startMonitoring() {
        // 每5秒检查一次内存状态
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentMemoryUsage()
            }
        }
    }
    
    // MARK: - 内存使用获取
    
    /// 更新当前内存使用情况
    private func updateCurrentMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        currentUsage = usage
        
        // 更新状态
        let newStatus = usage.status
        if newStatus != memoryStatus {
            memoryStatus = newStatus
            handleMemoryStatusChange(newStatus)
        }
        
        // 记录历史
        usageHistory.append(usage)
        if usageHistory.count > historyLimit {
            usageHistory.removeFirst()
        }
    }
    
    /// 获取当前内存使用情况
    private func getCurrentMemoryUsage() -> MemoryUsage {
        // 获取物理内存信息
        let physicalMemory = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
        
        // 获取应用内存使用（resident_size）
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        let usedMB: Double
        if kerr == KERN_SUCCESS {
            usedMB = Double(info.resident_size) / 1024.0 / 1024.0
        } else {
            // 备用方案
            usedMB = 0
        }
        
        let availableMB = physicalMemory - usedMB
        let usagePercentage = usedMB / physicalMemory
        
        return MemoryUsage(
            usedMB: usedMB,
            availableMB: availableMB,
            totalMB: physicalMemory,
            usagePercentage: usagePercentage
        )
    }
    
    // MARK: - 内存状态处理
    
    /// 处理内存状态变化
    private func handleMemoryStatusChange(_ status: MemoryStatus) {
        switch status {
        case .normal:
            break
        case .warning:
            print("⚠️ 内存警告: 使用率超过70%")
            performCleanup(aggressive: false)
        case .critical:
            print("🚨 内存严重警告: 使用率超过85%")
            performCleanup(aggressive: true)
        }
    }
    
    /// 处理内存警告
    private func handleMemoryWarning() {
        print("⚠️ 收到系统内存警告")
        memoryStatus = .warning
        performCleanup(aggressive: true)
        
        // 通知所有缓存
        notifyCachesOfMemoryWarning()
    }
    
    /// 处理进入后台
    private func handleEnterBackground() {
        print("📱 应用进入后台，执行内存清理")
        performCleanup(aggressive: false)
    }
    
    /// 处理进入前台
    private func handleEnterForeground() {
        print("📱 应用进入前台，恢复监控")
        updateCurrentMemoryUsage()
    }
    
    // MARK: - 缓存注册
    
    /// 注册缓存
    func registerCache(_ cache: MemoryCacheable, forKey key: String) {
        cacheLock.lock()
        registeredCaches[key] = cache
        cacheLock.unlock()
    }
    
    /// 注销缓存
    func unregisterCache(forKey key: String) {
        cacheLock.lock()
        registeredCaches.removeValue(forKey: key)
        cacheLock.unlock()
    }
    
    /// 获取缓存
    func getCache(forKey key: String) -> MemoryCacheable? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return registeredCaches[key]
    }
    
    /// 通知所有缓存内存警告
    private func notifyCachesOfMemoryWarning() {
        cacheLock.lock()
        let caches = Array(registeredCaches.values)
        cacheLock.unlock()
        
        for cache in caches {
            cache.handleMemoryWarning()
        }
    }
    
    // MARK: - 内存清理
    
    /// 执行内存清理
    func performCleanup(aggressive: Bool = false) {
        let startTime = Date()
        let beforeUsage = currentUsage?.usedMB ?? 0
        
        print("🧹 开始内存清理 (激进模式: \(aggressive))")
        
        // 1. 清理音频缓存
        AudioCacheManager.shared.trimCache(aggressive: aggressive)
        
        // 2. 通知所有注册缓存清理
        notifyCachesOfCleanup(aggressive: aggressive)
        
        // 3. Core Data 清理
        performCoreDataCleanup(aggressive: aggressive)
        
        // 4. URLCache 清理
        if aggressive {
            URLCache.shared.removeAllCachedResponses()
        } else {
            URLCache.shared.removeExpiredCachedResponses()
        }
        
        // 更新统计
        updateCurrentMemoryUsage()
        cleanupCount += 1
        lastCleanupTime = Date()
        
        let afterUsage = currentUsage?.usedMB ?? 0
        let freedMemory = max(0, beforeUsage - afterUsage)
        let cleanupTime = Date().timeIntervalSince(startTime)
        
        print("✅ 内存清理完成: 释放 \(String(format: "%.2f", freedMemory))MB, 耗时 \(String(format: "%.3f", cleanupTime))s")
    }
    
    /// 通知缓存清理
    private func notifyCachesOfCleanup(aggressive: Bool) {
        cacheLock.lock()
        let caches = Array(registeredCaches.values)
        cacheLock.unlock()
        
        for cache in caches {
            cache.trimCache(aggressive: aggressive)
        }
    }
    
    /// Core Data 清理
    private func performCoreDataCleanup(aggressive: Bool) {
        let context = DataManager.shared.context
        
        // 重置上下文以释放内存
        if aggressive {
            context.reset()
            print("🗑️ Core Data 上下文已重置")
        }
        
        // 尝试减少 Core Data 缓存
        let persistentStoreCoordinator = context.persistentStoreCoordinator
        if let stores = persistentStoreCoordinator?.persistentStores {
            for store in stores {
                do {
                    try persistentStoreCoordinator?.managedObjectID(for: store.url!)
                } catch {
                    // 忽略错误
                }
            }
        }
    }
    
    // MARK: - 缓存限制更新
    
    private func updateLimits() {
        // 更新已注册缓存的限制
        if let audioCache = getCache(forKey: "audio") as? AudioCacheMemoryControllable {
            audioCache.setMemoryLimit(MB: audioPlayerMemoryLimitMB)
        }
        
        if let imageCache = getCache(forKey: "image") as? ImageCacheMemoryControllable {
            imageCache.setMemoryLimit(MB: imageCacheLimitMB)
        }
    }
    
    // MARK: - 内存报告
    
    /// 获取内存使用报告
    func getMemoryReport() -> MemoryReport {
        let current = currentUsage
        let avgUsage = usageHistory.isEmpty ? 0 : usageHistory.map { $0.usedMB }.reduce(0, +) / Double(usageHistory.count)
        let peakUsage = usageHistory.map { $0.usedMB }.max() ?? 0
        
        return MemoryReport(
            currentUsage: current,
            averageUsage: avgUsage,
            peakUsage: peakUsage,
            cleanupCount: cleanupCount,
            lastCleanupTime: lastCleanupTime,
            status: memoryStatus,
            history: usageHistory
        )
    }
    
    /// 打印内存报告
    func printMemoryReport() {
        let report = getMemoryReport()
        
        print("\n=== 内存使用报告 ===")
        print(report.currentUsage?.description ?? "无法获取内存信息")
        print("平均使用: \(String(format: "%.1f", report.averageUsage))MB")
        print("峰值使用: \(String(format: "%.1f", report.peakUsage))MB")
        print("清理次数: \(report.cleanupCount)")
        if let lastCleanup = report.lastCleanupTime {
            print("上次清理: \(lastCleanup.timeAgoString())")
        }
        print("内存状态: \(report.status)")
        print("已注册缓存: \(registeredCaches.keys.joined(separator: ", "))")
        print("=".repeat(40) + "\n")
    }
}

// MARK: - 内存缓存协议

/// 内存缓存协议
protocol MemoryCacheable: AnyObject {
    /// 处理内存警告
    func handleMemoryWarning()
    
    /// 裁剪缓存
    func trimCache(aggressive: Bool)
    
    /// 获取当前缓存大小（MB）
    func currentCacheSizeMB() -> Double
}

/// 音频缓存内存控制协议
protocol AudioCacheMemoryControllable: MemoryCacheable {
    func setMemoryLimit(MB: Double)
}

/// 图片缓存内存控制协议
protocol ImageCacheMemoryControllable: MemoryCacheable {
    func setMemoryLimit(MB: Double)
}

// MARK: - 音频缓存管理器扩展

extension AudioCacheManager {
    
    /// 裁剪缓存
    func trimCache(aggressive: Bool) {
        let targetRatio = aggressive ? 0.3 : 0.5
        let targetSize = Int(Double(memoryCacheSize) * targetRatio)
        
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        let sortedItems = memoryCache.sorted { $0.value.weight > $1.value.weight }
        var currentSize = memoryCacheSize
        
        for (key, item) in sortedItems {
            guard currentSize > targetSize else { break }
            memoryCache.removeValue(forKey: key)
            currentSize -= item.size
        }
        
        updateCacheMetrics()
    }
}

// MARK: - 内存报告

struct MemoryReport {
    let currentUsage: MemoryUsage?
    let averageUsage: Double
    let peakUsage: Double
    let cleanupCount: Int
    let lastCleanupTime: Date?
    let status: MemoryStatus
    let history: [MemoryUsage]
}

// MARK: - 日期扩展

private extension Date {
    func timeAgoString() -> String {
        let interval = Date().timeIntervalSince(self)
        
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时前"
        } else {
            return "\(Int(interval / 86400))天前"
        }
    }
}

// MARK: - String 扩展

private extension String {
    func repeat(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

// MARK: - 视图内存优化修饰符

extension View {
    
    /// 内存优化修饰符
    /// 在视图不可见时释放内存
    func memoryOptimized() -> some View {
        self.onDisappear {
            // 视图消失时触发轻微内存清理
            if MemoryManager.shared.memoryStatus == .warning {
                MemoryManager.shared.performCleanup(aggressive: false)
            }
        }
    }
}
