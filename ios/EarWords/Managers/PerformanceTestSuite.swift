//
//  PerformanceTestSuite.swift
//  EarWords
//
//  性能测试套件 - 启动时间 + 内存监控 + 流畅度 + 电池消耗
//

import Foundation
import SwiftUI
import Combine
import QuartzCore

// MARK: - 性能测试类型

enum PerformanceTestType {
    case launchTime       // 启动时间
    case memoryUsage      // 内存占用
    case frameRate        // 帧率/FPS
    case batteryUsage     // 电池消耗
    case databaseQuery    // 数据库查询
    case audioPlayback    // 音频播放
    
    var displayName: String {
        switch self {
        case .launchTime: return "启动时间"
        case .memoryUsage: return "内存占用"
        case .frameRate: return "流畅度(FPS)"
        case .batteryUsage: return "电池消耗"
        case .databaseQuery: return "数据库查询"
        case .audioPlayback: return "音频播放"
        }
    }
    
    var icon: String {
        switch self {
        case .launchTime: return "timer"
        case .memoryUsage: return "memorychip"
        case .frameRate: return "bolt"
        case .batteryUsage: return "battery.100"
        case .databaseQuery: return "externaldrive"
        case .audioPlayback: return "speaker.wave.3"
        }
    }
}

// MARK: - 性能测试结果

struct PerformanceTestResult: Identifiable {
    let id = UUID()
    let testType: PerformanceTestType
    let timestamp: Date
    let value: Double
    let unit: String
    let status: TestStatus
    let details: [String: Any]
    let duration: TimeInterval
    
    enum TestStatus: String {
        case pass = "通过"
        case warning = "警告"
        case fail = "失败"
        
        var color: Color {
            switch self {
            case .pass: return .green
            case .warning: return .orange
            case .fail: return .red
            }
        }
    }
}

// MARK: - FPS 监控器

/// FPS 监控器
class FPSMonitor: ObservableObject {
    
    static let shared = FPSMonitor()
    
    @Published var currentFPS: Double = 60.0
    @Published var averageFPS: Double = 60.0
    @Published var minFPS: Double = 60.0
    @Published var droppedFrames: Int = 0
    @Published var isMonitoring: Bool = false
    
    private var displayLink: CADisplayLink?
    private var lastTimestamp: TimeInterval = 0
    private var frameCount: Int = 0
    private var totalFrameTime: TimeInterval = 0
    private var fpsHistory: [Double] = []
    private let historyLimit = 60
    
    private init() {}
    
    /// 开始监控
    func startMonitoring() {
        guard displayLink == nil else { return }
        
        isMonitoring = true
        lastTimestamp = 0
        frameCount = 0
        totalFrameTime = 0
        fpsHistory.removeAll()
        minFPS = 60.0
        droppedFrames = 0
        
        displayLink = CADisplayLink(target: self, selector: #selector(handleFrame))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    /// 停止监控
    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        isMonitoring = false
    }
    
    @objc private func handleFrame(displayLink: CADisplayLink) {
        guard lastTimestamp > 0 else {
            lastTimestamp = displayLink.timestamp
            return
        }
        
        let frameTime = displayLink.timestamp - lastTimestamp
        lastTimestamp = displayLink.timestamp
        
        // 计算FPS
        let fps = 1.0 / frameTime
        currentFPS = fps
        
        // 记录历史
        fpsHistory.append(fps)
        if fpsHistory.count > historyLimit {
            fpsHistory.removeFirst()
        }
        
        // 更新统计
        averageFPS = fpsHistory.reduce(0, +) / Double(fpsHistory.count)
        minFPS = min(minFPS, fps)
        
        // 检测掉帧（低于55fps）
        if fps < 55 {
            droppedFrames += 1
        }
        
        frameCount += 1
        totalFrameTime += frameTime
    }
    
    /// 获取FPS报告
    func getReport() -> FPSReport {
        return FPSReport(
            averageFPS: averageFPS,
            minFPS: minFPS,
            droppedFrames: droppedFrames,
            totalFrames: frameCount,
            frameTimeVariance: calculateFrameTimeVariance()
        )
    }
    
    /// 计算帧时间方差
    private func calculateFrameTimeVariance() -> Double {
        guard fpsHistory.count > 1 else { return 0 }
        
        let mean = fpsHistory.reduce(0, +) / Double(fpsHistory.count)
        let variance = fpsHistory.map { pow($0 - mean, 2) }.reduce(0, +) / Double(fpsHistory.count - 1)
        return sqrt(variance)
    }
}

// MARK: - FPS 报告

struct FPSReport {
    let averageFPS: Double
    let minFPS: Double
    let droppedFrames: Int
    let totalFrames: Int
    let frameTimeVariance: Double
    
