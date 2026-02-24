//
//  AudioReviewView.swift
//  EarWords
//
//  磨耳朵 - 音频复习界面（深色模式适配版）
//

import SwiftUI
import AVFoundation
import Combine

struct AudioReviewView: View {
    @StateObject private var playerManager = AudioPlayerManager.shared
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var settings = UserSettingsViewModel.shared
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showWordInfo = false
    @State private var showPlaylistSheet = false
    @State private var selectedMode: PlaybackMode = .sequential
    @State private var isLoading = true
    @State private var useTTS = false
    @State private var ttsSynthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: colorScheme == .dark ?
                        [Color.purple.opacity(0.15), Color.blue.opacity(0.15)] :
                        [Color.purple.opacity(0.08), Color.blue.opacity(0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部模式选择
                    modeSelector
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // 播放器卡片
                            PlayerCard(
                                word: playerManager.currentItem?.word,
                                state: playerManager.currentState,
                                progress: playerManager.progress,
                                currentTime: playerManager.currentTime,
                                totalDuration: playerManager.totalDuration,
                                showInfo: showWordInfo,
                                colorScheme: colorScheme
                            )
                            
                            // 播放控制
                            PlaybackControls(
                                state: playerManager.currentState,
                                onPlayPause: { togglePlayback() },
                                onPrevious: { playerManager.previousTrack() },
                                onNext: { playerManager.nextTrack() },
                                onShowInfo: { showWordInfo.toggle() },
                                colorScheme: colorScheme
                            )
                            
                            // 播放列表预览
                            PlaylistPreview(
                                queue: playerManager.queue,
                                currentIndex: playerManager.currentIndex,
                                onSelect: { index in
                                    playerManager.jumpToItem(at: index)
                                },
                                onShowFull: { showPlaylistSheet = true },
                                colorScheme: colorScheme
                            )
                            
                            // 播放速度控制
                            SpeedControl(
                                currentSpeed: playerManager.playbackSpeed,
                                onChange: { speed in
                                    playerManager.setPlaybackSpeed(speed)
                                },
                                colorScheme: colorScheme
                            )
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("磨耳朵")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // 刷新按钮（间隔重复模式）
                        if selectedMode == .spaced {
                            Button(action: {
                                playerManager.refreshSpacedRepetitionQueue()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.purple)
                            }
                        }
                        
                        // 播放列表按钮
                        Button(action: { showPlaylistSheet = true }) {
                            Image(systemName: "list.bullet")
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
            .sheet(isPresented: $showPlaylistSheet) {
                PlaylistSheet(
                    queue: playerManager.queue,
                    currentIndex: playerManager.currentIndex,
                    onSelect: { index in
                        playerManager.jumpToItem(at: index)
                        showPlaylistSheet = false
                    },
                    colorScheme: colorScheme
                )
            }
            .onAppear {
                loadPlaylist()
                setupNotifications()
            }
            .onDisappear {
                playerManager.pause()
                ttsSynthesizer.stopSpeaking(at: .immediate)
            }
            .onChange(of: selectedMode) { newMode in
                playerManager.setPlaybackMode(newMode)
            }
        }
    }
    
    // MARK: - 视图组件
    
    private var modeSelector: some View {
        Picker("播放模式", selection: $selectedMode) {
            ForEach(PlaybackMode.allCases, id: \.self) { mode in
                Text(mode.rawValue)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
    }
    
    // MARK: - 方法
    
    private func loadPlaylist() {
        // 加载今日待复习单词
        let dueWords = dataManager.fetchDueWords(limit: Int(settings.dailyReviewGoal))
        
        if !dueWords.isEmpty {
            playerManager.setPlaylist(words: dueWords, mode: selectedMode)
            isLoading = false
        } else {
            // 如果没有待复习单词，加载一些新词
            let newWords = dataManager.fetchNewWords(limit: Int(settings.dailyNewWordsGoal))
            playerManager.setPlaylist(words: newWords, mode: selectedMode)
            isLoading = false
        }
    }
    
    private func setupNotifications() {
        // 监听 TTS 降级通知
        NotificationCenter.default.addObserver(
            forName: .init("UseTTSForWord"),
            object: nil,
            queue: .main
        ) { notification in
            if let word = notification.object as? WordEntity {
                speakWithTTS(word: word)
            }
        }
    }
    
    private func togglePlayback() {
        switch playerManager.currentState {
        case .playing:
            playerManager.pause()
            ttsSynthesizer.pauseSpeaking(at: .immediate)
        case .paused, .idle, .finished:
            if case .error("TTS_FALLBACK") = playerManager.currentState {
                if let word = playerManager.currentItem?.word {
                    speakWithTTS(word: word)
                }
            } else {
                playerManager.play()
            }
        case .error:
            // 重试播放
            if let word = playerManager.currentItem?.word {
                playerManager.loadAudio(for: word)
                playerManager.play()
            }
        case .loading:
            break
        }
    }
    
    private func speakWithTTS(word: WordEntity) {
        let utterance = AVSpeechUtterance(string: word.word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        // 应用语速设置
        utterance.rate = Float(settings.speechRate * 0.5) // TTS 语速范围不同
        utterance.pitchMultiplier = 1.0
        
        ttsSynthesizer.speak(utterance)
        
        // 播放完成后自动下一首
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak playerManager] in
            playerManager?.nextTrack()
        }
    }
}

// MARK: - 播放器卡片

struct PlayerCard: View {
    let word: WordEntity?
    let state: PlayerState
    let progress: Double
    let currentTime: TimeInterval
    let totalDuration: TimeInterval
    let showInfo: Bool
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // 专辑封面
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark ?
                                [Color.purple.opacity(0.7), Color.blue.opacity(0.7)] :
                                [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 220, height: 220)
                    .shadow(color: .purple.opacity(colorScheme == .dark ? 0.2 : 0.3), radius: 20, x: 0, y: 10)
                
                if state == .playing {
                    AudioWaveform(colorScheme: colorScheme)
                } else if state == .loading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                } else {
                    Image(systemName: state == .error("TTS_FALLBACK") ? "speaker.wave.2" : "headphones")
                        .font(.system(size: 70))
                        .foregroundColor(.white)
                }
                
                // 状态指示器
                if case .error(let message) = state, message != "TTS_FALLBACK" {
                    VStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.yellow)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.bottom, 16)
                }
            }
            .padding(.top, 20)
            
            // 单词信息
            VStack(spacing: 12) {
                Text(word?.word ?? "准备播放")
                    .font(.system(size: 36, weight: .bold))
                    .lineLimit(1)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                
                if let phonetic = word?.phonetic, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                if showInfo, let meaning = word?.meaning {
                    Text(meaning)
                        .font(.title3)
                        .foregroundColor(.purple)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                if let example = word?.example, showInfo {
                    Text(example)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.3), value: showInfo)
            
            // 进度条
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.2))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: colorScheme == .dark ?
                                        [Color.purple.opacity(0.8), Color.blue.opacity(0.8)] :
                                        [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geometry.size.width * progress), height: 4)
                        
                        // 进度指示器
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 12, height: 12)
                            .position(
                                x: max(6, min(geometry.size.width - 6, geometry.size.width * progress)),
                                y: 2
                            )
                            .shadow(radius: 2)
                    }
                }
                .frame(height: 12)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newProgress = max(0, min(1, value.location.x / UIScreen.main.bounds.width))
                            AudioPlayerManager.shared.seek(to: totalDuration * Double(newProgress))
                        }
                )
                
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text(formatTime(totalDuration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.systemBackground))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.15 : 0.08), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 20)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 音频波形动画

