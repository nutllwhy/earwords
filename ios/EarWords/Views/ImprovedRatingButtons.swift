//
//  ImprovedRatingButtons.swift
//  EarWords
//
//  优化版评分按钮 - 防误触设计
//  改进点：增加间距、统一尺寸、触觉反馈、确认机制、视觉优化
//

import SwiftUI

// MARK: - 改进版评分按钮组件

struct ImprovedRatingButtons: View {
    let onRate: (ReviewQuality) -> Void
    @State private var selectedQuality: ReviewQuality? = nil
    @State private var showConfirmation = false
    @State private var undoTimer: Timer? = nil
    @State private var undoTimeRemaining: Int = 3
    @State private var isAnimating = false
    
    // 触觉反馈生成器
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionHaptic = UISelectionFeedbackGenerator()
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("你对这个词的掌握程度？")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 撤销按钮（评分后3秒内显示）
                if showConfirmation, let quality = selectedQuality {
                    Button(action: undoRating) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                            Text("撤销 (\(undoTimeRemaining)s)")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 4)
            
            // 评分按钮组
            HStack(spacing: 12) {
                ForEach(ReviewQuality.allCases, id: \.self) { quality in
                    ImprovedRatingButton(
                        quality: quality,
                        isSelected: selectedQuality == quality,
                        isEnabled: !showConfirmation || selectedQuality == quality
                    ) {
                        handleRating(quality)
                    }
                }
            }
            .padding(.horizontal, 8)
            
            // 确认提示文字
            if showConfirmation, let quality = selectedQuality {
                Text("已评分: \(quality.emoji) \(quality.description)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
        )
        .onDisappear {
            undoTimer?.invalidate()
        }
    }
    
    // MARK: - 评分处理
    
    private func handleRating(_ quality: ReviewQuality) {
        // 触觉反馈
        triggerHaptic(for: quality)
        
        // 如果正在确认中，直接确认
        if showConfirmation {
            confirmRating()
            return
        }
        
        // 选择评分
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedQuality = quality
            showConfirmation = true
        }
        
        // 启动撤销倒计时
        startUndoTimer()
    }
    
    // MARK: - 确认评分
    
    private func confirmRating() {
        guard let quality = selectedQuality else { return }
        
        undoTimer?.invalidate()
        
        // 成功触觉反馈
        let notificationHaptic = UINotificationFeedbackGenerator()
        notificationHaptic.notificationOccurred(.success)
        
        // 执行评分
        onRate(quality)
        
        // 重置状态
        withAnimation(.easeOut(duration: 0.2)) {
            selectedQuality = nil
            showConfirmation = false
        }
    }
    
    // MARK: - 撤销评分
    
    private func undoRating() {
        undoTimer?.invalidate()
        
        // 撤销触觉反馈
        let notificationHaptic = UINotificationFeedbackGenerator()
        notificationHaptic.notificationOccurred(.warning)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedQuality = nil
            showConfirmation = false
        }
    }
    
    // MARK: - 撤销计时器
    
    private func startUndoTimer() {
        undoTimeRemaining = 3
        undoTimer?.invalidate()
        
        undoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if undoTimeRemaining > 1 {
                undoTimeRemaining -= 1
            } else {
                timer.invalidate()
                confirmRating()
            }
        }
    }
    
    // MARK: - 触觉反馈
    
    private func triggerHaptic(for quality: ReviewQuality) {
        switch quality {
        case .blackOut, .incorrect:
            heavyHaptic.impactOccurred(intensity: 1.0)
        case .difficult:
            mediumHaptic.impactOccurred(intensity: 0.8)
        case .hesitation:
            lightHaptic.impactOccurred(intensity: 0.6)
        case .good:
            lightHaptic.impactOccurred(intensity: 0.4)
        case .perfect:
            selectionHaptic.selectionChanged()
        }
    }
}

// MARK: - 单个评分按钮

struct ImprovedRatingButton: View {
    let quality: ReviewQuality
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    @State private isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // 表情符号
                Text(quality.emoji)
                    .font(.system(size: 24))
                    .scaleEffect(isSelected ? 1.2 : (isPressed ? 0.9 : 1.0))
                
                // 分数
                Text("\(quality.rawValue)")
                    .font(.system(size: 14, weight: .bold))
                