    var status: PerformanceTestResult.TestStatus {
        if averageFPS >= 55 {
            return .pass
        } else if averageFPS >= 45 {
            return .warning
        } else {
            return .fail
        }
    }
    
    var description: String {
        return "平均FPS: \(String(format: "%.1f", averageFPS))" +
               ", 最低FPS: \(String(format: "%.1f", minFPS))" +
               ", 掉帧: \(droppedFrames)"
    }
}

// MARK: - 电池消耗监控器

/// 电池消耗监控器
class BatteryMonitor: ObservableObject {
    
    static let shared = BatteryMonitor()
    
    @Published var batteryLevel: Float = 1.0
    @Published var batteryState: UIDevice.BatteryState = .unknown
    @Published var isMonitoring: Bool = false
    
    private var startLevel: Float = 1.0
    private var startTime: Date?
    
    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBatteryInfo()
    }
    
    /// 开始监控
    func startMonitoring() {
        startLevel = UIDevice.current.batteryLevel
        startTime = Date()
        isMonitoring = true
        updateBatteryInfo()
    }
    
    /// 停止监控
    func stopMonitoring() -> BatteryReport? {
        guard let startTime = startTime else { return nil }
        
        let endLevel = UIDevice.current.batteryLevel
        let duration = Date().timeIntervalSince(startTime)
        let consumption = max(0, startLevel - endLevel)
        
        isMonitoring = false
        
        return BatteryReport(
            startLevel: startLevel,
            endLevel: endLevel,
            consumption: consumption,
            duration: duration,
            consumptionPerHour: consumption / Float(duration / 3600)
        )
    }
    
    private func updateBatteryInfo() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
    }
}

// MARK: - 电池报告

struct BatteryReport {
    let startLevel: Float
    let endLevel: Float
    let consumption: Float
    let duration: TimeInterval
    let consumptionPerHour: Float
    
    var status: PerformanceTestResult.TestStatus {
        // 每小时消耗超过10%为警告，超过20%为失败
        if consumptionPerHour < 0.1 {
            return .pass
        } else if consumptionPerHour < 0.2 {
            return .warning
        } else {
            return .fail
        }
    }
}

// MARK: - 性能测试套件

@MainActor
class PerformanceTestSuite: ObservableObject {
    
    static let shared = PerformanceTestSuite()
    
    // MARK: - 发布属性
    @Published var testResults: [PerformanceTestResult] = []
    @Published var isRunning: Bool = false
    @Published var currentTest: PerformanceTestType?
    @Published var progress: Double = 0
    
    // MARK: - 测试配置
    
    /// 启动时间测试配置
    struct LaunchTimeConfig {
        var iterations: Int = 5
        var targetTime: TimeInterval = 1.5 // 目标启动时间
    }
    
    /// FPS 测试配置
    struct FPSConfig {
        var testDuration: TimeInterval = 30 // 测试30秒
        var minAcceptableFPS: Double = 55
    }
    
    /// 电池测试配置
    struct BatteryConfig {
        var testDuration: TimeInterval = 300 // 测试5分钟
    }
    
    var launchTimeConfig = LaunchTimeConfig()
    var fpsConfig = FPSConfig()
    var batteryConfig = BatteryConfig()
    
    // MARK: - 初始化
    
    private init() {}
    
    // MARK: - 运行所有测试
    
    /// 运行完整测试套件
    func runAllTests() async {
        guard !isRunning else { return }
        
        isRunning = true
        testResults.removeAll()
        progress = 0
        
        let tests: [PerformanceTestType] = [
            .launchTime,
            .memoryUsage,
            .frameRate,
            .databaseQuery,
            .audioPlayback,
            .batteryUsage
        ]
        
        for (index, test) in tests.enumerated() {
            currentTest = test
            progress = Double(index) / Double(tests.count)
            
            let result = await runTest(test)
            testResults.append(result)
            
            // 测试间隔
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        }
        
        currentTest = nil
        progress = 1.0
        isRunning = false
        
        // 打印报告
        printTestReport()
    }
    
