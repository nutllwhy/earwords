//
//  StudyView.swift
//  EarWords
//
//  主学习界面
//

import SwiftUI

struct StudyView: View {
    @StateObject private var viewModel = StudyViewModel()
    @EnvironmentObject private var dataManager: DataManager
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 顶部进度栏
                    StudyProgressBar(
                        current: viewModel.currentIndex + 1,
                        total: viewModel.totalCount,
                        correctCount: viewModel.correctCount,
                        incorrectCount: viewModel.incorrectCount
                    )
                    .padding()
                    
                    // 主要内容
                    if let currentWord = viewModel.currentWord {
                        TabView(selection: $viewModel.currentIndex) {
                            ForEach(Array(viewModel.studyQueue.enumerated()), id: \.element.id) { index, word in
                                WordCardView(word: word)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .animation(.easeInOut, value: viewModel.currentIndex)
                        
                        // 评分按钮区
                        RatingButtons { quality in
                            viewModel.rateCurrentWord(quality: quality)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    } else {
                        EmptyStudyView {
                            viewModel.loadStudyQueue()
                        }
                    }
                }
            }
            .navigationTitle("今日学习")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                StudySettingsView()
            }
            .onAppear {
                viewModel.loadStudyQueue()
            }
        }
    }
}

// MARK: - 评分按钮

struct RatingButtons: View {
    let onRate: (ReviewQuality) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("回忆程度")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                ForEach(ReviewQuality.allCases, id: \.self) { quality in
                    RatingButton(quality: quality) {
                        onRate(quality)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

struct RatingButton: View {
    let quality: ReviewQuality
    let action: () -> Void
    
    var color: Color {
        switch quality {
        case .blackOut: return .red
        case .incorrect: return .orange
        case .difficult: return .yellow
        case .hesitation: return .blue
        case .good: return .green
        case .perfect: return .purple
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(quality.rawValue)")
                    .font(.headline)
                Text(quality.description)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(12)
        }
    }
}

// MARK: - 学习进度条

struct StudyProgressBar: View {
    let current: Int
    let total: Int
    let correctCount: Int
    let incorrectCount: Int
    
    var progress: Double {
        total > 0 ? Double(current) / Double(total) : 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(current)/\(total)")
                    .font(.subheadline.weight(.semibold))
                
                Spacer()
                
                HStack(spacing: 12) {
                    Label("\(correctCount)", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Label("\(incorrectCount)", systemImage: "xmark.circle.fill")
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
                                colors: [.blue, .purple],
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

// MARK: - 空状态视图

struct EmptyStudyView: View {
    let onLoad: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("今日学习完成！")
                .font(.title2.weight(.bold))
            
            Text("你已完成所有待学习的单词")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button(action: onLoad) {
                Text("继续学习")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

// MARK: - 设置视图

struct StudySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("每日目标") {
                    Stepper("新单词: 20", value: .constant(20))
                    Stepper("复习单词: 50", value: .constant(50))
                }
                
                Section("学习偏好") {
                    Toggle("自动播放音频", isOn: .constant(true))
                    Toggle("显示音标", isOn: .constant(true))
                    Toggle("显示例句", isOn: .constant(false))
                }
            }
            .navigationTitle("学习设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - ViewModel

class StudyViewModel: ObservableObject {
    @Published var studyQueue: [WordEntity] = []
    @Published var currentIndex = 0
    @Published var correctCount = 0
    @Published var incorrectCount = 0
    @Published var showSettings = false
    
    var currentWord: WordEntity? {
        studyQueue.indices.contains(currentIndex) ? studyQueue[currentIndex] : nil
    }
    
    var totalCount: Int {
        studyQueue.count
    }
    
    func loadStudyQueue() {
        // 从 DataManager 加载今日学习队列
        // 暂时使用模拟数据
    }
    
    func rateCurrentWord(quality: ReviewQuality) {
        guard let word = currentWord else { return }
        
        // 记录评分
        if quality.rawValue >= 3 {
            correctCount += 1
        } else {
            incorrectCount += 1
        }
        
        // 应用 SM-2 算法
        // DataManager.shared.logReview(word: word, quality: quality)
        
        // 移动到下一个
        withAnimation {
            if currentIndex < studyQueue.count - 1 {
                currentIndex += 1
            } else {
                // 学习完成
                studyQueue = []
                currentIndex = 0
            }
        }
    }
}

struct StudyView_Previews: PreviewProvider {
    static var previews: some View {
        StudyView()
            .environmentObject(DataManager.shared)
    }
}
