//
//  AudioCacheManager.swift
//  EarWords
//
//  音频缓存管理器 - LRU缓存策略
//  智能预加载 + 内存管理 + 文件清理
//

import Foundation
import AVFoundation
import Combine

// MARK: - 音频缓存项

/// 音频缓存项
struct AudioCacheItem {
    let id: String
    let url: URL
    let data: Data
    let size: Int
    let lastAccessed: Date
    let accessCount: Int
    
    /// 缓存权重（用于LRU淘汰决策）
    var weight: Double {
        let ageWeight = Date().timeIntervalSince(lastAccessed) / 3600.0 // 小时数
        let frequencyWeight = Double(accessCount) * 0.5
        return ageWeight - frequencyWeight
    }
}

// MARK: - 音频预加载队列

/// 音频预加载队列项
struct PreloadQueueItem: Identifiable {
    let id = UUID()
    let wordId: Int32
    let word: String
    let audioUrl: URL?
    let priority: PreloadPriority
    let timestamp: Date
}

/// 预加载优先级
enum PreloadPriority: Int, Comparable {
    case immediate = 0   // 当前播放
    case high = 1        // 下1个播放
    case medium = 2      // 下2-3个播放
    case low = 3         // 后台预加载
    
    static func < (lhs: PreloadPriority, rhs: PreloadPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - 音频缓存配置

/// 音频缓存配置
struct AudioCacheConfiguration {
    /// 内存缓存上限（MB）
    var memoryCacheLimitMB: Int = 50
    
    /// 磁盘缓存上限（MB）
    var diskCacheLimitMB: Int = 200
    
    /// 预加载数量（即将播放的音频数）
    var preloadCount: Int = 3
    
    /// 音频文件过期时间（天）
    var fileExpirationDays: Int = 30
    
    /// 内存警告时保留比例
    var memoryWarningRetentionRatio: Double = 0.5
    
    /// 自动清理间隔（小时）
    var autoCleanupInterval: TimeInterval = 24 * 3600
    
    /// 最大并发下载数
    var maxConcurrentDownloads: Int = 2
    
    /// 音频格式质量
    var audioQuality: AVAudioQuality = .high
    
    /// 内存缓存上限（字节）
    var memoryCacheLimitBytes: Int {
        memoryCacheLimitMB * 1024 * 1024
    }
    
    /// 磁盘缓存上限（字节）
    var diskCacheLimitBytes: Int {
        diskCacheLimitMB * 1024 * 1024
    }
}

// MARK: - 音频缓存管理器

@MainActor
class AudioCacheManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = AudioCacheManager()
    
    // MARK: - 发布属性
    @Published var memoryCacheSize: Int = 0
    @Published var diskCacheSize: Int = 0
    @Published var cachedItemCount: Int = 0
    @Published var isPreloading: Bool = false
    @Published var preloadProgress: Double = 0
    
    // MARK: - 私有属性
    
    /// 内存缓存 [wordId: cacheItem]
    private var memoryCache: [String: AudioCacheItem] = [:]
    private let cacheLock = NSLock()
    
    /// 磁盘缓存目录
    private var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("AudioCache", isDirectory: true)
    }
    
    /// 预加载队列
    private var preloadQueue: [PreloadQueueItem] = []
    private var currentPreloadTask: Task<Void, Never>?
    
    /// 活跃下载任务
    private var activeDownloads: [Int32: Task<Data?, Error>] = [:]
    
    /// 配置
    private var config: AudioCacheConfiguration
    
    /// 取消订阅集合
    private var cancellables = Set<AnyCancellable>()
    
    /// 内存警告通知
    private var memoryWarningObserver: NSObjectProtocol?
    
    /// 自动清理定时器
    private var cleanupTimer: Timer?
    
    // MARK: - 初始化
    
    private init(config: AudioCacheConfiguration = AudioCacheConfiguration()) {
        self.config = config
        setupCacheDirectory()
        setupMemoryWarningHandler()
        setupAutoCleanup()
        updateCacheMetrics()
    }
    