    /// 运行单个测试
    private func runTest(_ type: PerformanceTestType) async -> PerformanceTestResult {
        let startTime = Date()
        
        switch type {
        case .launchTime:
            return await testLaunchTime(startTime: startTime)
        case .memoryUsage:
            return await testMemoryUsage(startTime: startTime)
        case .frameRate:
            return await testFrameRate(startTime: startTime)
        case .batteryUsage:
            return await testBatteryUsage(startTime: startTime)
        case .databaseQuery:
            return await testDatabaseQuery(startTime: startTime)
        case .audioPlayback:
            return await testAudioPlayback(startTime: startTime)
        }
    }
    
    // MARK: - 具体测试实现
    
    /// 测试启动时间
    private func testLaunchTime(startTime: Date) async -> PerformanceTestResult {
        var times: [TimeInterval] = []
        
        for _ in 0..<launchTimeConfig.iterations {
            let iterationStart = Date()
            
            // 模拟启动流程
            _ = DataManager.shared.quickLaunchCheck()
            await LazyDataManager.shared.performFastLaunch()
            
            times.append(Date().timeIntervalSince(iterationStart))
            
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms间隔
        }
        
        let avgTime = times.reduce(0, +) / Double(times.count)
        let minTime = times.min() ?? 0
        let maxTime = times.max() ?? 0
        
        let status: PerformanceTestResult.TestStatus
        if avgTime <= launchTimeConfig.targetTime {
            status = .pass
        } else if avgTime <= launchTimeConfig.targetTime * 1.5 {
            status = .warning
        } else {
            status = .fail
        }
        
        return PerformanceTestResult(
            testType: .launchTime,
            timestamp: Date(),
            value: avgTime,
            unit: "s",
            status: status,
            details: [
                "iterations": launchTimeConfig.iterations,
                "min": minTime,
                "max": maxTime,
                "target": launchTimeConfig.targetTime,
                "allTimes": times
            ],
            duration: Date().timeIntervalSince(startTime)
        )
    }
    
    /// 测试内存使用
    private func testMemoryUsage(startTime: Date) async -> PerformanceTestResult {
        let initialUsage = MemoryManager.shared.currentUsage?.usedMB ?? 0
        
        // 执行各种操作来测试内存使用
        _ = await LazyDataManager.shared.calculateTodayStatistics()
        await LazyDataManager.shared.loadTodayDueWords()
        await LazyDataManager.shared.loadTodayNewWords()
        
        let peakUsage = MemoryManager.shared.currentUsage?.usedMB ?? 0
        let memoryIncrease = peakUsage - initialUsage
        
        // 评估内存使用
        let status: PerformanceTestResult.TestStatus
        if memoryIncrease < 50 { // 增加少于50MB
            status = .pass
        } else if memoryIncrease < 100 {
            status = .warning
        } else {
            status = .fail
        }
        
        return PerformanceTestResult(
            testType: .memoryUsage,
            timestamp: Date(),
            value: memoryIncrease,
            unit: "MB",
            status: status,
            details: [
                "initial": initialUsage,
                "peak": peakUsage,
                "increase": memoryIncrease
            ],
            duration: Date().timeIntervalSince(startTime)
        )
    }
    
    /// 测试帧率
    private func testFrameRate(startTime: Date) async -> PerformanceTestResult {
        FPSMonitor.shared.startMonitoring()
        
        // 等待测试时间
        try? await Task.sleep(nanoseconds: UInt64(fpsConfig.testDuration * 1_000_000_000))
        
        FPSMonitor.shared.stopMonitoring()
        let report = FPSMonitor.shared.getReport()
        
        return PerformanceTestResult(
            testType: .frameRate,
            timestamp: Date(),
            value: report.averageFPS,
            unit: "FPS",
            status: report.status,
            details: [
                "minFPS": report.minFPS,
                "droppedFrames": report.droppedFrames,
                "totalFrames": report.totalFrames,
                "variance": report.frameTimeVariance
            ],
            duration: Date().timeIntervalSince(startTime)
        )
    }
    
    /// 测试电池消耗
    private func testBatteryUsage(startTime: Date) async -> PerformanceTestResult {
        BatteryMonitor.shared.startMonitoring()
        
        // 等待测试时间
        try? await Task.sleep(nanoseconds: UInt64(batteryConfig.testDuration * 1_000_000_000))
        
        guard let report = BatteryMonitor.shared.stopMonitoring() else {
            return PerformanceTestResult(
                testType: .batteryUsage,
                timestamp: Date(),
                value: 0,
                unit: "%/h",
                status: .fail,
                details: ["error": "无法获取电池数据"],
                duration: Date().timeIntervalSince(startTime)
            )
        }
        
        return PerformanceTestResult(
            testType: .batteryUsage,
            timestamp: Date(),
            value: Double(report.consumptionPerHour),
            unit: "%/h",
            status: report.status,
            details: [
                "startLevel": report.startLevel,
                "endLevel": report.endLevel,
                "consumption": report.consumption,
                "duration": report.duration
            ],
            duration: Date().timeIntervalSince(startTime)
        )
    }
    
