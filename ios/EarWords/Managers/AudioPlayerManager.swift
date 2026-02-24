//
//  AudioPlayerManager.swift
//  EarWords
//
//  音频播放器管理器 - 完整版
//  支持：后台播放、锁屏控制、音频加载优先级、多种播放模式
//

import Foundation
import AVFoundation
import MediaPlayer
import Combine

// MARK: - 播放模式

enum PlaybackMode: String, CaseIterable {
    case sequential = "顺序播放"   // 按顺序播放
    case random = "随机播放"       // 随机打乱
    case spaced = "间隔重复"       // 根据掌握程度智能重复
}

// MARK: - 播放状态

enum PlayerState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case finished
    case error(String)
}

// MARK: - 播放队列项

struct PlaybackQueueItem: Identifiable, Equatable {
    let id = UUID()
    let word: WordEntity
    var priority: Double = 0      // 用于间隔重复模式的优先级
    var playCount: Int = 0        // 播放次数
    var lastPlayed: Date?         // 上次播放时间
    var audioSource: AudioSource = .unknown  // 音频来源
}

// MARK: - 音频来源

enum AudioSource {
    case documents       // Documents目录（已下载）
    case bundle          // Bundle资源
    case audioExamples   // Data/audio-examples/目录
    case online          // 在线URL
    case tts             // TTS降级
    case unknown
}

// MARK: - 音频播放器管理器

class AudioPlayerManager: NSObject, ObservableObject {
    
    // MARK: - 单例
    static let shared = AudioPlayerManager()
    
    // MARK: - 发布属性
    @Published var currentState: PlayerState = .idle
    @Published var currentItem: PlaybackQueueItem?
    @Published var currentIndex: Int = 0
    @Published var progress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var playbackMode: PlaybackMode = .sequential
    @Published var queue: [PlaybackQueueItem] = []
    @Published var isShuffleEnabled: Bool = false
    @Published var playbackSpeed: Float = 1.0
    @Published var currentAudioSource: AudioSource = .unknown
    
    // 完成回调
    var onPlaybackFinished: (() -> Void)?
    var onTrackChanged: ((PlaybackQueueItem) -> Void)?
    
    // MARK: - 私有属性
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var commandCenter = MPRemoteCommandCenter.shared()
    private var nowPlayingInfo = [String: Any]()
    private var audioSession: AVAudioSession { AVAudioSession.sharedInstance() }
    private var ttsSynthesizer = AVSpeechSynthesizer()
    
    // 间隔重复模式的播放历史
    private var spacedRepetitionHistory: [Int32: [Date]] = [:]
    private var originalQueue: [PlaybackQueueItem] = []  // 原始队列（用于顺序模式恢复）
    