    deinit {
        cleanupTimer?.invalidate()
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - 设置
    
    /// 配置缓存
    func configure(_ configuration: AudioCacheConfiguration) {
        self.config = configuration
        
        // 如果新配置限制更小，触发清理
        if memoryCacheSize > config.memoryCacheLimitBytes {
            trimMemoryCache(to: Int(Double(config.memoryCacheLimitBytes) * 0.8))
        }
    }
    
    /// 设置缓存目录
    private func setupCacheDirectory() {
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }
    
    /// 设置内存警告处理
    private func setupMemoryWarningHandler() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    /// 设置自动清理
    private func setupAutoCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: config.autoCleanupInterval, repeats: true) { [weak self] _ in
            self?.performAutoCleanup()
        }
    }
    
    // MARK: - 缓存操作
    
    /// 获取音频数据（带缓存）
    func getAudio(for wordId: Int32, word: String, audioUrl: URL?) async -> Data? {
        let cacheKey = String(wordId)
        
        // 1. 检查内存缓存
        if let cachedItem = getFromMemoryCache(key: cacheKey) {
            print("✅ 内存缓存命中: \(word)")
            return cachedItem.data
        }
        
        // 2. 检查磁盘缓存
        if let diskData = getFromDiskCache(key: cacheKey) {
            print("✅ 磁盘缓存命中: \(word)")
            // 放入内存缓存
            await cacheToMemory(key: cacheKey, data: diskData, url: audioUrl)
            return diskData
        }
        
        // 3. 下载音频
        guard let url = audioUrl else { return nil }
        
        if let data = await downloadAudio(from: url, wordId: wordId) {
            // 缓存到内存和磁盘
            await cacheToMemory(key: cacheKey, data: data, url: audioUrl)
            await cacheToDisk(key: cacheKey, data: data)
            return data
        }
        
        return nil
    }
    
    /// 预加载音频队列
    func preloadAudioQueue(words: [(id: Int32, word: String, audioUrl: URL?)]) {
        // 构建预加载队列
        var queue: [PreloadQueueItem] = []
        
        for (index, item) in words.enumerated() {
            let priority: PreloadPriority
            switch index {
            case 0: priority = .immediate
            case 1: priority = .high
            case 2..<config.preloadCount: priority = .medium
            default: priority = .low
            }
            
            queue.append(PreloadQueueItem(
                wordId: item.id,
                word: item.word,
                audioUrl: item.audioUrl,
                priority: priority,
                timestamp: Date()
            ))
        }
        
        self.preloadQueue = queue.sorted { $0.priority < $1.priority }
        
        // 启动预加载
        startPreloading()
    }
    
    /// 智能预加载（即将播放的3个音频）
    func smartPreload(currentIndex: Int, words: [WordEntity]) {
        // 计算需要预加载的范围
        let preloadRange = (currentIndex + 1)..<min(currentIndex + 1 + config.preloadCount, words.count)
        
        var preloadItems: [(id: Int32, word: String, audioUrl: URL?)] = []
        
        for index in preloadRange {
            let word = words[index]
            let audioUrl = word.audioUrl.flatMap { URL(string: $0) }
            preloadItems.append((id: word.id, word: word.word, audioUrl: audioUrl))
        }
        
        preloadAudioQueue(words: preloadItems)
    }
    
    /// 开始预加载
    private func startPreloading() {
        // 取消现有任务
        currentPreloadTask?.cancel()
        
        currentPreloadTask = Task {
            await performPreloading()
        }
    }
    
    /// 执行预加载
    private func performPreloading() async {
        guard !preloadQueue.isEmpty else { return }
        
        await MainActor.run {
            isPreloading = true
            preloadProgress = 0
        }
        
        let totalCount = preloadQueue.count
        var completedCount = 0
        
        // 限制并发数
        let semaphore = AsyncSemaphore(value: config.maxConcurrentDownloads)
        
        await withTaskGroup(of: Void.self) { group in
            for item in preloadQueue {
                group.addTask {
                    await semaphore.wait()
                    defer { semaphore.signal() }
                    
                    // 检查是否已取消
                    guard !Task.isCancelled else { return }
                    
                    // 检查是否已在缓存中
                    let cacheKey = String(item.wordId)
                    if await self.isCached(key: cacheKey) {
                        await MainActor.run {
                            completedCount += 1
                            self.preloadProgress = Double(completedCount) / Double(totalCount)
                        }
                        return
                    }
                    
                    // 下载并缓存
                    if let url = item.audioUrl {
                        if let data = await self.downloadAudio(from: url, wordId: item.wordId) {
                            await self.cacheToMemory(key: cacheKey, data: data, url: item.audioUrl)
                            await self.cacheToDisk(key: cacheKey, data: data)
                            print("✅ 预加载完成: \(item.word)")
                        }
                    }
                    
                    await MainActor.run {
                        completedCount += 1
                        self.preloadProgress = Double(completedCount) / Double(totalCount)
                    }
                }
            }
        }
        
        await MainActor.run {
            isPreloading = false
            preloadProgress = 1.0
        }
        
        // 清理已完成的队列项
        preloadQueue.removeAll()
    }
    
    /// 取消预加载
    func cancelPreloading() {
        currentPreloadTask?.cancel()
        currentPreloadTask = nil
        preloadQueue.removeAll()
        
        // 取消活跃下载
        for (_, task) in activeDownloads {
            task.cancel()
        }
        activeDownloads.removeAll()
        
        isPreloading = false
        preloadProgress = 0
    }
    
    // MARK: - 内存缓存管理
    
    /// 从内存缓存获取
    private func getFromMemoryCache(key: String) -> AudioCacheItem? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard var item = memoryCache[key] else { return nil }
        
        // 更新访问信息
        item = AudioCacheItem(
            id: item.id,
            url: item.url,
            data: item.data,
            size: item.size,
            lastAccessed: Date(),
            accessCount: item.accessCount + 1
        )
        memoryCache[key] = item
        
        return item
    }
    
    /// 缓存到内存（LRU策略）
    private func cacheToMemory(key: String, data: Data, url: URL?) async {
        cacheLock.lock()
        
        // 检查内存限制
        let newItemSize = data.count
        if memoryCacheSize + newItemSize > config.memoryCacheLimitBytes {
            cacheLock.unlock()
            // 需要先清理
            trimMemoryCache(to: Int(Double(config.memoryCacheLimitBytes) * 0.8))
            cacheLock.lock()
        }
        
        // 创建缓存项
        let item = AudioCacheItem(
            id: key,
            url: url,
            data: data,
            size: newItemSize,
            lastAccessed: Date(),
            accessCount: 1
        )
        
        memoryCache[key] = item
        cacheLock.unlock()
        
        updateCacheMetrics()
    }
    
    /// 裁剪内存缓存（LRU淘汰）
    private func trimMemoryCache(to targetSize: Int) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        var currentSize = memoryCacheSize
        
        // 按权重排序（权重高的优先淘汰）
        let sortedItems = memoryCache.sorted { $0.value.weight > $1.value.weight }
        
        for (key, item) in sortedItems {
            guard currentSize > targetSize else { break }
            
            memoryCache.removeValue(forKey: key)
            currentSize -= item.size
            
            print("🗑️ LRU淘汰内存缓存: \(key)")
        }
        
        updateCacheMetrics()
    }
    
    /// 检查是否已缓存
    private func isCached(key: String) async -> Bool {
        cacheLock.lock()
        let inMemory = memoryCache[key] != nil
        cacheLock.unlock()
        
        if inMemory { return true }
        
        return isInDiskCache(key: key)
    }
    
    // MARK: - 磁盘缓存管理
    
    /// 从磁盘缓存获取
    private func getFromDiskCache(key: String) -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).audio")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            
            // 更新访问时间
            try? FileManager.default.setAttributes(
                [.modificationDate: Date()],
                ofItemAtPath: fileURL.path
            )
            
            return data
        } catch {
            print("❌ 读取磁盘缓存失败: \(error)")
            return nil
        }
    }
    
    /// 缓存到磁盘
    private func cacheToDisk(key: String, data: Data) async {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).audio")
        
        do {
            try data.write(to: fileURL)
            
            // 检查磁盘缓存限制
            await checkDiskCacheLimit()
        } catch {
            print("❌ 写入磁盘缓存失败: \(error)")
        }
        
        await MainActor.run {
            updateDiskCacheSize()
        }
    }
    
    /// 检查磁盘缓存限制
    private func checkDiskCacheLimit() async {
        let currentSize = calculateDiskCacheSize()
        
        guard currentSize > config.diskCacheLimitBytes else { return }
        
        // 按修改时间排序，删除最旧的文件
        let targetSize = Int(Double(config.diskCacheLimitBytes) * 0.8)
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
            )
            
            // 获取文件信息
            var fileInfos: [(url: URL, size: Int, date: Date)] = []
            
            for file in files {
                let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
                let size = (attributes?[.size] as? Int) ?? 0
                let date = (attributes?[.modificationDate] as? Date) ?? Date.distantPast
                fileInfos.append((url: file, size: size, date: date))
            }
            
            // 按日期排序（旧的在前）
            fileInfos.sort { $0.date < $1.date }
            
            // 删除文件直到低于目标大小
            var remainingSize = currentSize
            for fileInfo in fileInfos {
                guard remainingSize > targetSize else { break }
                
                try? FileManager.default.removeItem(at: fileInfo.url)
                remainingSize -= fileInfo.size
                
                print("🗑️ 清理磁盘缓存: \(fileInfo.url.lastPathComponent)")
            }
            
        } catch {
            print("❌ 清理磁盘缓存失败: \(error)")
        }
    }
    
    /// 检查是否在磁盘缓存中
    private func isInDiskCache(key: String) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).audio")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// 计算磁盘缓存大小
    private func calculateDiskCacheSize() -> Int {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey]
            )
            
            return files.reduce(0) { total, file in
                let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
                return total + ((attributes?[.size] as? Int) ?? 0)
            }
        } catch {
            return 0
        }
    }
    
    // MARK: - 下载管理
    
    /// 下载音频
    private func downloadAudio(from url: URL, wordId: Int32) async -> Data? {
        // 检查是否已有进行中的下载
        if let existingTask = activeDownloads[wordId] {
            do {
                return try await existingTask.value
            } catch {
                return nil
            }
        }
        
        // 创建新下载任务
        let task = Task<Data?, Error> {
            defer {
                activeDownloads.removeValue(forKey: wordId)
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    return nil
                }
                
                return data
            } catch {
                print("❌ 下载音频失败: \(error)")
                return nil
            }
        }
        
        activeDownloads[wordId] = task
        
        do {
            return try await task.value
        } catch {
            return nil
        }
    }
    
    // MARK: - 内存警告处理
    
    /// 处理内存警告
    private func handleMemoryWarning() {
        print("⚠️ 收到内存警告，清理音频缓存")
        
        let targetSize = Int(Double(memoryCacheSize) * (1 - config.memoryWarningRetentionRatio))
        trimMemoryCache(to: targetSize)
        
        // 取消低优先级的预加载
        cancelLowPriorityPreloads()
    }
    
    /// 取消低优先级预加载
    private func cancelLowPriorityPreloads() {
        preloadQueue.removeAll { $0.priority == .low }
    }
    
    // MARK: - 自动清理
    
    /// 执行自动清理
    private func performAutoCleanup() {
        print("🧹 执行音频缓存自动清理")
        
        // 1. 清理过期文件
        cleanupExpiredFiles()
        
        // 2. 清理内存缓存
        trimMemoryCache(to: Int(Double(config.memoryCacheLimitBytes) * 0.7))
        
        // 3. 检查磁盘限制
        Task {
            await checkDiskCacheLimit()
        }
        
        updateCacheMetrics()
    }
    
    /// 清理过期文件
    private func cleanupExpiredFiles() {
        let expirationInterval = TimeInterval(config.fileExpirationDays * 24 * 3600)
        let cutoffDate = Date().addingTimeInterval(-expirationInterval)
        
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )
            
            var cleanedCount = 0
            
            for file in files {
                let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
                let modificationDate = (attributes?[.modificationDate] as? Date) ?? Date.distantPast
                
                if modificationDate < cutoffDate {
                    try? FileManager.default.removeItem(at: file)
                    cleanedCount += 1
                }
            }
            
            if cleanedCount > 0 {
                print("🗑️ 清理了 \(cleanedCount) 个过期音频文件")
            }
            
        } catch {
            print("❌ 清理过期文件失败: \(error)")
        }
    }
    
    // MARK: - 缓存指标
    
    /// 更新缓存指标
    private func updateCacheMetrics() {
        cacheLock.lock()
        memoryCacheSize = memoryCache.values.reduce(0) { $0 + $1.size }
        cachedItemCount = memoryCache.count
        cacheLock.unlock()
    }
    
    /// 更新磁盘缓存大小
    private func updateDiskCacheSize() {
        diskCacheSize = calculateDiskCacheSize()
    }
    
    // MARK: - 公共方法
    
    /// 清空所有缓存
    func clearAllCaches() {
        // 清空内存缓存
        cacheLock.lock()
        memoryCache.removeAll()
        cacheLock.unlock()
        
        // 清空磁盘缓存
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            print("❌ 清空磁盘缓存失败: \(error)")
        }
        
        updateCacheMetrics()
        updateDiskCacheSize()
        
        print("✅ 已清空所有音频缓存")
    }
    
    /// 获取缓存统计
    func getCacheStatistics() -> CacheStatistics {
        cacheLock.lock()
        let memoryItems = memoryCache.count
        let memorySize = memoryCacheSize
        cacheLock.unlock()
        
        return CacheStatistics(
            memoryCacheItems: memoryItems,
            memoryCacheSizeMB: Double(memorySize) / 1024.0 / 1024.0,
            diskCacheSizeMB: Double(diskCacheSize) / 1024.0 / 1024.0,
            activeDownloads: activeDownloads.count,
            preloadQueueSize: preloadQueue.count
        )
    }
    
    /// 打印缓存报告
    func printCacheReport() {
        let stats = getCacheStatistics()
        print("\n=== 音频缓存报告 ===")
        print("内存缓存项: \(stats.memoryCacheItems)")
        print("内存缓存大小: \(String(format: "%.2f", stats.memoryCacheSizeMB)) MB")
        print("磁盘缓存大小: \(String(format: "%.2f", stats.diskCacheSizeMB)) MB")
        print("活跃下载: \(stats.activeDownloads)")
        print("预加载队列: \(stats.preloadQueueSize)")
        print("==================\n")
    }
}

// MARK: - 缓存统计

struct CacheStatistics {
    let memoryCacheItems: Int
    let memoryCacheSizeMB: Double
    let diskCacheSizeMB: Double
    let activeDownloads: Int
    let preloadQueueSize: Int
}

// MARK: - 异步信号量

actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        if value > 0 {
            value -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }
    
    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}