struct AudioWaveform: View {
    let colorScheme: ColorScheme
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
                    .frame(width: 8, height: animating ? 50 : 20)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - 播放控制

struct PlaybackControls: View {
    let state: PlayerState
    let onPlayPause: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onShowInfo: () -> Void
    let colorScheme: ColorScheme
    
    private var isPlaying: Bool {
        if case .playing = state { return true }
        return false
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 40) {
                // 上一首
                Button(action: onPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                        .frame(width: 60, height: 60)
                        .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color(.systemGray6))
                        .clipShape(Circle())
                }
                
                // 播放/暂停
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.purple)
                        .symbolRenderingMode(.hierarchical)
                }
                
                // 下一首
                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                        .frame(width: 60, height: 60)
                        .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            
            // 显示信息按钮
            Button(action: onShowInfo) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                    Text("显示释义")
                        .font(.subheadline)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color(.systemGray6))
                .cornerRadius(20)
            }
        }
    }
}

// MARK: - 播放列表预览

struct PlaylistPreview: View {
    let queue: [PlaybackQueueItem]
    let currentIndex: Int
    let onSelect: (Int) -> Void
    let onShowFull: () -> Void
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("播放列表 (\(queue.count) 词)")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                
                Spacer()
                
                Button(action: onShowFull) {
                    Text("查看全部")
                        .font(.subheadline)
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal)
            
