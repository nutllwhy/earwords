//
//  StudyView.swift
//  学习主界面 - 核心交互原型
//

import SwiftUI

struct StudyView: View {
    @State private var currentIndex = 0
    @State private var showMeaning = false
    @State private var showExample = false
    @State private var correctCount = 0
    @State private var incorrectCount = 0
    
    // 模拟数据
    let words = [
        WordItem(id: 1, word: "atmosphere", phonetic: "/ˈætməsˌfɪr/", pos: "n.", meaning: "大气层；氛围", example: "The approaching examination created a tense atmosphere on the campus", chapter: "01_自然地理"),
        WordItem(id: 2, word: "hydrosphere", phonetic: "/ˈhaɪdrəsfɪr/", pos: "n.", meaning: "水圈；大气中的水汽", example: "All the water of the earth's surface is included in the hydrosphere", chapter: "01_自然地理"),
        WordItem(id: 3, word: "oxygen", phonetic: "/ˈɒksɪdʒən/", pos: "n.", meaning: "氧气", example: "Hydrogen and Oxygen are gases", chapter: "01_自然地理"),
        WordItem(id: 4, word: "lion", phonetic: "/ˈlaɪən/", pos: "n.", meaning: "狮子；勇猛的人", example: "The lion is called the king of beasts", chapter: "03_动物保护"),
        WordItem(id: 5, word: "tiger", phonetic: "/ˈtaɪɡər/", pos: "n.", meaning: "老虎", example: "The tiger is a fierce animal", chapter: "03_动物保护")
    ]
    
    var currentWord: WordItem {
        words[currentIndex]
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部进度栏
                ProgressBar(current: currentIndex + 1, total: words.count, correct: correctCount, incorrect: incorrectCount)
                    .padding()
                
                // 单词卡片
                WordCard(
                    word: currentWord,
                    showMeaning: $showMeaning,
                    showExample: $showExample
                )
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 评分按钮
                RatingButtons { rating in
                    handleRating(rating)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("今日学习")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    func handleRating(_ rating: Int) {
        if rating >= 3 {
            correctCount += 1
        } else {
            incorrectCount += 1
        }
        
        // 动画切换到下一个
        withAnimation(.easeInOut(duration: 0.3)) {
            showMeaning = false
            showExample = false
            
            if currentIndex < words.count - 1 {
                currentIndex += 1
            } else {
                // 学习完成
                currentIndex = 0
            }
        }
    }
}

// MARK: - 进度栏
struct ProgressBar: View {
    let current: Int
    let total: Int
    let correct: Int
    let incorrect: Int
    
    var progress: Double {
        Double(current) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(current)/\(total)")
                    .font(.subheadline.weight(.semibold))
                
                Spacer()
                
                HStack(spacing: 12) {
                    Label("\(correct)", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Label("\(incorrect)", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .font(.caption)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - 单词卡片
struct WordCard: View {
    let word: WordItem
    @Binding var showMeaning: Bool
    @Binding var showExample: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // 章节标签
            HStack {
                Text(word.chapter)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                Spacer()
            }
            
            Spacer()
            
            // 单词内容
            VStack(spacing: 16) {
                Text(word.word)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                
                if !word.phonetic.isEmpty {
                    Text(word.phonetic)
                        .font(.system(size: 20, design: .serif))
                        .foregroundColor(.secondary)
                }
                
                if !word.pos.isEmpty {
                    Text(word.pos)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // 可展开区域
            VStack(spacing: 16) {
                if showMeaning {
                    VStack(spacing: 8) {
                        Divider()
                        Text(word.meaning)
                            .font(.title3)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                if showExample, !word.example.isEmpty {
                    VStack(spacing: 8) {
                        Divider()
                        Text(word.example)
                            .font(.body)
                            .italic()
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: {}) {
                            Label("播放例句", systemImage: "play.circle")
                                .foregroundColor(.purple)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            
            Spacer()
            
            // 控制按钮
            HStack(spacing: 20) {
                ActionButton(
                    title: showMeaning ? "隐藏释义" : "显示释义",
                    icon: showMeaning ? "eye.slash" : "eye",
                    color: .blue
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showMeaning.toggle()
                        if !showMeaning {
                            showExample = false
                        }
                    }
                }
                
                ActionButton(
                    title: showExample ? "隐藏例句" : "显示例句",
                    icon: showExample ? "text.bubble" : "text.bubble.fill",
                    color: .green
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showExample.toggle()
                        if showExample && !showMeaning {
                            showMeaning = true
                        }
                    }
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
    }
}

// MARK: - 评分按钮
struct RatingButtons: View {
    let onRate: (Int) -> Void
    
    let ratings = [
        (0, "完全忘记", "😵", .red),
        (1, "错误", "😰", .orange),
        (2, "困难", "😓", .yellow),
        (3, "犹豫", "😊", .blue),
        (4, "正确", "😃", .green),
        (5, "完美", "🤩", .purple)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            Text("回忆程度")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 6) {
                ForEach(ratings, id: \.0) { rating in
                    RatingButton(
                        score: rating.0,
                        label: rating.1,
                        emoji: rating.2,
                        color: rating.3
                    ) {
                        onRate(rating.0)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

struct RatingButton: View {
    let score: Int
    let label: String
    let emoji: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.title3)
                Text("\(score)")
                    .font(.caption.weight(.bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(12)
        }
    }
}

// MARK: - 辅助组件
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
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
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - 数据模型
struct WordItem: Identifiable {
    let id: Int
    let word: String
    let phonetic: String
    let pos: String
    let meaning: String
    let example: String
    let chapter: String
}

struct StudyView_Previews: PreviewProvider {
    static var previews: some View {
        StudyView()
    }
}
