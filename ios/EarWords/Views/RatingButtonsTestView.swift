//
//  RatingButtonsTestView.swift
//  EarWords
//
//  评分按钮可用性测试视图
//  用于对比不同评分方案的可用性
//

import SwiftUI

struct RatingButtonsTestView: View {
    @State private var testResults: [TestResult] = []
    @State private var currentMode: TestMode = .original
    @State private var testCount = 0
    @State private var errorCount = 0
    @State private var startTime: Date?
    
    enum TestMode: String, CaseIterable {
        case original = "原始按钮"
        case improved = "改进按钮"
        case slider = "滑动评分"
        case twoStep = "两步评分"
    }
    
    struct TestResult: Identifiable {
        let id = UUID()
        let mode: TestMode
        let intendedScore: Int
        let actualScore: Int
        let duration: TimeInterval
        let hasError: Bool
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 测试统计
                    TestStatsCard(
                        totalTests: testCount,
                        errorCount: errorCount,
                        errorRate: testCount > 0 ? Double(errorCount) / Double(testCount) * 100 : 0
                    )
                    
                    // 模式选择
                    Picker("评分模式", selection: $currentMode) {
                        ForEach(TestMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // 测试说明
                    TestInstructionCard(mode: currentMode)
                    
                    // 评分组件（根据模式显示）
                    VStack(spacing: 20) {
                        Text("请点击你\'想\'给的分数")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        switch currentMode {
                        case .original:
                            // 模拟原始按钮（紧凑布局）
                            OriginalRatingButtonsMock { score in
                                recordTest(intended: 3, actual: score)
                            }
                        case .improved:
                            ImprovedRatingButtons { quality in
                                recordTest(intended: 3, actual: Int(quality.rawValue))
                            }
                        case .slider:
                            SlidingRatingView { quality in
                                recordTest(intended: 3, actual: Int(quality.rawValue))
                            }
                        case .twoStep:
                            TwoStepRatingView { quality in
                                recordTest(intended: 3, actual: Int(quality.rawValue))
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    
                    // 测试结果
                    if !testResults.isEmpty {
                        TestResultsList(results: testResults)
                    }
                    
                    // 清除按钮
                    if !testResults.isEmpty {
                        Button(action: clearResults) {
                            Text("清除测试结果")
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("评分按钮测试")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private func recordTest(intended: Int, actual: Int) {
        let duration = startTime?.timeIntervalSinceNow ?? 0
        let hasError = intended != actual
        
        let result = TestResult(
            mode: currentMode,
            intendedScore: intended,
            actualScore: actual,
            duration: abs(duration),
            hasError: hasError
        )
        
        testResults.insert(result, at: 0)
        testCount += 1
        if hasError {
            errorCount += 1
        }
        
        startTime = nil
    }
    
    private func clearResults() {
        testResults.removeAll()
        testCount = 0
        errorCount = 0
    }
}

// MARK: - 原始按钮模拟（用于对比测试）

struct OriginalRatingButtonsMock: View {
    let onRate: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Text("回忆程度")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 6) {  // 原始间距只有6pt
                ForEach(0...5, id: \.self) { score in
                    Button(action: { onRate(score) }) {
                        VStack(spacing: 2) {
                            Text("\(score)")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)  // 原始高度较小
                        .background(scoreColor(score).opacity(0.15))
                        .foregroundColor(scoreColor(score))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 0, 1: return .red
        case 2, 3: return .orange
        case 4, 5: return .green
        default: return .gray
        }
    }
}

// MARK: - 测试统计卡片

struct TestStatsCard: View {
    let totalTests: Int
    let errorCount: Int
    let errorRate: Double
    
    var body: some View {
        HStack(spacing: 20) {
            StatItem(title: "总测试", value: "\(totalTests)", color: .blue)
            StatItem(title: "误触数", value: "\(errorCount)", color: .red)
            StatItem(title: "误触率", value: String(format: "%.1f%%", errorRate), color: .orange)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 测试说明卡片

struct TestInstructionCard: View {
    let mode: RatingButtonsTestView.TestMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("当前模式: \(mode.rawValue)")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(nil)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var description: String {
        switch mode {
        case .original:
            return "原始设计：按钮间距6pt，无表情符号，无确认机制，容易误触。用于对比测试。"
        case .improved:
            return "改进设计：间距12pt，56x56pt按钮，带表情符号和颜色分组，3秒撤销机制，触觉反馈。"
        case .slider:
            return "滑动评分：连续滑动选择分数，适合快速评分，减少误触，但精确度略低。"
        case .twoStep:
            return "两步评分：先选大致水平（不认识/模糊/认识），再细化评分，适合精确反馈。"
        }
    }
}

// MARK: - 测试结果列表

struct TestResultsList: View {
    let results: [RatingButtonsTestView.TestResult]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近测试记录")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVStack(spacing: 8) {
                ForEach(results.prefix(10)) { result in
                    TestResultRow(result: result)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct TestResultRow: View {
    let result: RatingButtonsTestView.TestResult
    
    var body: some View {
        HStack {
            // 模式标签
            Text(result.mode.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            // 预期分数
            HStack(spacing: 4) {
                Text("目标:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(result.intendedScore)")
                    .font(.caption.weight(.medium))
            }
            
            // 实际分数
            HStack(spacing: 4) {
                Text("实际:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("\(result.actualScore)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(result.hasError ? .red : .green)
            }
            
            Spacer()
            
            // 结果状态
            if result.hasError {
                Label("误触", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Label("正确", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 预览

struct RatingButtonsTestView_Previews: PreviewProvider {
    static var previews: some View {
        RatingButtonsTestView()
    }
}
