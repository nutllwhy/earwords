//
//  AudioPlayerManager+Cache.swift
//  EarWords
//
//  音频播放器管理器扩展 - 集成音频缓存
//  添加智能预加载和LRU缓存支持
//

import Foundation
import AVFoundation

// MARK: - AudioPlayerManager 缓存扩展

extension AudioPlayerManager {
    
    /// 设置带缓存的播放列表
    func setPlaylistWithCache(words: [WordEntity], mode: PlaybackMode = .sequential) {
        // 调用原有方法设置播放列表
        setPlaylist(words: words, mode: mode)
        
        // 配置智能预加载
        setupSmartPreloading(words: words)
    }
    
    /// 配置智能预加载
    private func setupSmartPreloading(words: [WordEntity]) {
        // 获取即将播放的单词音频URL
        let preloadItems = words.prefix(AudioCacheManager.shared.preloadCount + 1).map { word in
            let audioUrl = word.audioUrl.flatMap { URL(string: $0) }
            return (id: word.id, word: word.word, audioUrl: audioUrl)
        }
        
        // 配置预加载
        AudioCacheManager.shared.preloadAudioQueue(words: Array(preloadItems))
        
        // 设置播放变更回调以触发预加载
        onTrackChanged = { [weak self] item in
            guard let self = self else { return }
            
            // 找到当前播放项在队列中的索引
            if let currentIndex = self.queue.firstIndex(where: { $0.id == item.id }) {
                // 获取剩余队列用于预加载
                let remainingWords = Array(self.queue.dropFirst(currentIndex + 1))
                    .prefix(AudioCacheManager.shared.preloadCount)
                    .map { $0.word }
                
                let preloadData = remainingWords.map { word in
                    let audioUrl = word.audioUrl.flatMap { URL(string: $0) }
                    return (id: word.id, word: word.word, audioUrl: audioUrl)
                }
                
                AudioCacheManager.shared.preloadAudioQueue(words: Array(preloadData))
            }
        }
    }
    
    /// 带缓存的音频加载
    func loadAudioWithCache(for word: WordEntity) async {
        currentState = .loading
        
        let cacheKey = String(word.id)
        
        // 1. 尝试从缓存获取音频数据
        if let cachedData = await AudioCacheManager.shared.getAudio(
            for: word.id,
            word: word.word,
            audioUrl: word.audioUrl.flatMap { URL(string: $0) }
        ) {
            // 从缓存数据加载音频
            await loadAudioFromData(cachedData, word: word)
            return
        }
        
        // 2. 回退到原有加载逻辑
        loadAudio(for: word)
    }
    
    /// 从数据加载音频
    private func loadAudioFromData(_ data: Data, word: WordEntity) async {
        do {
            // 创建临时文件
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent("\(word.id)_cached.aiff")
            
            // 写入数据
            try data.write(to: tempFile)
            
            // 加载音频
            await MainActor.run {
                self.loadAudio(from: tempFile, source: .documents)
            }
            
            // 清理临时文件（延迟）
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                try? FileManager.default.removeItem(at: tempFile)
            }
            
        } catch {
            print("❌ 从缓存数据加载音频失败: \(error)")
            // 回退到原有加载
            await MainActor.run {
                self.loadAudio(for: word)
            }
        }
    }
    
    /// 获取音频缓存统计
    func getAudioCacheStats() -> CacheStatistics {
        return AudioCacheManager.shared.getCacheStatistics()
    }
    
    /// 清理音频缓存
    func clearAudioCache() {
        AudioCacheManager.shared.clearAllCaches()
    }
    
    /// 打印音频缓存报告
    func printAudioCacheReport() {
        AudioCacheManager.shared.printCacheReport()
    }
}

// MARK: - 音频缓存配置扩展

extension AudioCacheManager {
    
    /// 预加载数量（公开访问）
    var preloadCount: Int {
        return config.preloadCount
    }
    
    /// 配置音频缓存（公开方法）
    func configureCache(
        memoryLimitMB: Int = 50,
        diskLimitMB: Int = 200,
        preloadCount: Int = 3,
        expirationDays: Int = 30
    ) {
        let config = AudioCacheConfiguration(
            memoryCacheLimitMB: memoryLimitMB,
            diskCacheLimitMB: diskLimitMB,
            preloadCount: preloadCount,
            fileExpirationDays: expirationDays
        )
        configure(config)
    }
}

