//
//  StatisticsView.swift
//  EarWords
//
//  统计与进度界面 - 深色模式适配版
//

import SwiftUI
import Charts

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    @State private var selectedTimeRange: TimeRange = .week
    @Environment(\.colorScheme) var colorScheme
    
    enum TimeRange: String, CaseIterable {
        case week = "7天"
        case month = "30天"
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
                    .onChange(of: selectedTimeRange) { newValue in
                        viewModel.loadData(for: newValue)
                    }
                    
                    // 今日概览卡片
                    TodayOverviewCard(stats: viewModel.todayStats, colorScheme: colorScheme)
                    
                    // 连续学习天数
                    StreakCard(streak: viewModel.currentStreak, longest: viewModel.longestStreak, colorScheme: colorScheme)
                    
                    // 学习趋势图
                    LearningTrendChart(data: viewModel.trendData, timeRange: selectedTimeRange, colorScheme: colorScheme)
                    
                    // 词汇掌握情况
                    MasteryOverviewCard(stats: viewModel.masteryStats, colorScheme: colorScheme)
                    
                    // 章节进度
                    ChapterProgressList(chapters: viewModel.chapterProgress, colorScheme: colorScheme)
                }
                .padding(.vertical)
            }
            .navigationTitle("学习统计")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                viewModel.loadData(for: selectedTimeRange)
            }
            .onAppear {
                viewModel.loadData(for: selectedTimeRange)
            }
        }
    }
}

// MARK: - 今日概览卡片

struct TodayOverviewCard: View {
    let stats: TodayStatistics
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("今日概览")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
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
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .clear : .black.opacity(0.05),
                    radius: 10, x: 0, y: 5
                )
        )
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
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("🔥 连续学习")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(streak)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
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
                colors: [
                    colorScheme == .dark ? Color.orange.opacity(0.3) : Color.orange.opacity(0.2),
                    colorScheme == .dark ? Color.red.opacity(0.2) : Color.red.opacity(0.1)
                ],
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
    let timeRange: StatisticsView.TimeRange
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习趋势")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .primary)
            
            if data.isEmpty {
                EmptyChartView(colorScheme: colorScheme)
            } else {
                Chart(data) { point in
                    BarMark(
                        x: .value("日期", point.shortDate),
                        y: .value("新词", point.newWords)
                    )
                    .foregroundStyle(
                        colorScheme == .dark ?
                            Color.green.opacity(0.8).gradient :
                            Color.green.gradient
                    )
                    
                    BarMark(
                        x: .value("日期", point.shortDate),
                        y: .value("复习", point.reviews)
                    )
                    .foregroundStyle(
                        colorScheme == .dark ?
                            Color.blue.opacity(0.8).gradient :
                            Color.blue.gradient
                    )
                }
                .frame(height: 180)
                .chartLegend(position: .top, alignment: .trailing)
            }
            
            // 图例
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorScheme == .dark ? Color.green.opacity(0.8) : Color.green)
                        .frame(width: 12, height: 12)
                    Text("新学")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorScheme == .dark ? Color.blue.opacity(0.8) : Color.blue)
                        .frame(width: 12, height: 12)
                    Text("复习")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .clear : .black.opacity(0.05),
                    radius: 10, x: 0, y: 5
                )
        )
        .padding(.horizontal)
    }
}

struct EmptyChartView: View {
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 40))
                .foregroundColor(colorScheme == .dark ? .gray.opacity(0.5) : .gray.opacity(0.5))
            
            Text("暂无数据")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }
}

// MARK: - 词汇掌握情况

struct MasteryOverviewCard: View {
    let stats: MasteryStats
    let colorScheme: ColorScheme
    
    var total: Int { stats.total }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("词汇掌握")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .white : .primary)
            
            // 进度条
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.gray.opacity(0.4) : Color.gray.opacity(0.3))
                        .frame(width: geometry.size.width * CGFloat(stats.new) / CGFloat(max(total, 1)))
                    
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.blue.opacity(0.8) : Color.blue)
                        .frame(width: geometry.size.width * CGFloat(stats.learning) / CGFloat(max(total, 1)))
                    
                    Rectangle()
                        .fill(colorScheme == .dark ? Color.green.opacity(0.8) : Color.green)
                        .frame(width: geometry.size.width * CGFloat(stats.mastered) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 12)
            .cornerRadius(6)
            
            // 图例
            HStack(spacing: 16) {
                LegendItem(
                    color: colorScheme == .dark ? Color.gray.opacity(0.4) : Color.gray.opacity(0.3),
                    label: "未学习",
                    value: stats.new
                )
                LegendItem(
                    color: colorScheme == .dark ? Color.blue.opacity(0.8) : Color.blue,
                    label: "学习中",
                    value: stats.learning
                )
                LegendItem(
                    color: colorScheme == .dark ? Color.green.opacity(0.8) : Color.green,
                    label: "已掌握",
                    value: stats.mastered
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .clear : .black.opacity(0.05),
                    radius: 10, x: 0, y: 5
                )
        )
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
    let colorScheme: ColorScheme
    @State private var isExpanded = false
    
    var displayedChapters: [ChapterProgress] {
        isExpanded ? chapters : Array(chapters.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("章节进度")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                
                Spacer()
                
                if chapters.count > 5 {
                    Button(isExpanded ? "收起" : "展开") {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(displayedChapters) { chapter in
                    ChapterProgressRow(chapter: chapter, colorScheme: colorScheme)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.systemBackground))
                    .shadow(
                        color: colorScheme == .dark ? .clear : .black.opacity(0.05),
                        radius: 10, x: 0, y: 5
                    )
            )
            .padding(.horizontal)
        }
    }
}

