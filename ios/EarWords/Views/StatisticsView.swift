//
//  StatisticsView.swift
//  EarWords
//
//  统计与进度界面
//

import SwiftUI

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    @State private var selectedTimeRange: TimeRange = .week
    
    enum TimeRange: String, CaseIterable {
        case week = "本周"
        case month = "本月"
        case year = "本年"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 时间范围选择
                    Picker("时间范围", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // 今日概览卡片
                    TodayOverviewCard(stats: viewModel.todayStats)
                    
                    // 连续学习天数
                    StreakCard(streak: viewModel.currentStreak, longest: viewModel.longestStreak)
                    
                    // 学习趋势图
                    LearningTrendChart(data: viewModel.weeklyData)
                    
                    // 词汇掌握情况
                    MasteryOverviewCard(
                        new: viewModel.newWordsCount,
                        learning: viewModel.learningWordsCount,
                        mastered: viewModel.masteredWordsCount
                    )
                    
                    // 章节进度
                    ChapterProgressList(chapters: viewModel.chapterProgress)
                }
                .padding(.vertical)
            }
            .navigationTitle("学习统计")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - 今日概览卡片

struct TodayOverviewCard: View {
    let stats: TodayStatistics
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("今日概览")
                    .font(.headline)
                Spacer()
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                StatItem(
                    icon: "sparkles",
                    color: .yellow,
                    value: "\(stats.newWords)",
                    label: "新学单词"
                )
                
                StatItem(
                    icon: "repeat",
                    color: .blue,
                    value: "\(stats.reviews)",
                    label: "复习单词"
                )
                
                StatItem(
                    icon: "checkmark.circle",
                    color: .green,
                    value: "\(Int(stats.accuracy * 100))%",
                    label: "正确率"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

struct StatItem: View {
    let icon: String
    let color: Color
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3.weight(.bold))
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 连续学习天数

struct StreakCard: View {
    let streak: Int
    let longest: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("🔥 连续学习")
                    .font(.headline)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(streak)")
                        .font(.system(size: 48, weight: .bold))
                    Text("天")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Text("最长记录: \(longest) 天")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 火焰动画效果
            FlameAnimation()
                .frame(width: 80, height: 80)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.orange.opacity(0.2), .red.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .padding(.horizontal)
    }
}

struct FlameAnimation: View {
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: 50))
            .foregroundColor(.orange)
            .scaleEffect(isAnimating ? 1.1 : 0.9)
            .animation(
                Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - 学习趋势图

struct LearningTrendChart: View {
    let data: [DailyDataPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习趋势")
                .font(.headline)
            
            if data.isEmpty {
                EmptyChartView()
            } else {
                BarChartView(data: data)
                    .frame(height: 150)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

struct BarChartView: View {
    let data: [DailyDataPoint]
    
    var maxValue: Int {
        data.map { $0.newWords + $0.reviews }.max() ?? 1
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(data) { point in
                VStack(spacing: 4) {
                    // 柱状图
                    VStack(spacing: 0) {
                        // 复习部分
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue)
                            .frame(height: CGFloat(point.reviews) / CGFloat(maxValue) * 100)
                        
                        // 新词部分
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(height: CGFloat(point.newWords) / CGFloat(maxValue) * 100)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // 日期标签
                    Text(point.shortDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct EmptyChartView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("暂无数据")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }
}

// MARK: - 词汇掌握情况

struct MasteryOverviewCard: View {
    let new: Int
    let learning: Int
    let mastered: Int
    
    var total: Int { new + learning + mastered }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("词汇掌握")
                .font(.headline)
            
            // 进度条
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: geometry.size.width * CGFloat(new) / CGFloat(total))
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(learning) / CGFloat(total))
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * CGFloat(mastered) / CGFloat(total))
                }
            }
            .frame(height: 12)
            .cornerRadius(6)
            
            // 图例
            HStack(spacing: 16) {
                LegendItem(color: .gray, label: "未学习", value: new)
                LegendItem(color: .blue, label: "学习中", value: learning)
                LegendItem(color: .green, label: "已掌握", value: mastered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    let value: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(value)")
                .font(.caption.weight(.semibold))
        }
    }
}

// MARK: - 章节进度

struct ChapterProgressList: View {
    let chapters: [ChapterProgress]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("章节进度")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(chapters.prefix(5)) { chapter in
                    ChapterProgressRow(chapter: chapter)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
            .padding(.horizontal)
        }
    }
}

struct ChapterProgressRow: View {
    let chapter: ChapterProgress
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.name)
                    .font(.subheadline)
                
                ProgressView(value: Double(chapter.mastered), total: Double(chapter.total))
                    .progressViewStyle(LinearProgressViewStyle(tint: .purple))
            }
            
            Spacer()
            
            Text("\(chapter.mastered)/\(chapter.total)")
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - 数据模型

struct TodayStatistics {
    let newWords: Int
    let reviews: Int
    let accuracy: Double
}

struct DailyDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let newWords: Int
    let reviews: Int
    
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

struct ChapterProgress: Identifiable {
    let id = UUID()
    let name: String
    let total: Int
    let mastered: Int
}

// MARK: - ViewModel

class StatisticsViewModel: ObservableObject {
    @Published var todayStats = TodayStatistics(newWords: 0, reviews: 0, accuracy: 0)
    @Published var currentStreak = 0
    @Published var longestStreak = 0
    @Published var newWordsCount = 0
    @Published var learningWordsCount = 0
    @Published var masteredWordsCount = 0
    @Published var weeklyData: [DailyDataPoint] = []
    @Published var chapterProgress: [ChapterProgress] = []
    
    init() {
        loadStatistics()
    }
    
    func loadStatistics() {
        // 从 DataManager 加载统计数据
        // 暂时使用模拟数据
        todayStats = TodayStatistics(newWords: 20, reviews: 35, accuracy: 0.85)
        currentStreak = 7
        longestStreak = 30
        newWordsCount = 1000
        learningWordsCount = 1500
        masteredWordsCount = 1174
        
        weeklyData = [
            DailyDataPoint(date: Date().addingTimeInterval(-86400 * 6), newWords: 15, reviews: 30),
            DailyDataPoint(date: Date().addingTimeInterval(-86400 * 5), newWords: 20, reviews: 40),
            DailyDataPoint(date: Date().addingTimeInterval(-86400 * 4), newWords: 18, reviews: 35),
            DailyDataPoint(date: Date().addingTimeInterval(-86400 * 3), newWords: 22, reviews: 45),
            DailyDataPoint(date: Date().addingTimeInterval(-86400 * 2), newWords: 20, reviews: 38),
            DailyDataPoint(date: Date().addingTimeInterval(-86400), newWords: 25, reviews: 50),
            DailyDataPoint(date: Date(), newWords: 20, reviews: 35)
        ]
        
        chapterProgress = [
            ChapterProgress(name: "01_自然地理", total: 241, mastered: 200),
            ChapterProgress(name: "02_植物研究", total: 130, mastered: 80),
            ChapterProgress(name: "03_动物保护", total: 168, mastered: 100),
            ChapterProgress(name: "04_太空探索", total: 75, mastered: 50),
            ChapterProgress(name: "05_学校教育", total: 401, mastered: 150)
        ]
    }
}

struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView()
    }
}
