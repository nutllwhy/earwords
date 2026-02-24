//
//  OnboardingView.swift
//  EarWords
//
//  新用户引导页 - 3页引导流程
//

import SwiftUI

// MARK: - 引导页数据模型
struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let accentColor: Color
}

// MARK: - 引导页视图
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("dailyNewWordsGoal") private var dailyNewWordsGoal = 20
    
    @State private var currentPage = 0
    @State private var dailyGoal = 20
    @Environment(\.dismiss) private var dismiss
    
    private let pages = [
        OnboardingPage(
            title: "EarWords 听词",
            subtitle: "雅思词汇学习",
            description: "通过科学的间隔重复算法和磨耳朵训练，帮助您高效记忆雅思核心词汇。让单词学习成为一种享受！",
            imageName: "earpods",
            accentColor: .purple
        ),
        OnboardingPage(
            title: "SM-2 记忆算法",
            subtitle: "科学记忆曲线",
            description: "基于 SuperMemo-2 间隔重复算法，智能安排复习计划。遗忘曲线？我们来对抗它！",
            imageName: "brain.head.profile",
            accentColor: .blue
        ),
        OnboardingPage(
            title: "设置每日目标",
            subtitle: "坚持就是胜利",
            description: "设定适合您的学习节奏，每天进步一点点。建议新用户从每天20词开始。",
            imageName: "target",
            accentColor: .orange
        )
    ]
    
    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient
            
            VStack(spacing: 0) {
                // 跳过按钮
                skipButton
                
                // 内容区域
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page, dailyGoal: $dailyGoal)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // 底部控制区
                bottomControls
            }
        }
    }
    
    // MARK: - 背景渐变
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                pages[currentPage].accentColor.opacity(0.1),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - 跳过按钮
    private var skipButton: some View {
        HStack {
            Spacer()
            Button("跳过") {
                completeOnboarding()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(20)
            .padding(.trailing, 20)
            .padding(.top, 10)
        }
    }
    
    // MARK: - 底部控制区
    private var bottomControls: some View {
        VStack(spacing: 20) {
            // 页面指示器
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(currentPage == index ? pages[currentPage].accentColor : Color.gray.opacity(0.3))
                        .frame(width: currentPage == index ? 24 : 8, height: 8)
                        .animation(.spring(), value: currentPage)
                }
            }
            
            // 下一步/开始按钮
            Button(action: nextAction) {
                HStack {
                    Text(currentPage == pages.count - 1 ? "开始学习" : "下一步")
                        .font(.headline)
                    Image(systemName: currentPage == pages.count - 1 ? "checkmark" : "arrow.right")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(pages[currentPage].accentColor)
                .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            
            // 返回按钮（非第一页显示）
            if currentPage > 0 {
                Button("返回") {
                    withAnimation {
                        currentPage -= 1
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - 下一步动作
    private func nextAction() {
        if currentPage < pages.count - 1 {
            withAnimation {
                currentPage += 1
            }
        } else {
            completeOnboarding()
        }
    }
    
    // MARK: - 完成引导
    private func completeOnboarding() {
        dailyNewWordsGoal = dailyGoal
        hasCompletedOnboarding = true
        dismiss()
    }
}

// MARK: - 单页引导视图
struct OnboardingPageView: View {
    let page: OnboardingPage
    @Binding var dailyGoal: Int
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // 图标
            ZStack {
                Circle()
                    .fill(page.accentColor.opacity(0.15))
                    .frame(width: 160, height: 160)
                
                Image(systemName: page.imageName)
                    .font(.system(size: 70))
                    .foregroundColor(page.accentColor)
            }
            
            // 标题区域
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(page.subtitle)
                    .font(.title3)
                    .foregroundColor(page.accentColor)
                    .fontWeight(.semibold)
            }
            
            // 描述
            Text(page.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
            
            // 第三页显示目标设置
            if page.title.contains("设置") {
                dailyGoalSelector
            }
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - 每日目标选择器
    private var dailyGoalSelector: some View {
        VStack(spacing: 20) {
            Text("\(dailyGoal)")
                .font(.system(size: 72, weight: .bold))
                .foregroundColor(page.accentColor)
            
            Text("词/天")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // 滑动选择器
            Slider(value: Binding(
                get: { Double(dailyGoal) },
                set: { dailyGoal = Int($0) }
            ), in: 5...50, step: 5)
            .tint(page.accentColor)
            .padding(.horizontal, 40)
            
            // 快捷选项
            HStack(spacing: 12) {
                ForEach([10, 20, 30, 50], id: \.self) { goal in
                    Button {
                        withAnimation {
                            dailyGoal = goal
                        }
                    } label: {
                        Text("\(goal)")
                            .font(.subheadline)
                            .fontWeight(dailyGoal == goal ? .bold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(dailyGoal == goal ? page.accentColor : Color(.systemGray5))
                            .foregroundColor(dailyGoal == goal ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
            
            // 预估提示
            Text(dailyGoalEstimate)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding(.top, 20)
    }
    
    private var dailyGoalEstimate: String {
        let daysToComplete = 3674 / dailyGoal
        let months = daysToComplete / 30
        return "按此速度，约 \(months) 个月可完成全部 3,674 词"
    }
}

// MARK: - 引导页管理器
class OnboardingManager: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    
    static let shared = OnboardingManager()
    
    var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

// MARK: - 引导页包装器视图
struct OnboardingWrapper<Content: View>: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
            
            if onboardingManager.shouldShowOnboarding {
                OnboardingView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }
}

// MARK: - 预览
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
