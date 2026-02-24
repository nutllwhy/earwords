//
//  AudioPlayerView.swift
//  EarWords
//
//  音频播放器视图 - 含TTS降级提示和设置
//

import SwiftUI
import AVFoundation

// MARK: - TTS设置模型
struct TTSSettings: Codable {
    var speechRate: Float      // 语速 0.1-1.0
    var pitchMultiplier: Float // 音调 0.5-2.0
    var voiceIdentifier: String // 音色标识
    
    static let `default` = TTSSettings(
        speechRate: 0.4,
        pitchMultiplier: 1.0,
        voiceIdentifier: "com.apple.ttsbundle.Samantha-compact"
    )
    
    static let availableVoices: [(id: String, name: String, language: String)] = [
        ("com.apple.ttsbundle.Samantha-compact", "Samantha", "en-US"),
        ("com.apple.ttsbundle.Daniel-compact", "Daniel", "en-GB"),
        ("com.apple.ttsbundle.Alex-compact", "Alex", "en-US"),
        ("com.apple.ttsbundle.Victoria-compact", "Victoria", "en-US"),
        ("com.apple.ttsbundle.Fred-compact", "Fred", "en-US"),
        ("com.apple.ttsbundle.Siri_Male_en-US_compact", "Siri 男声", "en-US"),
        ("com.apple.ttsbundle.Siri_Female_en-US_compact", "Siri 女声", "en-US")
    ]
}

// MARK: - TTS设置管理器
class TTSSettingsManager: ObservableObject {
    static let shared = TTSSettingsManager()
    
    @Published var settings: TTSSettings {
        didSet {
            saveSettings()
        }
    }
    
    private let settingsKey = "tts_settings"
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let saved = try? JSONDecoder().decode(TTSSettings.self, from: data) {
            self.settings = saved
        } else {
            self.settings = .default
        }
    }
    
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
    
    func resetToDefault() {
        settings = .default
    }
}