    /// 测试数据库查询
    private func testDatabaseQuery(startTime: Date) async -> PerformanceTestResult {
        let dataManager = DataManager.shared
        
        var queryTimes: [String: TimeInterval] = [:]
        
        // 测试各种查询
        let tests: [(name: String, operation: () -> Void)] = [
            ("待复习查询", { _ = dataManager.fetchDueWords(limit: 50) }),
            ("新词查询", { _ = dataManager.fetchNewWords(limit: 20) }),
            ("章节查询", { _ = dataManager.fetchAllChapters() }),
            ("搜索查询", { _ = dataManager.searchWords(query: "test") }),
            ("统计查询", { _ = dataManager.getVocabularyStats() })
        ]
        
        var totalTime: TimeInterval = 0
        
        for (name, operation) in tests {
            let queryStart = Date()
            operation()
            let queryTime = Date().timeIntervalSince(queryStart)
            queryTimes[name] = queryTime
            totalTime += queryTime
        }
        
        let avgTime = totalTime / Double(tests.count)
        
        let status: PerformanceTestResult.TestStatus
        if avgTime < 0.1 {
            status = .pass
        } else if avgTime < 0.5 {
            status = .warning
        } else {
            status = .fail
        }
        
        return PerformanceTestResult(
            testType: .databaseQuery,
            timestamp: Date(),
            value: avgTime,
            unit: "s",
            status: status,
            details: queryTimes,
            duration: Date().timeIntervalSince(startTime)
        )
    }
    
    /// 测试音频播放
    private func testAudioPlayback(startTime: Date) async -> PerformanceTestResult {
        let audioManager = AudioPlayerManager.shared
        let cacheManager = AudioCacheManager.shared
        
        // 测试音频加载时间
        let loadStart = Date()
        
        // 模拟音频加载
        let stats = cacheManager.getCacheStatistics()
        
        let loadTime = Date().timeIntervalSince(loadStart)
        
        // 检查音频缓存状态
        let status: PerformanceTestResult.TestStatus
        if stats.memoryCacheItems > 0 {
            status = .pass
        } else {
            status = .warning // 没有缓存数据
        }
        
        return PerformanceTestResult(
            testType: .audioPlayback,
            timestamp: Date(),
            value: loadTime,
            unit: "s",
            status: status,
            details: [
                "cacheItems": stats.memoryCacheItems,
                "memoryCacheMB": stats.memoryCacheSizeMB,
                "diskCacheMB": stats.diskCacheSizeMB
            ],
            duration: Date().timeIntervalSince(startTime)
        )
    }
    
    // MARK: - 报告生成
    
    /// 打印测试报告
    func printTestReport() {
        print("\n" + "=".repeat(60))
        print("           EarWords 性能测试报告")
        print("=".repeat(60))
        print("测试时间: \(Date())")
        print("-".repeat(60))
        
        var passCount = 0
        var warningCount = 0
        var failCount = 0
        
        for result in testResults {
            let statusIcon = result.status == .pass ? "✅" : (result.status == .warning ? "⚠️" : "❌")
            print("\(statusIcon) \(result.testType.displayName)")
            print("   结果: \(String(format: "%.3f", result.value))\(result.unit)")
            print("   状态: \(result.status.rawValue)")
            print("   耗时: \(String(format: "%.3f", result.duration))s")
            print()
            
            switch result.status {
            case .pass: passCount += 1
            case .warning: warningCount += 1
            case .fail: failCount += 1
            }
        }
        
        print("-".repeat(60))
        print("总览: ✅通过:\(passCount)  ⚠️警告:\(warningCount)  ❌失败:\(failCount)")
        print("=".repeat(60) + "\n")
    }
    
    /// 导出测试报告为JSON
    func exportReport() -> String {
        var report: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "unknown",
            "tests": testResults.map { result in
                [
                    "type": result.testType.displayName,
                    "value": result.value,
                    "unit": result.unit,
                    "status": result.status.rawValue,
                    "duration": result.duration
                ]
            }
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: report, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "{}"
    }
}

// MARK: - String 扩展

private extension String {
    func repeat(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}
