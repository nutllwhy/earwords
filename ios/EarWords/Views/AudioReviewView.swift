//
//  AudioReviewView.swift
//  EarWords
//
//  磨耳朵 - 音频复习界面
//

import SwiftUI
import AVFoundation

struct AudioReviewView: View {
    @StateObject private var audioManager = AudioReviewManager()
    @State private var selectedMode: ReviewMode = .sequential
    @State private var isPlaying = false
    @State private var currentWordIndex = 0
    @State private var showWordInfo = false
    
    enum ReviewMode: String, CaseIterable {
        case sequential = "顺序播放"
        case random = "随机播放"
        case spaced = "间隔重复"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // 模式选择
                    Picker("播放模式", selection: $selectedMode) {
                        ForEach(ReviewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // 播放器卡片
                    PlayerCard(
                        word: audioManager.currentWord,
                        isPlaying: isPlaying,
                        progress: audioManager.playbackProgress,
                        showInfo: showWordInfo
                    )
                    
                    // 播放控制
                    PlaybackControls(
                        isPlaying: isPlaying,
                        onPlayPause: { togglePlayback() },
                        onPrevious: { previousWord() },
                        onNext: { nextWord() },
                        onShowInfo: { showWordInfo.toggle() }
                    )
                    
                    // 播放列表
                    PlaylistView(
                        words: audioManager.playlist,
                        currentIndex: currentWordIndex
                    )
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("磨耳朵")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { audioManager.shufflePlaylist() }) {
                        Image(systemName: "shuffle")
                    }
                }
            }
        }
    }
    
    private func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            audioManager.startPlayback()
        } else {
            audioManager.pausePlayback()
        }
    }
    
    private func nextWord() {
        currentWordIndex = min(currentWordIndex + 1, audioManager.playlist.count - 1)
        audioManager.moveToWord(at: currentWordIndex)
    }
    
    private func previousWord() {
        currentWordIndex = max(currentWordIndex - 1, 0)
        audioManager.moveToWord(at: currentWordIndex)
    }
}

// MARK: - 播放器卡片

struct PlayerCard: View {
    let word: WordEntity?
    let isPlaying: Bool
    let progress: Double
    let showInfo: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // 专辑封面效果
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                    .shadow(color: .purple.opacity(0.3), radius: 20, x: 0, y: 10)
                
                if isPlaying {
                    // 音频波形动画
                    AudioWaveform()
                } else {
                    Image(systemName: "headphones")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 20)
            
            // 单词信息
            VStack(spacing: 12) {
                Text(word?.word ?? "准备播放")
                    .font(.system(size: 32, weight: .bold))
                
                if let phonetic = word?.phonetic {
                    Text(phonetic)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                if showInfo, let meaning = word?.meaning {
                    Text(meaning)
                        .font(.title3)
                        .foregroundColor(.purple)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal)
            
            // 进度条
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.purple)
                            .frame(width: geometry.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text(formatTime(audioManager.currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatTime(audioManager.totalDuration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 32)
        }
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .cornerRadius(32)
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 20)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    @ObservedObject private var audioManager = AudioReviewManager()
}

// MARK: - 音频波形动画

struct AudioWaveform: View {
    @State private var animation = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 6, height: animation ? 40 : 20)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.1),
                        value: animation
                    )
            }
        }
        .onAppear { animation = true }
    }
}

// MARK: - 播放控制

struct PlaybackControls: View {
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onShowInfo: () -> Void
    
    var body: some View {
        HStack(spacing: 40) {
            // 上一个
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            // 播放/暂停
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.purple)
            }
            
            // 下一个
            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        
        // 显示信息按钮
        Button(action: onShowInfo) {
            Image(systemName: "text.bubble")
                .font(.title3)
                .foregroundColor(.secondary)
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(Circle())
        }
    }
}

// MARK: - 播放列表

struct PlaylistView: View {
    let words: [WordEntity]
    let currentIndex: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("播放列表 (\(words.count) 词)")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(words.enumerated()), id: \.element.id) { index, word in
                        PlaylistItem(
                            word: word,
                            isPlaying: index == currentIndex
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct PlaylistItem: View {
    let word: WordEntity
    let isPlaying: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(word.word)
                .font(.subheadline.weight(isPlaying ? .semibold : .regular))
                .foregroundColor(isPlaying ? .purple : .primary)
            
            if isPlaying {
                HStack(spacing: 2) {
                    ForEach(0..<3) { _ in
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 3, height: 3)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isPlaying ? Color.purple.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - 音频管理器

class AudioReviewManager: ObservableObject {
    @Published var playlist: [WordEntity] = []
    @Published var currentWord: WordEntity?
    @Published var playbackProgress: Double = 0
    @Published var currentTime: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var currentIndex = 0
    
    init() {
        loadPlaylist()
    }
    
    func loadPlaylist() {
        // 加载最近学习的单词
        // 暂时使用模拟数据
    }
    
    func startPlayback() {
        // 开始播放
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.updateProgress()
        }
    }
    
    func pausePlayback() {
        timer?.invalidate()
        timer = nil
    }
    
    func moveToWord(at index: Int) {
        currentIndex = index
        currentWord = playlist.indices.contains(index) ? playlist[index] : nil
    }
    
    func shufflePlaylist() {
        playlist.shuffle()
        currentIndex = 0
        currentWord = playlist.first
    }
    
    private func updateProgress() {
        // 更新播放进度
    }
}

struct AudioReviewView_Previews: PreviewProvider {
    static var previews: some View {
        AudioReviewView()
    }
}