// MARK: - 音频播放器视图
struct AudioPlayerView: View {
    @StateObject private var audioManager = AudioPlayerManager.shared
    @StateObject private var ttsManager = TTSSettingsManager.shared
    @State private var showTTSSettings = false
    @State private var showTTSIndicator = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            // TTS降级提示
            if showTTSIndicator || audioManager.currentAudioSource == .tts {
                TTSDowngradeBanner {
                    showTTSSettings = true
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // 播放进度
            VStack(spacing: 8) {
                Slider(value: Binding(
                    get: { audioManager.progress },
                    set: { newValue in
                        audioManager.seek(to: newValue * audioManager.totalDuration)
                    }
                ), in: 0...1)
                .tint(ThemeManager.shared.primary)
                
                HStack {
                    Text(formatTime(audioManager.currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // 音频来源指示
                    AudioSourceBadge(source: audioManager.currentAudioSource)
                    
                    Spacer()
                    
                    Text(formatTime(audioManager.totalDuration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 播放控制按钮
            HStack(spacing: 40) {
                // 播放模式
                Button(action: togglePlaybackMode) {
                    Image(systemName: playbackModeIcon)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                // 上一首
                Button(action: { audioManager.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                }
                
                // 播放/暂停
                Button(action: togglePlayPause) {
                    ZStack {
                        Circle()
                            .fill(ThemeManager.shared.primary)
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: audioManager.currentState == .playing ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                
                // 下一首
                Button(action: { audioManager.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                }
                
                // 播放速度
                Button(action: showSpeedOptions) {
                    Text("\(String(format: "%.1f", audioManager.playbackSpeed))x")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }
            }
            
            // 当前播放单词信息
            if let item = audioManager.currentItem {
                VStack(spacing: 8) {
                    Text(item.word.word)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    
                    if let phonetic = item.word.phonetic {
                        Text(phonetic)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.systemBackground))
                .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .sheet(isPresented: $showTTSSettings) {
            TTSSettingsView()
        }
        .onChange(of: audioManager.currentAudioSource) { source in
            withAnimation(.easeInOut(duration: 0.3)) {
                showTTSIndicator = (source == .tts)
            }
            
            // 3秒后自动隐藏提示
            if source == .tts {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showTTSIndicator = false
                    }
                }
            }
        }
    }
    
    private var playbackModeIcon: String {
        switch audioManager.playbackMode {
        case .sequential: return "arrow.right"
        case .random: return "shuffle"
        case .spaced: return "brain.head.profile"
        }
    }
    
    private func togglePlayPause() {
        if audioManager.currentState == .playing {
            audioManager.pause()
        } else {
            audioManager.play()
        }
    }
    
    private func togglePlaybackMode() {
        let modes: [PlaybackMode] = [.sequential, .random, .spaced]
        if let currentIndex = modes.firstIndex(of: audioManager.playbackMode) {
            let nextIndex = (currentIndex + 1) % modes.count
            audioManager.setPlaybackMode(modes[nextIndex])
        }
    }
    
    private func showSpeedOptions() {
        // 循环切换速度: 0.5 -> 0.8 -> 1.0 -> 1.2 -> 1.5 -> 2.0 -> 0.5
        let speeds: [Float] = [0.5, 0.8, 1.0, 1.2, 1.5, 2.0]
        if let currentIndex = speeds.firstIndex(of: audioManager.playbackSpeed) {
            let nextIndex = (currentIndex + 1) % speeds.count
            audioManager.setPlaybackSpeed(speeds[nextIndex])
        } else {
            audioManager.setPlaybackSpeed(1.0)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite && time >= 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - TTS降级提示横幅
struct TTSDowngradeBanner: View {
    let onSettingsTap: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 语音合成图标
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                    .symbolEffect(.bounce, options: .repeating, value: isAnimating)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("正在使用语音合成")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text("本地/在线音频不可用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - 音频来源徽章
struct AudioSourceBadge: View {
    let source: AudioSource
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption2)
            Text(sourceText)
                .font(.caption2)
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(badgeColor.opacity(0.15))
        .cornerRadius(8)
    }
    
    private var iconName: String {
        switch source {
        case .documents: return "folder.fill"
        case .bundle: return "cube.fill"
        case .audioExamples: return "music.note"
        case .online: return "icloud.fill"
        case .tts: return "waveform"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var sourceText: String {
        switch source {
        case .documents: return "本地"
        case .bundle: return "内置"
        case .audioExamples: return "示例"
        case .online: return "在线"
        case .tts: return "TTS"
        case .unknown: return "未知"
        }
    }
    
    private var badgeColor: Color {
        switch source {
        case .documents: return .blue
        case .bundle: return .purple
        case .audioExamples: return .green
        case .online: return .orange
        case .tts: return .pink
        case .unknown: return .gray
        }
    }
}

// MARK: - TTS设置视图
struct TTSSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = TTSSettingsManager.shared
    @State private var previewText = "Hello, this is a preview of the voice."
    @State private var isPreviewPlaying = false
    
    private let synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("语速")) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("慢")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(manager.settings.speechRate * 100))%")
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text("快")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $manager.settings.speechRate, in: 0.1...1.0, step: 0.05)
                            .tint(ThemeManager.shared.primary)
                    }
                }
                
                Section(header: Text("音调")) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("低")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1fx", manager.settings.pitchMultiplier))
                                .font(.caption.weight(.medium))
                            Spacer()
                            Text("高")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $manager.settings.pitchMultiplier, in: 0.5...2.0, step: 0.1)
                            .tint(ThemeManager.shared.primary)
                    }
                }
                
                Section(header: Text("音色")) {
                    Picker("选择声音", selection: $manager.settings.voiceIdentifier) {
                        ForEach(TTSSettings.availableVoices, id: \.id) { voice in
                            Text("\(voice.name) (\(voice.language))")
                                .tag(voice.id)
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                Section {
                    Button(action: playPreview) {
                        HStack {
                            Image(systemName: isPreviewPlaying ? "stop.circle.fill" : "play.circle.fill")
                            Text(isPreviewPlaying ? "停止预览" : "播放预览")
                        }
                        .foregroundColor(ThemeManager.shared.primary)
                    }
                    
                    Button(action: { manager.resetToDefault() }) {
                        Text("恢复默认设置")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("说明")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("语速影响朗读快慢", systemImage: "tortoise")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("音调改变声音高低", systemImage: "music.note")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("TTS在本地/在线音频不可用时自动启用", systemImage: "waveform")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("语音合成设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        synthesizer.stopSpeaking(at: .immediate)
                        dismiss()
                    }
                }
            }
            .onDisappear {
                synthesizer.stopSpeaking(at: .immediate)
            }
        }
    }
    
    private func playPreview() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isPreviewPlaying = false
            return
        }
        
        let utterance = AVSpeechUtterance(string: previewText)
        utterance.rate = manager.settings.speechRate
        utterance.pitchMultiplier = manager.settings.pitchMultiplier
        utterance.volume = 1.0
        
        // 查找选中的声音
        if let voice = AVSpeechSynthesisVoice(identifier: manager.settings.voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        synthesizer.speak(utterance)
        isPreviewPlaying = true
        
        // 监听完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isPreviewPlaying = false
        }
    }
}

// MARK: - 预览
struct AudioPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AudioPlayerView()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            AudioPlayerView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
        .padding()
    }
}
