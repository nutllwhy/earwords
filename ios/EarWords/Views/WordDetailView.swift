//
//  WordDetailView.swift
//  EarWords
//
//  单词详情页 - 显示完整信息+音频播放
//

import SwiftUI
import AVFoundation

// MARK: - 单词详情视图

struct WordDetailView: View {
    let word: WordEntity
    
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullExample = false
    @State private var showAudioError = false
    @State private var audioErrorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 单词卡片
                WordHeaderCard(
                    word: word,
                    audioSource: audioManager.currentAudioSource,
                    isPlaying: isPlayingWord,
                    progress: audioManager.progress,
                    onPlay: { playWordPronunciation() }
                )
                
                // 学习状态卡片
                LearningStatusCard(word: word)
                
                // 释义卡片
                MeaningCard(word: word)
                
                // 例句卡片
                if let example = word.example, !example.isEmpty {
                    ExampleCard(
                        example: example,
                        word: word.word,
                        audioSource: audioManager.currentAudioSource,
                        isPlaying: isPlayingExample,
                        progress: audioManager.progress,
                        onPlay: { playExampleAudio() }
                    )
                }
                
                // 额外信息
                if let extra = word.extra, !extra.isEmpty {
                    ExtraInfoCard(extra: extra)
                }
                
                // 学习统计
                StudyStatsCard(word: word)
            }
            .padding()
        }
        .navigationTitle("单词详情")
        .navigationBarTitleDisplayMode(.inline)
        .alert("音频播放错误", isPresented: $showAudioError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(audioErrorMessage)
        }
        .onDisappear {
            // 离开页面时停止播放
            audioManager.stop()
        }
    }
    
    // MARK: - 播放状态
    
    private var isPlayingWord: Bool {
        audioManager.currentState == .playing && audioManager.currentAudioSource != .tts
    }
    
    private var isPlayingExample: Bool {
        audioManager.currentState == .playing
    }
    
    // MARK: - 播放单词发音
    
    private func playWordPronunciation() {
        // 如果正在播放，暂停
        if audioManager.currentState == .playing {
            audioManager.pause()
            return
        }
        
        // 加载并播放单词音频
        loadAndPlayWordAudio()
    }
    
    private func loadAndPlayWordAudio() {
        // 检查本地音频文件（优先级：Documents > Bundle > audio-examples）
        if let localURL = findLocalAudio(for: word.word) {
            audioManager.loadLocalAudio(from: localURL)
            return
        }
        
        // 检查在线音频
        if let audioUrl = word.audioUrl, !audioUrl.isEmpty {
            audioManager.playAudio(from: audioUrl)
            return
        }
        
        // 使用TTS作为降级方案
        audioManager.playTTS(text: word.word, word: word)
    }
    
    // MARK: - 播放例句音频
    
    private func playExampleAudio() {
        // 如果正在播放，暂停
        if audioManager.currentState == .playing {
            audioManager.pause()
            return
        }
        
        // 检查例句本地音频
        if let exampleAudioPath = word.exampleAudioPath, !exampleAudioPath.isEmpty {
            let documentsPath = getDocumentsDirectory().appendingPathComponent(exampleAudioPath)
            if FileManager.default.fileExists(atPath: documentsPath.path) {
                audioManager.loadLocalAudio(from: documentsPath)
                return
            }
        }
        
        // 检查在线音频
        if let audioUrl = word.audioUrl, !audioUrl.isEmpty {
            audioManager.playAudio(from: audioUrl)
            return
        }
        
        // 使用TTS播放例句
        if let example = word.example {
            audioManager.playTTS(text: example, word: word)
        } else {
            showAudioError(message: "没有找到例句音频")
        }
    }
    
    private func showAudioError(message: String) {
        audioErrorMessage = message
        showAudioError = true
    }
}

// MARK: - 单词头部卡片

struct WordHeaderCard: View {
    let word: WordEntity
    let audioSource: AudioSource
    let isPlaying: Bool
    let progress: Double
    let onPlay: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // 状态标签
            HStack {
                StatusBadge(status: word.status)
                Spacer()
                AudioSourceBadge(source: audioSource)
            }
            
