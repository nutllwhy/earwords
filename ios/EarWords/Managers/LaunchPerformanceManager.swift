//
//  LaunchPerformanceManager.swift
//  EarWords
//
//  启动性能管理器 - 延迟加载 + 启动时间优化
//  目标：3,674词启动加载优化，启动时间 < 1.5秒
//

import Foundation
import SwiftUI
import Combine

// MARK: - 启动阶段

/// 应用启动阶段
enum LaunchPhase: String, CaseIterable {
    case initialized = "初始化完成"
    case coreDataReady = "Core Data就绪"
    case settingsLoaded = "设置加载完成"
    case uiReady = "UI准备就绪"
    case dataPreloaded = "数据预加载完成"
    case fullyReady = "完全就绪"
    
    var order: Int {
        LaunchPhase.allCases.firstIndex(of: self) ?? 0
    }
}

// MARK: - 启动时间测量

/// 启动时间测量工具
class LaunchTimeProfiler {
    
    static let shared = LaunchTimeProfiler()
    
    private var startTime: Date?
    private var phaseTimes: [LaunchPhase: TimeInterval] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    /// 开始测量
    func start() {
        startTime = Date()
        phaseTimes.removeAll()
    }
    
    /// 记录阶段完成
    func record(phase: LaunchPhase) {
        guard let start = startTime else { return }
        
        let elapsed = Date().timeIntervalSince(start)
        
        lock.lock()
        phaseTimes[phase] = elapsed
        lock.unlock()
        
        print("⏱️ 启动阶段 [\(phase.rawValue)]: \(String(format: "%.3f", elapsed))s")
    }
    
    /// 获取总启动时间
    func totalLaunchTime() -> TimeInterval? {
        guard let start = startTime else { return nil }
        return Date().timeIntervalSince(start)
    }
    
    /// 获取阶段时间
    func getPhaseTimes() -> [LaunchPhase: TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return phaseTimes
    }
    
    /// 打印启动报告
    func printReport() {
        guard let total = totalLaunchTime() else {
            print("❌ 未开始启动测量")
            return
        }
        
        print("\n=== 启动时间报告 ===")
        print("总启动时间: \(String(format: "%.3f", total))s")
        print("目标时间: < 1.5s")
        print("状态: \(total < 1.5 ? "✅ 达标" : "⚠️ 超标")")
        print("-".repeat(50))
        
        let sortedPhases = phaseTimes.sorted { $0.key.order < $1.key.order }
        var previousTime: TimeInterval = 0
        
        for (phase, time) in sortedPhases {
            let phaseDuration = time - previousTime
            let percentage = (phaseDuration / total) * 100
            print("\(phase.rawValue.padding(toLength: 15, withPad: " ", startingAt: 0)) " +
                  "\(String(format: "%6.3f", time))s " +
                  "(+\(String(format: "%5.3f", phaseDuration))s, \(String(format: "%4.1f", percentage))%)")
            previousTime = time
        }
        
        print("=".repeat(50) + "\n")
    }
}

// MARK: - 延迟加载数据管理器

/// 延迟加载数据管理器
/// 只加载今日需要的数据，避免启动时全量加载
@MainActor
class LazyDataManager: ObservableObject {
    
    static let shared = LazyDataManager()
    
    // MARK: - 发布属性
    @Published var isInitialized: Bool = false
    @Published var isLoading: Bool = false
    @Published var currentPhase: LaunchPhase = .initialized
    
    // MARK: - 缓存数据
    
    /// 今日待复习单词（延迟加载）
    @Published private(set) var todayDueWords: [WordEntity] = []
    
    /// 今日新单词（延迟加载）
    @Published private(set) var todayNewWords: [WordEntity] = []
    
    /// 今日统计（延迟计算）
    @Published private(set) var todayStatistics: TodayStudyStats?
    
    /// 章节列表（延迟加载）
    @Published private(set) var chapterList: [ChapterInfo] = []
    
    // MARK: - 加载状态跟踪
    
    private var loadedDataTypes: Set<LazyLoadableData> = []
    private var dataManager: DataManager { .shared }
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 配置
    
    /// 今日新词目标
    private let dailyNewWordsTarget = 20
    
    /// 今日复习上限
    private let dailyReviewLimit = 50
    
    // MARK: - 初始化
    
    private init() {}
    
    // MARK: - 启动流程
    
