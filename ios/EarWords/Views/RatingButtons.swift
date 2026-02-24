//
//  RatingButtons.swift
//  EarWords
//
//  简化的3档评分按钮 - 忘记/模糊/记住
//  用户友好设计：大按钮、直观颜色、触觉反馈
//

import SwiftUI

// MARK: - 主评分按钮组件

struct RatingButtons: View {
    let onRate: (SimpleRating) -> Void
    
    @State private var selectedRating: SimpleRating? = nil
    @State private var showGuideTip = false
    @State private var hasShownGuide = false
    
    // 触觉反馈生成器
    private let impactHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let selectionHaptic = UISelectionFeedbackGenerator()
    
    // 用户设置：是否显示引导
    @AppStorage("hasSeenRatingGuide") private var hasSeenRatingGuide: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            Text("你还记得这个词吗？")
                .font(.headline)
                .foregroundColor(.primary)
            
            // 引导提示（首次显示）
            if showGuideTip {
                GuideTipView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // 3个大按钮
            VStack(spacing: 12) {
                ForEach(SimpleRating.allCases, id: \.self) { rating in
                    RatingButtonRow(
                        rating: rating,
                        isSelected: selectedRating == rating
                    ) {
                        handleRating(rating)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
        )
        .onAppear {
            // 首次显示引导提示
            if !hasSeenRatingGuide {
                withAnimation(.easeInOut.delay(0.3)) {
                    showGuideTip = true
                }
                // 2秒后自动隐藏
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeOut) {
                        showGuideTip = false
                    }
                    hasSeenRatingGuide = true
                }
            }
        }
    }
    
    // MARK: - 评分处理
    
    private func handleRating(_ rating: SimpleRating) {
        // 触觉反馈
        rating.triggerHaptic()
        
        // 选中动画
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedRating = rating
        }
        
        // 延迟提交，让用户看到选中效果
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onRate(rating)
            
            // 重置选中状态（为下一个单词做准备）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.2)) {
                    selectedRating = nil
                }
            }
        }
    }
}

// MARK: - 单个评分按钮行

struct RatingButtonRow: View {
    let rating: SimpleRating
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Emoji 图标
                Text(rating.emoji)
                    .font(.system(size: 32))
                    .scaleEffect(isSelected ? 1.2 : (isPressed ? 0.9 : 1.0))
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isSelected)
                
                // 文字内容
                VStack(alignment: .leading, spacing: 4) {
                    Text(rating.title)
                        .font(.system(size: 18, weight: .bold))
                    
                    Text(rating.description)
                        .font(.system(size: 13))
                        .opacity(0.8)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 选中指示器
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? rating.color : .gray.opacity(0.3))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? rating.color.opacity(0.2) : rating.color.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? rating.color : rating.color.opacity(0.3), lineWidth: isSelected ? 3 : 1.5)
                    )
            )
            .foregroundColor(rating.color)
            .scaleEffect(isSelected ? 1.02 : (isPressed ? 0.98 : 1.0))
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - 引导提示视图

struct GuideTipView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
            
            Text(SimpleRating.guideText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - 横向布局版本（备用）

struct RatingButtonsHorizontal: View {
    let onRate: (SimpleRating) -> Void
    
    @State private var selectedRating: SimpleRating? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Text("你还记得这个词吗？")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(SimpleRating.allCases, id: \.self) { rating in
                    CompactRatingButton(
                        rating: rating,
                        isSelected: selectedRating == rating
                    ) {
                        handleRating(rating)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
        )
    }
    
    private func handleRating(_ rating: SimpleRating) {
        rating.triggerHaptic()
        
        withAnimation(.spring(response: 0.3)) {
            selectedRating = rating
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onRate(rating)
        }
    }
}

// MARK: - 紧凑评分按钮

struct CompactRatingButton: View {
    let rating: SimpleRating
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(rating.emoji)
                    .font(.system(size: 36))
                
                Text(rating.title)
                    .font(.system(size: 14, weight: .semibold))
                
                Text(rating.description)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? rating.color.opacity(0.25) : rating.color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? rating.color : rating.color.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                    )
            )
            .foregroundColor(rating.color)
            .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - 预览

struct RatingButtons_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 垂直布局（默认）
            RatingButtons { rating in
                print("Selected: \(rating.title)")
            }
            .previewDisplayName("垂直布局")
            .padding()
            .background(Color(.systemGroupedBackground))
            
            // 横向布局
            RatingButtonsHorizontal { rating in
                print("Selected: \(rating.title)")
            }
            .previewDisplayName("横向布局")
            .padding()
            .background(Color(.systemGroupedBackground))
            
            // 在深色模式下
            RatingButtons { rating in
                print("Selected: \(rating.title)")
            }
            .previewDisplayName("深色模式")
            .padding()
            .background(Color(.systemGroupedBackground))
            .preferredColorScheme(.dark)
        }
    }
}