struct ChapterProgressRow: View {
    let chapter: ChapterProgress
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.name)
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                
                ProgressView(value: Double(chapter.mastered), total: Double(max(chapter.total, 1)))
                    .progressViewStyle(
                        LinearProgressViewStyle(tint: colorScheme == .dark ? Color.purple.opacity(0.8) : .purple)
                    )
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(chapter.mastered)/\(chapter.total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                Text("\(Int(chapter.progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(colorScheme == .dark ? Color.purple.opacity(0.8) : .purple)
            }
        }
    }
}

// MARK: - ViewModel

class StatisticsViewModel: ObservableObject {
    @Published var todayStats = TodayStatistics(newWords: 0, reviews: 0, accuracy: 0)
    @Published var currentStreak = 0
    @Published var longestStreak = 0
    @Published var trendData: [DailyDataPoint] = []
    @Published var masteryStats = MasteryStats(new: 0, learning: 0, mastered: 0)
    @Published var chapterProgress: [ChapterProgress] = []
    
    private let dataManager = DataManager.shared
    
    func loadData(for timeRange: StatisticsView.TimeRange) {
        // 今日统计
        todayStats = dataManager.getTodayStatistics()
        
        // 连续学习天数
        let streak = dataManager.calculateStreak()
        currentStreak = streak.current
        longestStreak = streak.longest
        
        // 学习趋势数据
        let days = timeRange == .week ? 7 : 30
        trendData = dataManager.getLearningTrendData(days: days)
        
        // 词汇掌握统计
        masteryStats = dataManager.getMasteryStats()
        
        // 章节进度
        chapterProgress = dataManager.getChapterProgress()
    }
}

// MARK: - 数据模型

struct TodayStatistics {
    let newWords: Int
    let reviews: Int
    let accuracy: Double
}

struct MasteryStats {
    let new: Int
    let learning: Int
    let mastered: Int
    
    var total: Int { new + learning + mastered }
}

struct DailyDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let newWords: Int
    let reviews: Int
    
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
}

struct ChapterProgress: Identifiable {
    let id = UUID()
    let name: String
    let total: Int
    let mastered: Int
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(mastered) / Double(total)
    }
}

// MARK: - DataManager 扩展

extension DataManager {
    func getTodayStatistics() -> TodayStatistics {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        
        // 今日新学
        let newRequest = WordEntity.fetchRequest()
        newRequest.predicate = NSPredicate(format: "createdAt >= %@ AND status != %@", startOfDay as CVarArg, "new")
        let newWords = (try? context.count(for: newRequest)) ?? 0
        
        // 今日复习
        let reviewRequest = ReviewLogEntity.fetchRequest()
        reviewRequest.predicate = NSPredicate(format: "reviewDate >= %@", startOfDay as CVarArg)
        let reviews = (try? context.count(for: reviewRequest)) ?? 0
        
        // 正确率
        let correctRequest = ReviewLogEntity.fetchRequest()
        correctRequest.predicate = NSPredicate(format: "reviewDate >= %@ AND result == %@", startOfDay as CVarArg, "correct")
        let correct = (try? context.count(for: correctRequest)) ?? 0
        let accuracy = reviews > 0 ? Double(correct) / Double(reviews) : 0
        
        return TodayStatistics(newWords: newWords, reviews: reviews, accuracy: accuracy)
    }
    
    func calculateStreak() -> (current: Int, longest: Int) {
        // 从 UserSettings 获取连续天数
        let settings = UserSettingsEntity.defaultSettings(in: context)
        return (Int(settings.currentStreak), Int(settings.longestStreak))
    }
    
    func getLearningTrendData(days: Int) -> [DailyDataPoint] {
        let calendar = Calendar.current
        var data: [DailyDataPoint] = []
        
        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            // 新学
            let newRequest = WordEntity.fetchRequest()
            newRequest.predicate = NSPredicate(format: "createdAt >= %@ AND createdAt < %@ AND status != %@", startOfDay as CVarArg, endOfDay as CVarArg, "new")
            let newWords = (try? context.count(for: newRequest)) ?? 0
            
            // 复习
            let reviewRequest = ReviewLogEntity.fetchRequest()
            reviewRequest.predicate = NSPredicate(format: "reviewDate >= %@ AND reviewDate < %@", startOfDay as CVarArg, endOfDay as CVarArg)
            let reviews = (try? context.count(for: reviewRequest)) ?? 0
            
            data.append(DailyDataPoint(date: date, newWords: newWords, reviews: reviews))
        }
        
        return data
    }
    
    func getMasteryStats() -> MasteryStats {
        let newRequest = WordEntity.fetchRequest()
        newRequest.predicate = NSPredicate(format: "status == %@", "new")
        let new = (try? context.count(for: newRequest)) ?? 0
        
        let learningRequest = WordEntity.fetchRequest()
        learningRequest.predicate = NSPredicate(format: "status == %@", "learning")
        let learning = (try? context.count(for: learningRequest)) ?? 0
        
        let masteredRequest = WordEntity.fetchRequest()
        masteredRequest.predicate = NSPredicate(format: "status == %@", "mastered")
        let mastered = (try? context.count(for: masteredRequest)) ?? 0
        
        return MasteryStats(new: new, learning: learning, mastered: mastered)
    }
    
    func getChapterProgress() -> [ChapterProgress] {
        let chapters = fetchAllChapters()
        return chapters.map { chapter in
            let words = fetchWordsByChapter(chapterKey: chapter.key)
            let mastered = words.filter { $0.status == "mastered" }.count
            return ChapterProgress(name: chapter.name, total: chapter.wordCount, mastered: mastered)
        }
    }
}

// MARK: - 预览

struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StatisticsView()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            StatisticsView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