            // 单词
            Text(word.word)
                .font(.system(size: 40, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
            
            // 音标和播放按钮
            if let phonetic = word.phonetic, !phonetic.isEmpty {
                HStack(spacing: 12) {
                    Text(phonetic)
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    // 播放按钮 + 波形动画
                    AudioPlayButton(
                        isPlaying: isPlaying,
                        progress: progress,
                        action: onPlay
                    )
                }
            } else {
                // 没有音标时，播放按钮在下方
                AudioPlayButton(
                    isPlaying: isPlaying,
                    progress: progress,
                    action: onPlay
                )
            }
            
            // 词性
            if let pos = word.pos, !pos.isEmpty {
                Text(pos)
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - 音频播放按钮（带动画）

struct AudioPlayButton: View {
    let isPlaying: Bool
    let progress: Double
    let action: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // 圆形背景
                Circle()
                    .fill(isPlaying ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                // 进度环
                if isPlaying {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)
                }
                
                // 播放图标或波形
                if isPlaying {
                    WaveformBars(isAnimating: $isAnimating)
                        .frame(width: 20, height: 20)
                        .onAppear { isAnimating = true }
                        .onDisappear { isAnimating = false }
                } else {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - 波形动画组件

struct WaveformBars: View {
    @Binding var isAnimating: Bool
    @State private var barHeights: [CGFloat] = [0.3, 0.6, 0.4, 0.8, 0.5]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.blue)
                    .frame(width: 3, height: 20 * barHeights[index])
                    .animation(
                        .easeInOut(duration: 0.3)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.05),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            startAnimation()
        }
        .onChange(of: isAnimating) { newValue in
            if newValue {
                startAnimation()
            }
        }
    }
    
    private func startAnimation() {
        for i in barHeights.indices {
            withAnimation(
                .easeInOut(duration: 0.3 + Double.random(in: 0.1...0.3))
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.05)
            ) {
                barHeights[i] = CGFloat.random(in: 0.2...1.0)
            }
        }
    }
}

// MARK: - 音频来源徽章

struct AudioSourceBadge: View {
    let source: AudioSource
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(.caption)
            Text(sourceText)
                .font(.caption.weight(.medium))
        }
        .foregroundColor(sourceColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(sourceColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    var sourceText: String {
        switch source {
        case .documents: return "本地"
        case .bundle: return "内置"
        case .audioExamples: return "示例"
        case .online: return "在线"
        case .tts: return "TTS"
        case .unknown: return ""
        }
    }
    
    var sourceColor: Color {
        switch source {
        case .documents: return .blue
        case .bundle: return .purple
        case .audioExamples: return .green
        case .online: return .orange
        case .tts: return .gray
        case .unknown: return .clear
        }
    }
    
    var iconName: String {
        switch source {
        case .documents: return "folder.fill"
        case .bundle: return "archivebox.fill"
        case .audioExamples: return "music.note"
        case .online: return "cloud.fill"
        case .tts: return "waveform"
        case .unknown: return ""
        }
    }
}

// MARK: - 按钮缩放样式

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 状态徽章

struct StatusBadge: View {
    let status: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption.weight(.medium))
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    var statusColor: Color {
        switch status {
        case "new": return .gray
        case "learning": return .blue
        case "mastered": return .green
        default: return .gray
        }
    }
    
    var statusText: String {
        switch status {
        case "new": return "未学习"
        case "learning": return "学习中"
        case "mastered": return "已掌握"
        default: return status
        }
    }
}

// MARK: - 学习状态卡片

struct LearningStatusCard: View {
    let word: WordEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习状态")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatusItem(
                    icon: "number.circle.fill",
                    value: "\(word.reviewCount)",
                    label: "复习次数"
                )
                
                StatusItem(
                    icon: "star.circle.fill",
                    value: String(format: "%.1f", word.easeFactor),
                    label: "简易度"
                )
                
                StatusItem(
                    icon: "clock.arrow.circlepath",
                    value: "\(word.interval)",
                    label: "间隔天数"
                )
            }
            
            if let nextReview = word.nextReviewDate {
                Divider()
                
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.orange)
                    
                    Text("下次复习: ")
                        .font(.subheadline)
                    
                    Text(nextReview, style: .date)
                        .font(.subheadline.weight(.medium))
                    
