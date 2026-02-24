//
//  WordCardView.swift
//  EarWords
//
//  单词卡片组件 - 深色模式适配版
//

import SwiftUI

struct WordCardView: View {
    let word: WordEntity
    @EnvironmentObject var settings: UserSettingsViewModel
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showMeaning = false
    @State private var showExample = false
    @State private var isFlipped = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 顶部：章节标签
            HStack {
                Text(word.chapter)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                Spacer()
                
                // 难度指示
                DifficultyBadge(difficulty: Int(word.difficulty), colorScheme: colorScheme)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 主要内容区
            VStack(spacing: 16) {
                // 单词
                Text(word.word)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .multilineTextAlignment(.center)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                
                // 音标
                if settings.showPhonetic, let phonetic = word.phonetic, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.system(size: 20, design: .serif))
                        .foregroundColor(.secondary)
                }
                
                // 词性
                if let pos = word.pos, !pos.isEmpty {
                    Text(pos)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // 可展开区域
            VStack(spacing: 16) {
                if showMeaning {
                    VStack(spacing: 8) {
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                        Text(word.meaning)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                if showExample, settings.showExample, let example = word.example, !example.isEmpty {
                    VStack(spacing: 8) {
                        Divider()
                            .background(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                        Text(example)
                            .font(.body)
                            .italic()
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        // 播放例句音频按钮
                        AudioPlayButton(wordId: Int(word.id), colorScheme: colorScheme)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            
            Spacer()
            
            // 底部控制区
            HStack(spacing: 20) {
                // 显示释义按钮
                ActionButton(
                    title: showMeaning ? "隐藏释义" : "显示释义",
                    icon: showMeaning ? "eye.slash" : "eye",
                    color: .blue,
                    colorScheme: colorScheme
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showMeaning.toggle()
                        if !showMeaning {
                            showExample = false
                        }
                    }
                }
                
                // 显示例句按钮
                ActionButton(
                    title: showExample ? "隐藏例句" : "显示例句",
                    icon: showExample ? "text.bubble" : "text.bubble.fill",
                    color: .green,
                    colorScheme: colorScheme
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showExample.toggle()
                        if showExample && !showMeaning {
                            showMeaning = true
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .clear : .black.opacity(0.1),
                    radius: 20, x: 0, y: 10
                )
        )
        .padding(.horizontal, 20)
        .onAppear {
            // 根据设置自动播放音频
            if settings.audioAutoPlay {
                // 延迟播放以完成视图加载动画
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    AudioPlayerManager.shared.loadAudio(for: word)
                    AudioPlayerManager.shared.play()
                }
            }
        }
    }
}

// MARK: - 子组件

struct DifficultyBadge: View {
    let difficulty: Int
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { level in
                Circle()
                    .fill(level <= difficulty ? 
                          Color.orange : 
                          (colorScheme == .dark ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3)))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let colorScheme: ColorScheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(color.opacity(colorScheme == .dark ? 0.2 : 0.1))
            .cornerRadius(12)
        }
    }
}

struct AudioPlayButton: View {
    let wordId: Int
    let colorScheme: ColorScheme
    @State private var isPlaying = false
    
    var body: some View {
        Button(action: {
            // 播放音频逻辑
            isPlaying.toggle()
        }) {
            HStack {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                Text(isPlaying ? "暂停" : "播放例句")
                    .font(.subheadline)
            }
            .foregroundColor(.purple)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.purple.opacity(colorScheme == .dark ? 0.2 : 0.1))
            .cornerRadius(20)
        }
    }
}

// MARK: - 预览

struct WordCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WordCardView(word: mockWord)
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            WordCardView(word: mockWord)
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
        .environmentObject(UserSettingsViewModel.shared)
    }
    
    static var mockWord: WordEntity {
        let word = WordEntity()
        word.id = 1
        word.word = "atmosphere"
        word.phonetic = "/ˈætməsˌfɪr/"
        word.pos = "n."
        word.meaning = "大气层；氛围"
        word.example = "The approaching examination created a tense atmosphere on the campus"
        word.chapter = "01_自然地理"
        word.difficulty = 1
        return word
    }
}
