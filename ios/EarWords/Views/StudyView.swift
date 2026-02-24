//
//  StudyView.swift
//  EarWords
//
//  主学习界面 - 完整版
//

import SwiftUI

struct StudyView: View {
    @StateObject private var viewModel: StudyViewModel
    @EnvironmentObject private var dataManager: DataManager
    
    // 手势状态
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showDetailSheet = false
    
    init() {
        _viewModel = StateObject(wrappedValue: StudyViewModel())
    }
    
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
                        incorrectCount: viewModel.incorrectCount,
                        newWordsCount: viewModel.newWordsCount,
                        reviewWordsCount: viewModel.reviewWordsCount
                    )
                    .padding()
                    
                    // 主要内容
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("加载中...")
                        Spacer()
                    } else if let currentWord = viewModel.currentWord {
                        // 卡片区域（支持手势）
                        ZStack {
                            // 下一个单词预览（底层）
                            if let nextWord = viewModel.nextWord {
                                WordCardView(word: nextWord, showHint: true)
                                    .opacity(0.3)
                                    .scaleEffect(0.95)
                            }
                            
                            // 当前单词卡片（可拖拽）
                            WordCardView(word: currentWord)
                                .offset(dragOffset)
                                .rotationEffect(.degrees(Double(dragOffset.width / 15)))
                                .scaleEffect(1.0 - abs(dragOffset.width) / 2000)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            withAnimation(.interactiveSpring()) {
                                                dragOffset = value.translation
                                                isDragging = true
                                            }
                                            // 震动反馈
                                            if abs(value.translation.width) > 100 {
                                                let generator = UIImpactFeedbackGenerator(style: .light)
                                                generator.impactOccurred()
                                            }
                                        }
                                        .onEnded { value in
                                            handleDragEnd(value: value)
                                        }
                                )
                                .onLongPressGesture(minimumDuration: 0.5) {
                                    showDetailSheet = true
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                }
                        }
                        .animation(.easeInOut, value: viewModel.currentIndex)
                        
                        // 手势提示
                        HStack(spacing: 40) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.left")
                                Text("左滑模糊")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Text("长按详情")
                                Image(systemName: "hand.tap")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                            HStack(spacing: 4) {
                                Text("右滑认识")
                                Image(systemName: "arrow.right")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                        
                        // 评分按钮区 - 使用改进版防误触设计
                        ImprovedRatingButtons { quality in
                            viewModel.rateCurrentWord(quality: quality)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    } else if viewModel.isStudyComplete {
                        // 学习完成页面
                        StudyCompleteView(
                            stats: viewModel.todayStats,
                            onContinue: {
                                viewModel.loadStudyQueue()
                            },
                            onFinish: {
                                // 返回首页或其他操作
                            }
                        )
                    } else {
                        EmptyStudyView {
                            viewModel.loadStudyQueue()
                        }
                    }
                }
            }
            .navigationTitle("今日学习 (\(viewModel.totalCount))")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { viewModel.skipCurrentWord() }) {
                        Text("跳过")
                            .font(.subheadline)
                    }
                    .disabled(viewModel.currentWord == nil)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                StudySettingsView()
            }
            .sheet(isPresented: $showDetailSheet) {
                if let word = viewModel.currentWord {
                    WordDetailSheet(word: word)
                }
            }
            .onAppear {
                // 先检查是否需要恢复进度
                let hasRecovery = viewModel.checkForRecovery()
                if !hasRecovery {
                    viewModel.loadStudyQueue()
                }
            }
            .alert("提示", isPresented: $viewModel.showError) {
                Button("确定") { }
            } message: {
                Text(viewModel.errorMessage ?? "发生错误")
            }
            // 恢复进度对话框
            .alert("恢复学习进度", isPresented: $viewModel.showRecoveryDialog) {
                Button("继续上次学习", role: .none) {
                    viewModel.restoreProgress()
                }
                Button("重新开始", role: .cancel) {
                    viewModel.startNewSession()
                }
            } message: {
                Text(viewModel.recoveryMessage)
            }
            // 恢复成功提示
            .overlay(
                RecoveryToast(show: $viewModel.showRecoveryToast)
            )
        }
    }
    
    // MARK: - 手势处理
    private func handleDragEnd(value: DragGesture.Value) {
        let threshold: CGFloat = 100
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if value.translation.width > threshold {
                // 右滑 - 标记为认识（4分）
                viewModel.rateCurrentWord(quality: .good)
                triggerHaptic(for: .good)
            } else if value.translation.width < -threshold {
                // 左滑 - 标记为模糊（2分）
                viewModel.rateCurrentWord(quality: .difficult)
                triggerHaptic(for: .difficult)
            }
            dragOffset = .zero
            isDragging = false
        }
    }
    
}

// MARK: - 学习进度条

struct StudyProgressBar: View {
    let current: Int
    let total: Int
    let correctCount: Int
    let incorrectCount: Int
    let newWordsCount: Int
    let reviewWordsCount: Int
    