                // 描述
                Text(quality.shortDescription)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(borderColor, lineWidth: isSelected ? 3 : 1)
                    )
            )
            .foregroundColor(foregroundColor)
            .scaleEffect(isSelected ? 1.1 : (isPressed ? 0.95 : 1.0))
            .opacity(isEnabled ? 1.0 : 0.4)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
        .animation(.spring(response: 0.1, dampingFraction: 0.5), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isEnabled {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
    
    // MARK: - 颜色配置
    
    private var backgroundColor: Color {
        if isSelected {
            return quality.color.opacity(0.3)
        }
        return quality.color.opacity(0.12)
    }
    
    private var borderColor: Color {
        if isSelected {
            return quality.color
        }
        return quality.color.opacity(0.3)
    }
    
    private var foregroundColor: Color {
        if isSelected {
            return quality.color
        }
        return quality.color.opacity(0.8)
    }
}

// MARK: - ReviewQuality 扩展

extension ReviewQuality {
    /// 表情符号
    var emoji: String {
        switch self {
        case .blackOut: return "😵"    // 完全想不起来
        case .incorrect: return "😰"   // 记错了
        case .difficult: return "😓"   // 很难想起来
        case .hesitation: return "😊"  // 有点犹豫
        case .good: return "😃"        // 顺利想起
        case .perfect: return "🤩"     // 完美掌握
        }
    }
    
    /// 简短描述（用于按钮）
    var shortDescription: String {
        switch self {
        case .blackOut: return "完全不会"
        case .incorrect: return "记错了"
        case .difficult: return "很难"
        case .hesitation: return "犹豫"
        case .good: return "顺利"
        case .perfect: return "完美"
        }
    }
    
    /// 按钮颜色（按难度分组）
    var color: Color {
        switch self {
        case .blackOut, .incorrect:
            return .red          // 0-1分：红色组（困难）
        case .difficult, .hesitation:
            return .orange       // 2-3分：黄色组（一般）
        case .good, .perfect:
            return .green        // 4-5分：绿色组（良好）
        }
    }
}

// MARK: - 滑动评分条（替代方案）

struct SlidingRatingView: View {
    let onRate: (ReviewQuality) -> Void
    
    @State private var sliderValue: Double = 2.5
    @State private var isDragging = false
    @State private var currentQuality: ReviewQuality = .hesitation
    
    private let selectionHaptic = UISelectionFeedbackGenerator()
    
    var body: some View {
        VStack(spacing: 20) {
            // 当前评分显示
            VStack(spacing: 8) {
                Text(currentQuality.emoji)
                    .font(.system(size: 48))
                    .scaleEffect(isDragging ? 1.2 : 1.0)
                
                Text("\(Int(sliderValue))分 - \(currentQuality.description)")
                    .font(.headline)
                    .foregroundColor(currentQuality.color)
                
                Text(currentQuality.shortDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .animation(.spring(response: 0.2), value: isDragging)
            
            // 滑动条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景轨道
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 24)
                        .opacity(0.3)
                    
                    // 进度条
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: CGFloat(sliderValue / 5.0) * geometry.size.width, height: 24)
                    
                    // 滑块
                    Circle()
                        .fill(Color.white)
                        .frame(width: 36, height: 36)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .overlay(
                            Circle()
                                .stroke(currentQuality.color, lineWidth: 3)
                        )
                        .position(
                            x: CGFloat(sliderValue / 5.0) * geometry.size.width,
                            y: 12
                        )
                        .scaleEffect(isDragging ? 1.2 : 1.0)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            let newValue = max(0, min(5, Double(value.location.x / geometry.size.width) * 5))
                            sliderValue = newValue
                            
                            let newQuality = ReviewQuality(rawValue: Int(round(newValue))) ?? .hesitation
                            if newQuality != currentQuality {
                                currentQuality = newQuality
                                selectionHaptic.selectionChanged()
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                            let finalQuality = ReviewQuality(rawValue: Int(round(sliderValue))) ?? .hesitation
                            onRate(finalQuality)
                            
                            // 成功触觉反馈
                            let notificationHaptic = UINotificationFeedbackGenerator()
                            notificationHaptic.notificationOccurred(.success)
                        }
                )
            }
            .frame(height: 36)
            
            // 刻度标记
            HStack {
                ForEach(0...5, id: \.self) { index in
                    Text("\(index)")
                        .font(.caption)
                        .foregroundColor(index == Int(round(sliderValue)) ? currentQuality.color : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // 确认按钮
            Button(action: {
                let finalQuality = ReviewQuality(rawValue: Int(round(sliderValue))) ?? .hesitation
                onRate(finalQuality)
                
                let notificationHaptic = UINotificationFeedbackGenerator()
                notificationHaptic.notificationOccurred(.success)
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("确认评分")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [currentQuality.color, currentQuality.color.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
        )
    }
}

// MARK: - 两步评分（先选大致水平，再细化）

struct TwoStepRatingView: View {
    let onRate: (ReviewQuality) -> Void
    
    @State private var step: RatingStep = .first
    @State private var selectedLevel: KnowledgeLevel? = nil
    
    enum RatingStep {
        case first      // 第一步：选择大致水平
        case second     // 第二步：细化评分
    }
    
    enum KnowledgeLevel: CaseIterable {
        case dontKnow    // 不认识
        case vague       // 模糊
        case known       // 认识
        
        var title: String {
            switch self {
            case .dontKnow: return "不认识"
            case .vague: return "有点模糊"
            case .known: return "认识"
            }
        }
        
        var emoji: String {
            switch self {
            case .dontKnow: return "❌"
            case .vague: return "🤔"
            case .known: return "✅"
            }
        }
        
        var color: Color {
            switch self {
            case .dontKnow: return .red
            case .vague: return .orange
            case .known: return .green
            }
        }
        
        var qualities: [ReviewQuality] {
            switch self {
            case .dontKnow: return [.blackOut, .incorrect]
            case .vague: return [.difficult, .hesitation]
            case .known: return [.good, .perfect]
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // 步骤指示器
            HStack(spacing: 8) {
                ForEach([RatingStep.first, .second], id: \.self) { s in
                    Circle()
                        .fill(step == s ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            // 标题
            Text(step == .first ? "你对这个词的掌握程度？" : "更精确一点？")
                .font(.headline)
                .foregroundColor(.primary)
            
            if step == .first {
                // 第一步：大致水平
                HStack(spacing: 16) {
                    ForEach(KnowledgeLevel.allCases, id: \.self) { level in
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedLevel = level
                                step = .second
                            }
                            // 触觉反馈
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        }) {
                            VStack(spacing: 12) {
                                Text(level.emoji)
                                    .font(.system(size: 40))
                                Text(level.title)
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(level.color.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(level.color.opacity(0.3), lineWidth: 2)
                                    )
                            )
                            .foregroundColor(level.color)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            } else {
                // 第二步：细化评分
                if let level = selectedLevel {
                    VStack(spacing: 16) {
                        HStack(spacing: 20) {
                            ForEach(level.qualities, id: \.self) { quality in
                                Button(action: {
                                    onRate(quality)
                                    
                                    // 成功触觉反馈
                                    let notificationHaptic = UINotificationFeedbackGenerator()
                                    notificationHaptic.notificationOccurred(.success)
                                    
                                    // 重置
                                    withAnimation {
                                        step = .first
                                        selectedLevel = nil
                                    }
                                }) {
                                    VStack(spacing: 8) {
                                        Text(quality.emoji)
                                            .font(.system(size: 32))
                                        Text("\(quality.rawValue)")
                                            .font(.title2.weight(.bold))
                                        Text(quality.description)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 100)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(quality.color.opacity(0.15))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(quality.color, lineWidth: 2)
                                            )
                                    )
                                    .foregroundColor(quality.color)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        // 返回按钮
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                step = .first
                                selectedLevel = nil
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.uturn.backward")
                                Text("重新选择")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(20)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
        )
    }
}

// MARK: - 使用示例

struct ImprovedRatingButtonsDemo: View {
    @State private var selectedMode: RatingMode = .buttons
    @State private var lastRating: String = ""
    
    enum RatingMode {
        case buttons      // 改进的按钮
        case slider       // 滑动条
        case twoStep      // 两步评分
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // 模式选择
            Picker("评分模式", selection: $selectedMode) {
                Text("按钮").tag(RatingMode.buttons)
                Text("滑动").tag(RatingMode.slider)
                Text("两步").tag(RatingMode.twoStep)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // 评分组件
            switch selectedMode {
            case .buttons:
                ImprovedRatingButtons { quality in
                    lastRating = "按钮评分: \(quality.rawValue)分 \(quality.emoji)"
                }
            case .slider:
                SlidingRatingView { quality in
                    lastRating = "滑动评分: \(quality.rawValue)分 \(quality.emoji)"
                }
            case .twoStep:
                TwoStepRatingView { quality in
                    lastRating = "两步评分: \(quality.rawValue)分 \(quality.emoji)"
                }
            }
            
            // 评分结果
            if !lastRating.isEmpty {
                Text(lastRating)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding(.top, 40)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - 预览

struct ImprovedRatingButtons_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ImprovedRatingButtonsDemo()
                .previewDisplayName("Demo")
            
            ImprovedRatingButtons { quality in
                print("Rated: \(quality)")
            }
            .previewDisplayName("Buttons")
            .padding()
            .background(Color(.systemGroupedBackground))
            
            SlidingRatingView { quality in
                print("Rated: \(quality)")
            }
            .previewDisplayName("Slider")
            .padding()
            .background(Color(.systemGroupedBackground))
            
            TwoStepRatingView { quality in
                print("Rated: \(quality)")
            }
            .previewDisplayName("Two Step")
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }
}