            if queue.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无单词")
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(queue.prefix(10).enumerated()), id: \.element.id) { index, item in
                            PlaylistItem(
                                word: item.word,
                                isPlaying: index == currentIndex,
                                priority: item.priority,
                                playCount: item.playCount,
                                colorScheme: colorScheme
                            )
                            .onTapGesture {
                                onSelect(index)
                            }
                        }
                        
                        if queue.count > 10 {
                            Button(action: onShowFull) {
                                VStack {
                                    Text("+\(queue.count - 10)")
                                        .font(.headline)
                                        .foregroundColor(.purple)
                                    Text("更多")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 70, height: 70)
                                .background(Color.purple.opacity(colorScheme == .dark ? 0.2 : 0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.systemBackground))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.15 : 0.05), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - 播放列表项

struct PlaylistItem: View {
    let word: WordEntity
    let isPlaying: Bool
    let priority: Double
    let playCount: Int
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 6) {
            Text(word.word)
                .font(.subheadline.weight(isPlaying ? .bold : .medium))
                .foregroundColor(isPlaying ? .purple : (colorScheme == .dark ? .white : .primary))
                .lineLimit(1)
            
            if isPlaying {
                HStack(spacing: 3) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 4, height: 4)
                            .scaleEffect(isPlaying ? 1.0 : 0.5)
                    }
                }
            } else {
                // 显示优先级或播放次数
                HStack(spacing: 4) {
                    if priority > 1.5 {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    if playCount > 0 {
                        Text("\(playCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(width: 80, height: 70)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPlaying ? Color.purple.opacity(colorScheme == .dark ? 0.25 : 0.15) : 
                      (colorScheme == .dark ? Color.gray.opacity(0.3) : Color(.systemGray6)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isPlaying ? Color.purple : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - 播放列表详情 Sheet

struct PlaylistSheet: View {
    let queue: [PlaybackQueueItem]
    let currentIndex: Int
    let onSelect: (Int) -> Void
    let colorScheme: ColorScheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("当前队列共 \(queue.count) 个单词")) {
                    ForEach(Array(queue.enumerated()), id: \.element.id) { index, item in
                        PlaylistRow(
                            word: item.word,
                            isPlaying: index == currentIndex,
                            priority: item.priority,
                            playCount: item.playCount,
                            colorScheme: colorScheme
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelect(index)
                        }
                        .background(index == currentIndex ? Color.purple.opacity(colorScheme == .dark ? 0.15 : 0.05) : Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("播放列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 播放列表行

struct PlaylistRow: View {
    let word: WordEntity
    let isPlaying: Bool
    let priority: Double
    let playCount: Int
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // 播放状态指示
            ZStack {
                Circle()
                    .fill(isPlaying ? Color.purple : (colorScheme == .dark ? Color.gray.opacity(0.3) : Color(.systemGray5)))
                    .frame(width: 32, height: 32)
                
                if isPlaying {
                    AudioWaveformMini()
                } else {
                    Image(systemName: "speaker")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 单词信息
            VStack(alignment: .leading, spacing: 4) {
                Text(word.word)
                    .font(.body.weight(isPlaying ? .semibold : .regular))
                    .foregroundColor(isPlaying ? .purple : (colorScheme == .dark ? .white : .primary))
                
                if let meaning = word.meaning {
                    Text(meaning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 优先级和播放次数
            VStack(alignment: .trailing, spacing: 4) {
                if priority > 1.0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f", priority))
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
                
                if playCount > 0 {
                    Text("已播\(playCount)次")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 迷你音频波形

struct AudioWaveformMini: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.purple)
                    .frame(width: 3, height: animating ? 12 : 6)
                    .animation(
                        Animation.easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

// MARK: - 播放速度控制

struct SpeedControl: View {
    let currentSpeed: Float
    let onChange: (Float) -> Void
    let colorScheme: ColorScheme
    
    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    
    var body: some View {
        VStack(spacing: 12) {
            Text("播放速度")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                ForEach(speeds, id: \.self) { speed in
                    Button(action: { onChange(speed) }) {
                        Text("\(String(format: "%.2f", speed))x")
                            .font(.caption.weight(currentSpeed == speed ? .bold : .regular))
                            .foregroundColor(currentSpeed == speed ? .white : (colorScheme == .dark ? .white : .primary))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(currentSpeed == speed ? Color.purple : 
                                          (colorScheme == .dark ? Color.gray.opacity(0.3) : Color(.systemGray6)))
                            )
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.systemBackground))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.15 : 0.05), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - 预览

struct AudioReviewView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AudioReviewView()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            AudioReviewView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