    /// 执行快速启动
    /// 只加载UI显示必需的最小数据集
    func performFastLaunch() async {
        LaunchTimeProfiler.shared.start()
        
        // 阶段1: 初始化完成（已经在init中）
        currentPhase = .initialized
        LaunchTimeProfiler.shared.record(phase: .initialized)
        
        // 阶段2: 等待Core Data就绪
        // DataManager.shared 已经在应用启动时初始化
        currentPhase = .coreDataReady
        LaunchTimeProfiler.shared.record(phase: .coreDataReady)
        
        // 阶段3: 加载设置（UserDefaults，非常快）
        loadSettings()
        currentPhase = .settingsLoaded
        LaunchTimeProfiler.shared.record(phase: .settingsLoaded)
        
        // 阶段4: UI准备就绪（使用最小数据集）
        // 不等待数据加载，让UI先显示
        currentPhase = .uiReady
        isInitialized = true
        LaunchTimeProfiler.shared.record(phase: .uiReady)
        
        // 阶段5: 后台预加载今日数据
        await preloadTodayData()
        currentPhase = .dataPreloaded
        LaunchTimeProfiler.shared.record(phase: .dataPreloaded)
        
        currentPhase = .fullyReady
        LaunchTimeProfiler.shared.record(phase: .fullyReady)
        
        // 打印启动报告
        LaunchTimeProfiler.shared.printReport()
    }
    
    /// 加载设置
    private func loadSettings() {
        // 从UserDefaults加载设置，通常在毫秒级完成
        let defaults = UserDefaults.standard
        
        // 预加载常用设置到内存
        _ = defaults.object(forKey: "dailyNewWordsTarget")
        _ = defaults.object(forKey: "reminderEnabled")
        _ = defaults.object(forKey: "colorScheme")
    }
    
    /// 后台预加载今日数据
    private func preloadTodayData() async {
        // 使用后台线程加载数据
        await withTaskGroup(of: Void.self) { group in
            // 加载今日待复习单词
            group.addTask {
                await self.loadTodayDueWords()
            }
            
            // 加载今日新词
            group.addTask {
                await self.loadTodayNewWords()
            }
            
            // 加载章节列表（简化版，只加载元数据）
            group.addTask {
                await self.loadChapterList()
            }
        }
    }
    
    // MARK: - 延迟加载方法
    
    /// 加载今日待复习单词
    func loadTodayDueWords() async {
        guard !loadedDataTypes.contains(.todayDueWords) else { return }
        
        let words = await Task.detached {
            return self.dataManager.fetchDueWords(limit: self.dailyReviewLimit)
        }.value
        
        await MainActor.run {
            self.todayDueWords = words
            self.loadedDataTypes.insert(.todayDueWords)
        }
        
        print("✅ 延迟加载完成: \(words.count) 个待复习单词")
    }
    
    /// 加载今日新词
    func loadTodayNewWords() async {
        guard !loadedDataTypes.contains(.todayNewWords) else { return }
        
        let words = await Task.detached {
            return self.dataManager.fetchNewWords(limit: self.dailyNewWordsTarget)
        }.value
        
        await MainActor.run {
            self.todayNewWords = words
            self.loadedDataTypes.insert(.todayNewWords)
        }
        
        print("✅ 延迟加载完成: \(words.count) 个新单词")
    }
    
    /// 加载章节列表（简化版）
    func loadChapterList() async {
        guard !loadedDataTypes.contains(.chapterList) else { return }
        
        let chapters = await Task.detached {
            return self.dataManager.fetchAllChapters()
        }.value
        
        await MainActor.run {
            self.chapterList = chapters
            self.loadedDataTypes.insert(.chapterList)
        }
        
        print("✅ 延迟加载完成: \(chapters.count) 个章节")
    }
    
    /// 计算今日统计
    func calculateTodayStatistics() async -> TodayStudyStats {
        // 如果已经计算过，直接返回
        if let stats = todayStatistics {
            return stats
        }
        
        return await Task.detached {
            // 异步计算今日统计
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            
            // 今日新学单词数
            let newWordsRequest = WordEntity.fetchRequest()
            newWordsRequest.predicate = NSPredicate(
                format: "status != %@ AND lastReviewDate >= %@",
                "new",
                startOfDay as CVarArg
            )
            let newWordsCount = (try? self.dataManager.context.count(for: newWordsRequest)) ?? 0
            
            // 今日复习数
            let reviewRequest = ReviewLogEntity.fetchRequest()
            reviewRequest.predicate = NSPredicate(
                format: "reviewDate >= %@",
                startOfDay as CVarArg
            )
            let reviewCount = (try? self.dataManager.context.count(for: reviewRequest)) ?? 0
            
            // 正确数
            let correctRequest = ReviewLogEntity.fetchRequest()
            correctRequest.predicate = NSPredicate(
                format: "reviewDate >= %@ AND result == %@",
                startOfDay as CVarArg,
                "correct"
            )
            let correctCount = (try? self.dataManager.context.count(for: correctRequest)) ?? 0
            
            // 错误数
            let incorrectCount = reviewCount - correctCount
            
            // 正确率
            let accuracy = reviewCount > 0 ? Double(correctCount) / Double(reviewCount) : 0
            
            return TodayStudyStats(
                newWordsCount: newWordsCount,
                reviewWordsCount: reviewCount,
                correctCount: correctCount,
                incorrectCount: incorrectCount,
                streakDays: 0, // 简化计算
                accuracy: accuracy,
                totalTime: 0,
                tomorrowPreview: []
            )
        }.value
    }
    