    // MARK: - 初始化
    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
        setupTTS()
    }
    
    // MARK: - 音频会话配置
    private func setupAudioSession() {
        do {
            // 配置为播放模式，支持后台播放
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.setActive(true)
            print("✅ 音频会话配置成功")
        } catch {
            print("❌ 配置音频会话失败: \(error)")
        }
    }
    
    // MARK: - TTS配置
    private func setupTTS() {
        ttsSynthesizer.delegate = self
    }
    
    // MARK: - 远程控制中心设置（锁屏控制）
    private func setupRemoteCommandCenter() {
        // 播放命令
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        // 暂停命令
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // 下一首命令
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        
        // 上一首命令
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
        
        // 拖动进度条
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
        
        // 启用命令
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        
        print("✅ 远程控制中心配置成功")
    }
    
    // MARK: - 播放队列管理
    
    /// 设置播放列表
    func setPlaylist(words: [WordEntity], mode: PlaybackMode = .sequential) {
        self.playbackMode = mode
        self.queue = words.map { PlaybackQueueItem(word: $0) }
        self.originalQueue = self.queue
        
        switch mode {
        case .sequential:
            // 按单词ID排序
            queue.sort { $0.word.id < $1.word.id }
            
        case .random:
            // 随机打乱
            queue.shuffle()
            
        case .spaced:
            // 根据掌握程度排序（不熟悉优先）
            sortQueueBySpacedRepetition()
        }
        
        currentIndex = 0
        if let firstItem = queue.first {
            currentItem = firstItem
            loadAudio(for: firstItem.word)
        }
        
        print("✅ 播放列表设置完成: \(queue.count) 个单词, 模式: \(mode.rawValue)")
    }
    
    /// 更新间隔重复优先级
    private func updateSpacedRepetitionPriorities() {
        for index in queue.indices {
            let item = queue[index]
            let word = item.word
            
            // 计算优先级：不熟悉的词优先级高
            var priority = 1.0
            
            // 基于正确率的优先级（正确率越低优先级越高）
            let accuracy = word.accuracy
            if accuracy < 0.3 {
                priority += 3.0
            } else if accuracy < 0.5 {
                priority += 2.0
            } else if accuracy < 0.8 {
                priority += 1.0
            }
            
            // 基于难度的优先级（难度越高优先级越高）
            let difficulty = Double(word.difficulty)
            priority += (6.0 - difficulty) * 0.3
            
            // 基于学习状态的优先级
            switch word.status {
            case "learning":
                priority += 1.5
            case "new":
                priority += 1.0
            case "mastered":
                priority += 0.2
            default:
                break
            }
            
            // 基于复习次数的优先级（复习次数少的优先）
            priority += max(0, 5.0 - Double(word.reviewCount)) * 0.2
            
            // 基于播放次数的衰减（播放次数多的降低优先级）
            priority -= Double(item.playCount) * 0.4
            
            // 基于时间间隔的衰减（刚播放过的降低优先级）
            if let lastPlayed = item.lastPlayed {
                let minutesSince = Date().timeIntervalSince(lastPlayed) / 60
                priority += min(2.0, minutesSince / 15)  // 每15分钟增加一点优先级
            }
            
            // 基于连续正确次数的优先级（连续正确多的降低优先级）
            priority -= Double(word.streak) * 0.1
            
            queue[index].priority = max(0.1, priority)  // 最小优先级0.1
        }
    }
    
    /// 按间隔重复排序队列
    private func sortQueueBySpacedRepetition() {
        updateSpacedRepetitionPriorities()
        queue.sort { $0.priority > $1.priority }
        print("🔄 间隔重复队列已排序，前5个优先级: \(queue.prefix(5).map { "\($0.word.word):\(String(format: "%.1f", $0.priority))" })")
    }
    
    /// 刷新间隔重复队列
    func refreshSpacedRepetitionQueue() {
        guard playbackMode == .spaced else { return }
        sortQueueBySpacedRepetition()
        // 重新定位当前播放项
        if let currentItem = currentItem,
           let newIndex = queue.firstIndex(where: { $0.id == currentItem.id }) {
            currentIndex = newIndex
        }
    }
    
    // MARK: - 音频加载（优先级实现）
    
    /// 加载音频 - 按优先级查找
    func loadAudio(for word: WordEntity) {
        currentState = .loading
        
        // 优先级1: Documents目录（已下载）
        if let audioPath = word.exampleAudioPath, !audioPath.isEmpty {
            let fullPath = getDocumentsDirectory().appendingPathComponent(audioPath)
            if FileManager.default.fileExists(atPath: fullPath.path) {
                print("📁 从 Documents 加载音频: \(audioPath)")
                loadAudio(from: fullPath, source: .documents)
                return
            }
        }
        
        // 优先级2: Bundle资源（单词名.aiff）
        let bundlePaths = [
            Bundle.main.path(forResource: word.word, ofType: "aiff"),
            Bundle.main.path(forResource: word.word.lowercased(), ofType: "aiff"),
            Bundle.main.path(forResource: word.word, ofType: "mp3"),
            Bundle.main.path(forResource: word.word.lowercased(), ofType: "mp3"),
            Bundle.main.path(forResource: word.word, ofType: "wav"),
            Bundle.main.path(forResource: word.word.lowercased(), ofType: "wav")
        ].compactMap { $0 }
        
        for path in bundlePaths {
            if FileManager.default.fileExists(atPath: path) {
                print("📦 从 Bundle 加载音频: \(path)")
                loadAudio(from: URL(fileURLWithPath: path), source: .bundle)
                return
            }
        }
        
        // 优先级3: Data/audio-examples/ 目录
        let examplesDir = getAudioExamplesDirectory()
        let exampleFiles = [
            "\(word.word).aiff",
            "\(word.word.lowercased()).aiff",
            "\(word.word).mp3",
            "\(word.word.lowercased()).mp3"
        ]
        
        for file in exampleFiles {
            let filePath = examplesDir.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: filePath.path) {
                print("🎵 从 audio-examples 加载音频: \(file)")
                loadAudio(from: filePath, source: .audioExamples)
                return
            }
        }
        
        // 优先级4: 在线URL
        if let audioUrl = word.audioUrl, let url = URL(string: audioUrl) {
            print("🌐 尝试加载在线音频: \(url)")
            loadOnlineAudio(from: url, word: word)
            return
        }
        
        // 优先级5: TTS降级
        print("🔊 使用 TTS 降级")
        loadTTS(for: word)
    }
    
    /// 从本地文件加载音频
    private func loadAudio(from url: URL, source: AudioSource) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.enableRate = true
            audioPlayer?.rate = playbackSpeed
            
            totalDuration = audioPlayer?.duration ?? 0
            currentState = .paused
            currentAudioSource = source
            
            // 更新队列项的音频来源
            if var item = currentItem {
                item.audioSource = source
                currentItem = item
                if let index = queue.firstIndex(where: { $0.id == item.id }) {
                    queue[index].audioSource = source
                }
            }
            
            updateNowPlayingInfo()
            print("✅ 音频加载成功: \(url.lastPathComponent), 时长: \(totalDuration.formatted)")
        } catch {
            print("❌ 加载音频失败: \(error)")
            currentState = .error("无法加载音频: \(error.localizedDescription)")
        }
    }
    
    /// 加载在线音频
    private func loadOnlineAudio(from url: URL, word: WordEntity) {
        // 下载并缓存音频
        let task = URLSession.shared.downloadTask(with: url) { [weak self] location, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 下载在线音频失败: \(error)")
                    self?.loadTTS(for: word)
                    return
                }
                
                guard let location = location else {
                    print("❌ 在线音频下载位置为空")
                    self?.loadTTS(for: word)
                    return
                }
                
                // 移动到临时目录
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent("\(word.word)_online.mp3")
                
                do {
                    if FileManager.default.fileExists(atPath: tempFile.path) {
                        try FileManager.default.removeItem(at: tempFile)
                    }
                    try FileManager.default.moveItem(at: location, to: tempFile)
                    self?.loadAudio(from: tempFile, source: .online)
                } catch {
                    print("❌ 移动下载文件失败: \(error)")
                    self?.loadTTS(for: word)
                }
            }
        }
        task.resume()
    }
    
    /// 使用 TTS 播放
    private func loadTTS(for word: WordEntity?) {
        guard let word = word else { return }
        
        currentAudioSource = .tts
        currentState = .playing  // TTS直接开始播放
        
        // 更新队列项
        if var item = currentItem {
            item.audioSource = .tts
            currentItem = item
            if let index = queue.firstIndex(where: { $0.id == item.id }) {
                queue[index].audioSource = .tts
            }
        }
        
        // 预估TTS时长
        totalDuration = Double(word.word.count) * 0.25 + 0.5
        
        updateNowPlayingInfo()
        speakWithTTS(word: word)
        
        print("🔊 TTS 播放: \(word.word)")
    }
    
    /// TTS语音合成
    private func speakWithTTS(word: WordEntity) {
        ttsSynthesizer.stopSpeaking(at: .immediate)
        
        // 构建朗读内容：单词 + 释义
        var textToSpeak = word.word
        if let meaning = word.meaning, !meaning.isEmpty {
            // 简化释义，只取主要部分
            let simplifiedMeaning = meaning.components(separatedBy: "；").first ?? meaning
            textToSpeak += ", \(simplifiedMeaning)"
        }
        
        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.4  // 较慢语速
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        ttsSynthesizer.speak(utterance)
    }
    
    // MARK: - 播放控制
    
    /// 播放
    func play() {
        // 如果是TTS模式
        if currentAudioSource == .tts {
            if !ttsSynthesizer.isSpeaking {
                if let word = currentItem?.word {
                    speakWithTTS(word: word)
                }
            } else {
                ttsSynthesizer.continueSpeaking()
            }
            currentState = .playing
            startProgressTimer()
            updateNowPlayingInfo()
            return
        }
        
        // 普通音频播放
        guard let player = audioPlayer else {
            if let word = currentItem?.word {
                loadAudio(for: word)
            }
            return
        }
        
        player.play()
        currentState = .playing
        startProgressTimer()
        updateNowPlayingInfo()
        print("▶️ 播放")
    }
    
    /// 暂停
    func pause() {
        if currentAudioSource == .tts {
            ttsSynthesizer.pauseSpeaking(at: .immediate)
        }
        
        audioPlayer?.pause()
        currentState = .paused
        stopProgressTimer()
        updateNowPlayingInfo()
        print("⏸️ 暂停")
    }
    
    /// 停止
    func stop() {
        ttsSynthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentState = .idle
        progress = 0
        currentTime = 0
        stopProgressTimer()
        updateNowPlayingInfo()
    }
    
    /// 跳转到指定位置
    func seek(to time: TimeInterval) {
        guard currentAudioSource != .tts else { return }  // TTS不支持跳转
        
        guard let player = audioPlayer else { return }
        player.currentTime = min(max(0, time), player.duration)
        currentTime = player.currentTime
        progress = player.duration > 0 ? player.currentTime / player.duration : 0
        updateNowPlayingInfo()
    }
    
    /// 下一首
    func nextTrack() {
        guard !queue.isEmpty else { return }
        
        // 更新当前项的播放统计
        if currentItem != nil {
            updateCurrentItemStats()
        }
        
        // 确定下一首
        let nextIndex: Int
        switch playbackMode {
        case .sequential:
            nextIndex = (currentIndex + 1) % queue.count
            
        case .random:
            nextIndex = Int.random(in: 0..<queue.count)
            
        case .spaced:
            // 更新优先级并重新排序
            sortQueueBySpacedRepetition()
            nextIndex = 0
        }
        
        currentIndex = nextIndex
        currentItem = queue[nextIndex]
        
        if let word = currentItem?.word {
            loadAudio(for: word)
            play()
            onTrackChanged?(currentItem!)
        }
        
        print("⏭️ 下一首: \(currentItem?.word.word ?? "未知")")
    }
    
    /// 上一首
    func previousTrack() {
        guard !queue.isEmpty else { return }
        
        // 更新当前项的播放统计
        if currentItem != nil {
            updateCurrentItemStats()
        }
        
        let prevIndex = (currentIndex - 1 + queue.count) % queue.count
        currentIndex = prevIndex
        currentItem = queue[prevIndex]
        
        if let word = currentItem?.word {
            loadAudio(for: word)
            play()
            onTrackChanged?(currentItem!)
        }
        
        print("⏮️ 上一首: \(currentItem?.word.word ?? "未知")")
    }
    
    /// 跳转到指定项
    func jumpToItem(at index: Int) {
        guard queue.indices.contains(index) else { return }
        
        // 更新当前项统计
        if currentItem != nil {
            updateCurrentItemStats()
        }
        
        currentIndex = index
        currentItem = queue[index]
        
        if let word = currentItem?.word {
            loadAudio(for: word)
            play()
            onTrackChanged?(currentItem!)
        }
        
        print("⏯️ 跳转到: \(currentItem?.word.word ?? "未知") [\(index)]")
    }
    
    /// 更新当前项播放统计
    private func updateCurrentItemStats() {
        guard var item = currentItem else { return }
        item.playCount += 1
        item.lastPlayed = Date()
        currentItem = item
        
        if let index = queue.firstIndex(where: { $0.id == item.id }) {
            queue[index].playCount = item.playCount
            queue[index].lastPlayed = item.lastPlayed
        }
    }
    
    /// 切换播放速度
    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed
        audioPlayer?.rate = speed
        updateNowPlayingInfo()
    }
    
    // MARK: - 进度管理
    
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        if currentAudioSource == .tts {
            // TTS进度模拟
            currentTime += 0.1
            if currentTime >= totalDuration {
                progress = 1.0
                ttsDidFinish()
            } else {
                progress = currentTime / totalDuration
            }
            return
        }
        
        guard let player = audioPlayer else { return }
        
        currentTime = player.currentTime
        totalDuration = player.duration
        progress = player.duration > 0 ? player.currentTime / player.duration : 0
        
        updateNowPlayingInfo()
    }
    
    /// TTS完成处理
    private func ttsDidFinish() {
        stopProgressTimer()
        currentState = .finished
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.nextTrack()
        }
    }
    
    // MARK: - Now Playing 信息更新（锁屏显示）
    
    private func updateNowPlayingInfo() {
        guard let item = currentItem else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        let word = item.word
        
        // 构建标题和艺术家信息
        var title = word.word
        var artist = word.phonetic ?? ""
        
        // 如果有释义，添加到艺术家信息
        if let meaning = word.meaning, !meaning.isEmpty {
            let simplifiedMeaning = meaning.components(separatedBy: "；").first ?? meaning
            artist = artist.isEmpty ? simplifiedMeaning : "\(artist) - \(simplifiedMeaning)"
        }
        
        // 添加音频来源标识
        let sourceIcon: String
        switch item.audioSource {
        case .documents: sourceIcon = "📁"
        case .bundle: sourceIcon = "📦"
        case .audioExamples: sourceIcon = "🎵"
        case .online: sourceIcon = "🌐"
        case .tts: sourceIcon = "🔊"
        case .unknown: sourceIcon = ""
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "\(sourceIcon) \(title)",
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyAlbumTitle: "EarWords 磨耳朵 (\(currentIndex + 1)/\(queue.count))",
            MPNowPlayingInfoPropertyPlaybackRate: currentState == .playing ? playbackSpeed : 0,
            MPMediaItemPropertyPlaybackDuration: totalDuration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime
        ]
        
        // 如果有例句，添加到作曲家字段
        if let example = word.example, !example.isEmpty {
            info[MPMediaItemPropertyComposer] = example
        }
        
        // 添加专辑封面
        let artworkImage = generateArtwork(for: word)
        let artwork = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in artworkImage }
        info[MPMediaItemPropertyArtwork] = artwork
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    /// 生成锁屏封面
    private func generateArtwork(for word: WordEntity) -> UIImage {
        let size = CGSize(width: 400, height: 400)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        // 根据音频来源选择渐变色
        let colors: [CGColor]
        switch currentAudioSource {
        case .documents:
            colors = [UIColor.systemBlue.cgColor, UIColor.systemIndigo.cgColor]
        case .bundle:
            colors = [UIColor.systemPurple.cgColor, UIColor.systemPink.cgColor]
        case .audioExamples:
            colors = [UIColor.systemGreen.cgColor, UIColor.systemTeal.cgColor]
        case .online:
            colors = [UIColor.systemOrange.cgColor, UIColor.systemRed.cgColor]
        case .tts:
            colors = [UIColor.systemGray.cgColor, UIColor.systemGray2.cgColor]
        case .unknown:
            colors = [UIColor.purple.cgColor, UIColor.blue.cgColor]
        }
        
        // 绘制渐变背景
        let context = UIGraphicsGetCurrentContext()!
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors as CFArray,
                                  locations: [0, 1])!
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: size.width, y: size.height),
                                   options: [])
        
        // 绘制装饰圆环
        let circlePath = UIBezierPath(arcCenter: CGPoint(x: size.width/2, y: size.height/2 - 20),
                                      radius: 120,
                                      startAngle: 0,
                                      endAngle: .pi * 2,
                                      clockwise: true)
        circlePath.lineWidth = 4
        UIColor.white.withAlphaComponent(0.3).setStroke()
        circlePath.stroke()
        
        // 绘制单词文本
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 52, weight: .bold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        let textSize = word.word.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2 - 20,
            width: textSize.width,
            height: textSize.height
        )
        word.word.draw(in: textRect, withAttributes: attributes)
        
        // 绘制音标
        if let phonetic = word.phonetic {
            let phoneticAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .paragraphStyle: paragraphStyle
            ]
            let phoneticSize = phonetic.size(withAttributes: phoneticAttributes)
            let phoneticRect = CGRect(
                x: (size.width - phoneticSize.width) / 2,
                y: textRect.maxY + 16,
                width: phoneticSize.width,
                height: phoneticSize.height
            )
            phonetic.draw(in: phoneticRect, withAttributes: phoneticAttributes)
        }
        
        // 绘制来源标识
        let sourceText: String
        switch currentAudioSource {
        case .documents: sourceText = "本地音频"
        case .bundle: sourceText = "内置音频"
        case .audioExamples: sourceText = "示例音频"
        case .online: sourceText = "在线音频"
        case .tts: sourceText = "语音合成"
        case .unknown: sourceText = ""
        }
        
        if !sourceText.isEmpty {
            let sourceAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6),
                .paragraphStyle: paragraphStyle
            ]
            let sourceSize = sourceText.size(withAttributes: sourceAttributes)
            let sourceRect = CGRect(
                x: (size.width - sourceSize.width) / 2,
                y: size.height - 50,
                width: sourceSize.width,
                height: sourceSize.height
            )
            sourceText.draw(in: sourceRect, withAttributes: sourceAttributes)
        }
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    // MARK: - 工具方法
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private func getAudioExamplesDirectory() -> URL {
        // 首先尝试Bundle中的Data/audio-examples
        let bundlePath = Bundle.main.bundleURL.appendingPathComponent("Data/audio-examples")
        if FileManager.default.fileExists(atPath: bundlePath.path) {
            return bundlePath
        }
        
        // 尝试其他可能的路径
        let possiblePaths = [
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("audio-examples"),
            URL(fileURLWithPath: "/Users/nutllwhy/.openclaw/workspace/plans/earwords/data/audio-examples")
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }
        
        return bundlePath  // 默认返回bundle路径
    }
    
    /// 设置播放模式
    func setPlaybackMode(_ mode: PlaybackMode) {
        guard playbackMode != mode else { return }
        
        playbackMode = mode
        
        // 保存当前播放项
        let currentItemId = currentItem?.id
        
        // 重新排序队列
        switch mode {
        case .sequential:
            // 按 ID 排序恢复原始顺序
            queue.sort { $0.word.id < $1.word.id }
            
        case .random:
            queue.shuffle()
            
        case .spaced:
            sortQueueBySpacedRepetition()
        }
        
        // 更新当前索引
        if let id = currentItemId,
           let newIndex = queue.firstIndex(where: { $0.id == id }) {
            currentIndex = newIndex
        }
        
        print("🔄 播放模式切换为: \(mode.rawValue)")
    }
    
    /// 清空队列
    func clearQueue() {
        stop()
        queue.removeAll()
        originalQueue.removeAll()
        currentItem = nil
        currentIndex = 0
    }
    
    /// 获取播放统计
    func getPlaybackStats() -> PlaybackStats {
        let totalWords = queue.count
        let totalPlayCount = queue.reduce(0) { $0 + $1.playCount }
        let avgPriority = queue.isEmpty ? 0 : queue.reduce(0.0) { $0 + $1.priority } / Double(queue.count)
        
        return PlaybackStats(
            totalWords: totalWords,
            totalPlayCount: totalPlayCount,
            averagePriority: avgPriority,
            audioSourceBreakdown: getAudioSourceBreakdown()
        )
    }
    
    /// 获取音频来源分布
    private func getAudioSourceBreakdown() -> [AudioSource: Int] {
        var breakdown: [AudioSource: Int] = [:]
        for item in queue {
            breakdown[item.audioSource, default: 0] += 1
        }
        return breakdown
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        currentState = .finished
        
        // 更新当前项统计
        if currentItem != nil {
            updateCurrentItemStats()
        }
        
        // 自动播放下一首
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.nextTrack()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        currentState = .error(error?.localizedDescription ?? "解码错误")
        print("❌ 音频解码错误: \(error?.localizedDescription ?? "未知")")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioPlayerManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if currentAudioSource == .tts {
            ttsDidFinish()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if currentAudioSource == .tts {
            stopProgressTimer()
        }
    }
}

// MARK: - 播放统计

struct PlaybackStats {
    let totalWords: Int
    let totalPlayCount: Int
    let averagePriority: Double
    let audioSourceBreakdown: [AudioSource: Int]
}

// MARK: - 辅助扩展

extension TimeInterval {
    var formatted: String {
        guard self.isFinite && self >= 0 else { return "0:00" }
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
