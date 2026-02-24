//
//  WordDetailView.swift
//  EarWords
//
//  单词详情页 - 显示完整信息+音频播放
//

import SwiftUI
import AVFoundation

struct WordDetailView: View {
    let word: WordEntity
    
    @StateObject private var audioManager = AudioPlayerManager.shared
    @State private var showFullExample = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 单词卡片
                WordHeaderCard(word: word)
                
                // 学习状态卡片
                LearningStatusCard(word: word)
                
                // 释义卡片
                MeaningCard(word: word)
                
                // 例句卡片
                if let example = word.example, !example.isEmpty {
                    ExampleCard(
                        example: example,
                        word: word.word,
                        isPlaying: audioManager.isPlaying,
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
    }
    
    private func playExampleAudio() {
        // 这里可以实现音频播放逻辑
        // 如果有在线音频URL，可以使用 AudioPlayerManager
        if let audioUrl = word.audioUrl, !audioUrl.isEmpty {
            audioManager.playAudio(from: audioUrl)
        }
    }
}

// MARK: - 单词头部卡片

struct WordHeaderCard: View {
    let word: WordEntity
    @State private var isPlaying = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 状态标签
            HStack {
                StatusBadge(status: word.status)
                Spacer()
            }
            
            // 单词
            Text(word.word)
                .font(.system(size: 40, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
            
            // 音标
            if let phonetic = word.phonetic, !phonetic.isEmpty {
                HStack(spacing: 8) {
                    Text(phonetic)
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    // 发音按钮
                    Button(action: { playPronunciation() }) {
                        Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.wave.2")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
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
    
    private func playPronunciation() {
        withAnimation {
            isPlaying = true
        }
        
        // 使用语音合成播放单词发音
        let utterance = AVSpeechUtterance(string: word.word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.4
        
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
        
        // 2秒后重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isPlaying = false
            }
        }
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
    let isPlaying: Bool
    let onPlay: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("例句")
                    .font(.headline)
                
                Spacer()
                
                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            // 高亮显示目标单词的例句
            HighlightedText(text: example, highlight: word)
                .font(.body)
                .lineSpacing(6)
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

struct WordDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // 预览需要实际的 WordEntity，这里省略
        Text("WordDetailView Preview")
    }
}