    var progress: Double {
        total > 0 ? Double(current) / Double(total) : 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(current)/\(total)")
                    .font(.subheadline.weight(.semibold))
                
                Spacer()
                
                HStack(spacing: 8) {
                    if newWordsCount > 0 {
                        Label("\(newWordsCount)", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    if reviewWordsCount > 0 {
                        Label("\(reviewWordsCount)", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
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
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无学习任务")
                .font(.title2.weight(.bold))
            
            Text("今日没有需要学习的单词，休息一下吧！")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onLoad) {
                Text("刷新")
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

// MARK: - 学习完成页面

struct StudyCompleteView: View {
    let stats: TodayStudyStats
    let onContinue: () -> Void
    let onFinish: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 顶部庆祝图标
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                    }
                    
                    Text("学习完成！")
                        .font(.largeTitle.weight(.bold))
                    
                    Text("今日学习任务已完成，继续保持！")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // 今日统计卡片
                VStack(spacing: 16) {
                    Text("今日统计")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 16) {
                        StatCard(
                            title: "新词",
                            value: "\(stats.newWordsCount)",
                            icon: "sparkles",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "复习",
                            value: "\(stats.reviewWordsCount)",
                            icon: "arrow.clockwise",
                            color: .orange
                        )
                    }
                    
                    HStack(spacing: 16) {
                        StatCard(
                            title: "正确",
                            value: "\(stats.correctCount)",
                            icon: "checkmark.circle",
                            color: .green
                        )
                        
                        StatCard(
                            title: "准确率",
                            value: String(format: "%.0f%%", stats.accuracy * 100),
                            icon: "percent",
                            color: .purple
                        )
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                
                // 连续打卡
                if stats.streakDays > 0 {
                    HStack(spacing: 12) {
                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("连续打卡 \(stats.streakDays) 天")
                                .font(.headline)
                            Text("继续保持，养成学习习惯！")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(16)
                }
                
                // 明日预览
                if !stats.tomorrowPreview.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("明日学习预览")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("复习: \(stats.tomorrowPreview[safe: 0] ?? 0)")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            
                            Divider()
                                .frame(height: 16)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("新词: \(stats.tomorrowPreview[safe: 1] ?? 0)")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                }
                
                // 操作按钮
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("继续学习")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    Button(action: onFinish) {
                        Text("完成")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - 统计卡片

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - 单词详情弹窗

struct WordDetailSheet: View {
    let word: WordEntity
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 单词信息
                    VStack(spacing: 12) {
                        Text(word.word)
                            .font(.system(size: 36, weight: .bold))
                        
                        if let phonetic = word.phonetic {
                            Text(phonetic)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(word.meaning)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    // 学习统计
                    VStack(alignment: .leading, spacing: 12) {
                        Text("学习统计")
                            .font(.headline)
                        
                        DetailRow(title: "学习状态", value: word.status)
                        DetailRow(title: "复习次数", value: "\(word.reviewCount)")
                        DetailRow(title: "正确次数", value: "\(word.correctCount)")
                        DetailRow(title: "错误次数", value: "\(word.incorrectCount)")
                        DetailRow(title: "连续正确", value: "\(word.streak)")
                        DetailRow(title: "简易度", value: String(format: "%.2f", word.easeFactor))
                        DetailRow(title: "当前间隔", value: "\(word.interval) 天")
                        
                        if let nextReview = word.nextReviewDate {
                            DetailRow(title: "下次复习", value: formatDate(nextReview))
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    
                    // 例句
                    if let example = word.example, !example.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("例句")
                                .font(.headline)
                            
                            Text(example)
                                .font(.body)
                                .italic()
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("单词详情")
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - 设置视图

struct StudySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dailyNewWordsTarget") private var dailyNewWordsTarget = 20
    @AppStorage("dailyReviewLimit") private var dailyReviewLimit = 50
    @AppStorage("enableAutoPlay") private var enableAutoPlay = true
    @AppStorage("showPhonetic") private var showPhonetic = true
    @AppStorage("enableHaptic") private var enableHaptic = true
    
    var body: some View {
        NavigationView {
            List {
                Section("每日目标") {
                    Stepper("新单词: \(dailyNewWordsTarget)", value: $dailyNewWordsTarget, in: 5...100, step: 5)
                    Stepper("复习上限: \(dailyReviewLimit)", value: $dailyReviewLimit, in: 10...200, step: 10)
                }
                
                Section("学习偏好") {
                    Toggle("自动播放音频", isOn: $enableAutoPlay)
                    Toggle("显示音标", isOn: $showPhonetic)
                    Toggle("震动反馈", isOn: $enableHaptic)
                }
                
                Section("关于") {
                    HStack {
                        Text("SM-2 算法")
                        Spacer()
                        Text("已启用")
                            .foregroundColor(.secondary)
                    }
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

// MARK: - 恢复提示视图

struct RecoveryToast: View {
    @Binding var show: Bool
    
    var body: some View {
        VStack {
            if show {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.title3)
                    Text("已恢复上次学习进度")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.green.opacity(0.9))
                .cornerRadius(25)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    // 2秒后自动消失
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation {
                            show = false
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.top, 60)
        .animation(.easeInOut(duration: 0.3), value: show)
    }
}

// MARK: - 数组安全访问扩展

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - 预览

struct StudyView_Previews: PreviewProvider {
    static var previews: some View {
        StudyView()
            .environmentObject(DataManager.shared)
    }
}