// MARK: - 播放队列智能预加载

extension AudioPlayerManager {
    
    /// 智能预加载当前播放位置附近的音频
    func smartPreloadNearCurrentIndex() {
        guard !queue.isEmpty else { return }
        
        // 计算预加载范围（当前+3个）
        let preloadRange = (currentIndex + 1)..<min(currentIndex + 4, queue.count)
        
        var preloadItems: [(id: Int32, word: String, audioUrl: URL?)] = []
        
        for index in preloadRange {
            let word = queue[index].word
            let audioUrl = word.audioUrl.flatMap { URL(string: $0) }
            preloadItems.append((id: word.id, word: word.word, audioUrl: audioUrl))
        }
        
        AudioCacheManager.shared.preloadAudioQueue(words: preloadItems)
    }
}

// MARK: - 内存管理集成

extension AudioCacheManager: AudioCacheMemoryControllable {
    
    func handleMemoryWarning() {
        print("⚠️ AudioCacheManager 收到内存警告")
        trimCache(aggressive: true)
        cancelPreloading()
    }
    
    func trimCache(aggressive: Bool) {
        let targetRatio = aggressive ? 0.3 : 0.5
        let targetSize = Int(Double(memoryCacheSize) * targetRatio)
        
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        // 按权重排序（权重高的优先淘汰）
        let sortedItems = memoryCache.sorted { $0.value.weight > $1.value.weight }
        
        var currentSize = memoryCacheSize
        for (key, item) in sortedItems {
            guard currentSize > targetSize else { break }
            
            memoryCache.removeValue(forKey: key)
            currentSize -= item.size
            
            print("🗑️ LRU淘汰音频缓存: \(key) (\(item.size) bytes)")
        }
        
        updateCacheMetrics()
    }
    
    func currentCacheSizeMB() -> Double {
        return Double(memoryCacheSize) / 1024.0 / 1024.0
    }
    
    func setMemoryLimit(MB: Double) {
        var newConfig = config
        newConfig.memoryCacheLimitMB = Int(MB)
        configure(newConfig)
    }
}

// MARK: - 音频播放性能监控

/// 音频播放性能指标
struct AudioPlaybackMetrics {
    let cacheHitRate: Double
    let averageLoadTime: TimeInterval
    let totalPlayCount: Int
    let cacheHitCount: Int
    let networkLoadCount: Int
}

extension AudioPlayerManager {
    
    /// 播放性能监控
    private static var playbackMetrics: [String: Any] = [
        "totalPlays": 0,
        "cacheHits": 0,
        "networkLoads": 0,
        "totalLoadTime": 0.0
    ]
    
    /// 记录播放指标
    func recordPlaybackMetrics(cacheHit: Bool, loadTime: TimeInterval) {
        AudioPlayerManager.playbackMetrics["totalPlays"] = 
            (AudioPlayerManager.playbackMetrics["totalPlays"] as? Int ?? 0) + 1
        
        if cacheHit {
            AudioPlayerManager.playbackMetrics["cacheHits"] = 
                (AudioPlayerManager.playbackMetrics["cacheHits"] as? Int ?? 0) + 1
        } else {
            AudioPlayerManager.playbackMetrics["networkLoads"] = 
                (AudioPlayerManager.playbackMetrics["networkLoads"] as? Int ?? 0) + 1
        }
        
        AudioPlayerManager.playbackMetrics["totalLoadTime"] = 
            (AudioPlayerManager.playbackMetrics["totalLoadTime"] as? Double ?? 0) + loadTime
    }
    
    /// 获取播放性能指标
    func getPlaybackMetrics() -> AudioPlaybackMetrics {
        let total = AudioPlayerManager.playbackMetrics["totalPlays"] as? Int ?? 0
        let hits = AudioPlayerManager.playbackMetrics["cacheHits"] as? Int ?? 0
        let totalTime = AudioPlayerManager.playbackMetrics["totalLoadTime"] as? Double ?? 0
        let networks = AudioPlayerManager.playbackMetrics["networkLoads"] as? Int ?? 0
        
        return AudioPlaybackMetrics(
            cacheHitRate: total > 0 ? Double(hits) / Double(total) : 0,
            averageLoadTime: total > 0 ? totalTime / Double(total) : 0,
            totalPlayCount: total,
            cacheHitCount: hits,
            networkLoadCount: networks
        )
    }
}