                    Spacer()
                    
                    if word.isDue {
                        Text("待复习")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

struct StatusItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(value)
                    .font(.title3.weight(.semibold))
            }
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 释义卡片

struct MeaningCard: View {
    let word: WordEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("释义")
                .font(.headline)
            
            Text(word.meaning)
                .font(.body)
                .lineSpacing(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - 例句卡片

struct ExampleCard: View {
    let example: String
    let word: String
    let audioSource: AudioSource
    let isPlaying: Bool
    let progress: Double
    let onPlay: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("例句")
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 8) {
                    AudioSourceBadge(source: audioSource)
                    
                    Button(action: onPlay) {
                        ZStack {
                            Circle()
                                .fill(isPlaying ? Color.blue.opacity(0.2) : Color.blue.opacity(0.1))
                                .frame(width: 36, height: 36)
                            
                            if isPlaying {
                                WaveformBars(isAnimating: .constant(true))
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            
            // 高亮显示目标单词的例句
            HighlightedText(text: example, highlight: word)
                .font(.body)
                .lineSpacing(6)
            
            // 播放进度条
            if isPlaying {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * progress, height: 4)
                            .animation(.linear(duration: 0.1), value: progress)
                    }
                }
                .frame(height: 4)
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - 高亮文本组件

struct HighlightedText: View {
    let text: String
    let highlight: String
    
    var body: some View {
        let lowerText = text.lowercased()
        let lowerHighlight = highlight.lowercased()
        
        if let range = lowerText.range(of: lowerHighlight) {
            let before = String(text[..<range.lowerBound])
            let match = String(text[range])
            let after = String(text[range.upperBound...])
            
            return Text(before) +
                   Text(match).foregroundColor(.blue).fontWeight(.semibold) +
                   Text(after)
        } else {
            return Text(text)
        }
    }
}

// MARK: - 额外信息卡片

struct ExtraInfoCard: View {
    let extra: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("补充信息")
                .font(.headline)
            
            Text(extra)
                .font(.body)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - 学习统计卡片

struct StudyStatsCard: View {
    let word: WordEntity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习统计")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatDetailItem(
                    icon: "checkmark.circle.fill",
                    value: "\(word.correctCount)",
                    label: "正确次数",
                    color: .green
                )
                
                StatDetailItem(
                    icon: "xmark.circle.fill",
                    value: "\(word.incorrectCount)",
                    label: "错误次数",
                    color: .red
                )
                
                StatDetailItem(
                    icon: "flame.fill",
                    value: "\(word.streak)",
                    label: "连续正确",
                    color: .orange
                )
            }
            
            // 准确率进度条
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("准确率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(word.accuracy * 100))%")
                        .font(.caption.weight(.semibold))
                }
                
                ProgressView(value: word.accuracy, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: accuracyColor))
                    .scaleEffect(y: 1.5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    var accuracyColor: Color {
        let acc = word.accuracy
        if acc >= 0.8 { return .green }
        if acc >= 0.5 { return .orange }
        return .red
    }
}

struct StatDetailItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 辅助方法

extension WordDetailView {
    /// 查找本地音频文件
    func findLocalAudio(for wordText: String) -> URL? {
        let fileManager = FileManager.default
        let documentsDir = getDocumentsDirectory()
        
        // 可能的音频文件名
        let audioFiles = [
            "\(wordText).aiff",
            "\(wordText.lowercased()).aiff",
            "\(wordText).mp3",
            "\(wordText.lowercased()).mp3",
            "\(wordText).wav",
            "\(wordText.lowercased()).wav"
        ]
        
        // 在Documents目录中查找
        for file in audioFiles {
            let fileURL = documentsDir.appendingPathComponent(file)
            if fileManager.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        
        // 在Bundle中查找
        for file in audioFiles {
            let fileName = (file as NSString).deletingPathExtension
            let ext = (file as NSString).pathExtension
            if let bundlePath = Bundle.main.path(forResource: fileName, ofType: ext) {
                return URL(fileURLWithPath: bundlePath)
            }
        }
        
        return nil
    }
    
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
}

// MARK: - 预览

struct WordDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Text("WordDetailView Preview")
    }
}