    /// 按需加载章节单词
    func loadWords(forChapter chapterKey: String) async -> [WordEntity] {
        return await Task.detached {
            return self.dataManager.fetchWordsByChapter(chapterKey: chapterKey)
        }.value
    }
    
    /// 按需加载搜索结果
    func searchWords(query: String, status: String? = nil) async -> [WordEntity] {
        guard query.count >= 2 else { return [] }
        
        return await Task.detached {
            return self.dataManager.searchWords(query: query, status: status)
        }.value
    }
    
    /// 检查数据是否已加载
    func isDataLoaded(_ type: LazyLoadableData) -> Bool {
        return loadedDataTypes.contains(type)
    }
    
    /// 强制刷新数据
    func refreshData(_ type: LazyLoadableData) async {
        loadedDataTypes.remove(type)
        
        switch type {
        case .todayDueWords:
            await loadTodayDueWords()
        case .todayNewWords:
            await loadTodayNewWords()
        case .chapterList:
            await loadChapterList()
        case .statistics:
            todayStatistics = nil
            _ = await calculateTodayStatistics()
        }
    }
}

// MARK: - 可延迟加载的数据类型

enum LazyLoadableData: String, CaseIterable {
    case todayDueWords = "今日待复习单词"
    case todayNewWords = "今日新单词"
    case chapterList = "章节列表"
    case statistics = "统计数据"
}

// MARK: - 启动优化扩展

extension DataManager {
    
    /// 快速启动检查（不加载全部数据）
    func quickLaunchCheck() -> LaunchCheckResult {
        let startTime = Date()
        
        // 快速检查词库是否已导入
        let isImported = isVocabularyImported()
        
        // 快速获取基本统计（使用count查询，避免fetch）
        let totalCount = (try? context.count(for: WordEntity.fetchRequest())) ?? 0
        
        let checkTime = Date().timeIntervalSince(startTime)
        
        return LaunchCheckResult(
            isVocabularyImported: isImported,
            totalWordCount: totalCount,
            checkTime: checkTime
        )
    }
}

// MARK: - 启动检查结果

struct LaunchCheckResult {
    let isVocabularyImported: Bool
    let totalWordCount: Int
    let checkTime: TimeInterval
    
    var needsImport: Bool {
        !isVocabularyImported || totalWordCount == 0
    }
}

// MARK: - 性能基准测试

/// 启动性能基准测试
class LaunchBenchmark {
    
    static let shared = LaunchBenchmark()
    
    private var benchmarks: [String: [TimeInterval]] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    /// 运行基准测试
    func runBenchmark(iterations: Int = 5) async -> BenchmarkResult {
        var results: [TimeInterval] = []
        
        for i in 0..<iterations {
            print("运行基准测试 \(i + 1)/\(iterations)...")
            
            let startTime = Date()
            
            // 模拟启动流程
            _ = DataManager.shared.quickLaunchCheck()
            await LazyDataManager.shared.performFastLaunch()
            
            let launchTime = Date().timeIntervalSince(startTime)
            results.append(launchTime)
            
            // 重置状态
            await Task.sleep(500_000_000) // 500ms
        }
        
        let avg = results.reduce(0, +) / Double(results.count)
        let min = results.min() ?? 0
        let max = results.max() ?? 0
        
        let result = BenchmarkResult(
            iterations: iterations,
            averageTime: avg,
            minTime: min,
            maxTime: max,
            allTimes: results
        )
        
        return result
    }
    
    /// 打印基准测试报告
    func printBenchmarkReport(result: BenchmarkResult) {
        print("\n=== 启动性能基准测试报告 ===")
        print("测试次数: \(result.iterations)")
        print("平均启动时间: \(String(format: "%.3f", result.averageTime))s")
        print("最短启动时间: \(String(format: "%.3f", result.minTime))s")
        print("最长启动时间: \(String(format: "%.3f", result.maxTime))s")
        print("目标时间: < 1.5s")
        print("达标状态: \(result.averageTime < 1.5 ? "✅ 达标" : "⚠️ 超标")")
        print("详细数据: \(result.allTimes.map { String(format: "%.3f", $0) }.joined(separator: "s, "))s")
        print("=".repeat(40) + "\n")
    }
}

// MARK: - 基准测试结果

struct BenchmarkResult {
    let iterations: Int
    let averageTime: TimeInterval
    let minTime: TimeInterval
    let maxTime: TimeInterval
    let allTimes: [TimeInterval]
}

// MARK: - String 扩展

private extension String {
    func repeat(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}
