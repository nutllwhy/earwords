//
//  AudioReviewView.swift
//  磨耳朵界面原型
//

import SwiftUI

struct AudioReviewView: View {
    @State private var isPlaying = false
    @State private var currentIndex = 0
    @State private var showWordInfo = false
    @State private var selectedMode = 0
    
    let modes = ["顺序", "随机", "间隔"]
    
    let words = [
        (word: "atmosphere", example: "The approaching examination created a tense atmosphere..."),
        (word: "hydrosphere", example: "All the water of the earth's surface is included in the hydrosphere..."),
        (word: "oxygen", example: "Hydrogen and Oxygen are gases..."),
        (word: "lion", example: "The lion is called the king of beasts..."),
        (word: "tiger", example: "The tiger is a fierce animal...")
    ]
    
    var currentWord: (word: String, example: String) {
        words[currentIndex]
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
                        ForEach(0..<modes.count, id: \.self) { index in
                            Text(modes[index]).tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // 播放器卡片
                    PlayerCard(
                        word: currentWord.word,
                        example: currentWord.example,
                        isPlaying: isPlaying,
                        showInfo: showWordInfo
                    )
                    
                    // 播放控制
                    PlaybackControls(
                        isPlaying: isPlaying,
                        onPlayPause: { isPlaying.toggle() },
                        onPrevious: {
                            if currentIndex > 0 {
                                currentIndex -= 1
                            }
                        },
                        onNext: {
                            if currentIndex < words.count - 1 {
                                currentIndex += 1
                            }
                        },
                        onShowInfo: { showWordInfo.toggle() }
                    )
                    
                    // 播放列表
                    PlaylistView(words: words, currentIndex: currentIndex)
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("磨耳朵")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct PlayerCard: View {
    let word: String
    let example: String
    let isPlaying: Bool
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
                Text(word)
                    .font(.system(size: 32, weight: .bold))
                
                if showInfo {
                    Text(example)
                        .font(.body)
                        .italic()
                        .foregroundColor(.purple)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .transition(.opacity)
                }
            }
            
            // 进度条
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.purple)
                            .frame(width: geometry.size.width * 0.35, height: 4)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text("0:12")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("0:35")
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
}

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

struct PlaybackControls: View {
    let isPlaying: Bool
    let onPlayPause: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onShowInfo: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 40) {
                Button(action: onPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.purple)
                }
                
                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            
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
}

struct PlaylistView: View {
    let words: [(word: String, example: String)]
    let currentIndex: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("播放列表 (\(words.count) 词)")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        PlaylistItem(
                            word: word.word,
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
    let word: String
    let isPlaying: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(word)
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

struct AudioReviewView_Previews: PreviewProvider {
    static var previews: some View {
        AudioReviewView()
    }
}
