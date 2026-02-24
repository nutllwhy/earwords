//
//  TodayProgressWidget.swift
//  EarWordsWidgets
//
//  今日进度小组件（桌面）
//

import WidgetKit
import SwiftUI

// MARK: - 数据提供器

struct TodayProgressProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> TodayProgressEntry {
        TodayProgressEntry.sample()
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodayProgressEntry) -> Void) {
        completion(TodayProgressEntry.current())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayProgressEntry>) -> Void) {
        let entry = TodayProgressEntry.current()
        
        // 每15分钟更新一次
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

// MARK: - 时间线条目

struct TodayProgressEntry: TimelineEntry {
    let date: Date
    let studiedCount: Int
    let newWordsGoal: Int
    let reviewCount: Int
    let reviewGoal: Int
    let dueCount: Int
    let streakDays: Int
    
    var newWordsProgress: Double {
        guard newWordsGoal > 0 else { return 0 }
        return min(Double(studiedCount) / Double(newWordsGoal), 1.0)
    }
    
    var reviewProgress: Double {
        guard reviewGoal > 0 else { return 0 }
        return min(Double(reviewCount) / Double(reviewGoal), 1.0)
    }
    
    var overallProgress: Double {
        let totalGoal = newWordsGoal + reviewGoal
        let totalDone = studiedCount + reviewCount
        guard totalGoal > 0 else { return 0 }
        return min(Double(totalDone) / Double(totalGoal), 1.0)
    }
    
    var isGoalCompleted: Bool {
        studiedCount >= newWordsGoal && reviewCount >= reviewGoal
    }
    
    static func sample() -> TodayProgressEntry {
        TodayProgressEntry(
            date: Date(),
            studiedCount: 12,
            newWordsGoal: 20,
            reviewCount: 25,
            reviewGoal: 50,
            dueCount: 15,
            streakDays: 7
        )
    }
    
    static func current() -> TodayProgressEntry {
        guard let progress = WidgetDataReader.read() else {
            return sample()
        }
        
        return TodayProgressEntry(
            date: Date(),
            studiedCount: progress.studiedCount,
            newWordsGoal: progress.newWordsGoal,
            reviewCount: progress.reviewCount,
            reviewGoal: progress.reviewGoal,
            dueCount: progress.dueCount,
            streakDays: progress.streakDays
        )
    }
}

// MARK: - 小组件视图

struct TodayProgressWidgetEntryView: View {
    var entry: TodayProgressProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallProgressView(entry: entry)
        case .systemMedium:
            MediumProgressView(entry: entry)
        case .systemLarge:
            LargeProgressView(entry: entry)
        @unknown default:
            SmallProgressView(entry: entry)
        }
    }
}

// MARK: - 小组件定义

struct TodayProgressWidget: Widget {
    let kind: String = "com.earwords.widget.today"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProgressProvider()) { entry in
            TodayProgressWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("今日学习进度")
        .description("显示今天的学习进度和目标完成情况")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - 小组件子视图

struct SmallProgressView: View {
    let entry: TodayProgressEntry
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            // 标题
            HStack {
                Image(systemName: "book.fill")
                    .font(.caption)
                    .foregroundColor(.purple)
                Text("今日学习")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Spacer()
            
            // 环形进度
            ZStack {
                Circle()
                    .stroke(
                        colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2),
                        lineWidth: 8
                    )
                
                Circle()
                    .trim(from: 0, to: entry.overallProgress)
                    .stroke(
                        AngularGradient(
                            colors: [.purple, .blue],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: entry.overallProgress)
                
                VStack(spacing: 2) {
                    Text("\(Int(entry.overallProgress * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    if entry.streakDays > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("\(entry.streakDays)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .frame(height: 70)
            
            Spacer()
        }
        .padding()
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
    }
}

struct MediumProgressView: View {
    let entry: TodayProgressEntry
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧环形进度
            ZStack {
                Circle()
                    .stroke(
                        colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2),
                        lineWidth: 10
                    )
                
                Circle()
                    .trim(from: 0, to: entry.overallProgress)
                    .stroke(
                        AngularGradient(
                            colors: [.purple, .blue],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(Int(entry.overallProgress * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if entry.streakDays > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("\(entry.streakDays)天")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .frame(width: 90, height: 90)
            
            // 右侧详情
            VStack(alignment: .leading, spacing: 12) {
                // 新词进度
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("新词学习")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(entry.studiedCount)/\(entry.newWordsGoal)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.purple)
                                .frame(width: geo.size.width * entry.newWordsProgress, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                
                // 复习进度
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("单词复习")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(entry.reviewCount)/\(entry.reviewGoal)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue)
                                .frame(width: geo.size.width * entry.reviewProgress, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                
                // 待复习
                if entry.dueCount > 0 {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("待复习: \(entry.dueCount) 词")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
    }
}

struct LargeProgressView: View {
    let entry: TodayProgressEntry
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            // 顶部标题和总进度
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日学习")
                        .font(.headline)
                    Text(entry.isGoalCompleted ? "目标已完成 🎉" : "继续加油 💪")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 环形进度
                ZStack {
                    Circle()
                        .stroke(
                            colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2),
                            lineWidth: 6
                        )
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: entry.overallProgress)
                        .stroke(
                            AngularGradient(
                                colors: [.purple, .blue],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(entry.overallProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            
            Divider()
            
            // 详细进度
            HStack(spacing: 20) {
                // 新词卡片
                ProgressCard(
                    title: "新词学习",
                    icon: "book.fill",
                    color: .purple,
                    current: entry.studiedCount,
                    goal: entry.newWordsGoal,
                    progress: entry.newWordsProgress
                )
                
                // 复习卡片
                ProgressCard(
                    title: "单词复习",
                    icon: "arrow.clockwise",
                    color: .blue,
                    current: entry.reviewCount,
                    goal: entry.reviewGoal,
                    progress: entry.reviewProgress
                )
            }
            
            // 连续学习
            if entry.streakDays > 0 {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("已连续学习 \(entry.streakDays) 天")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(colorScheme == .dark ? 0.2 : 0.1))
                .cornerRadius(8)
            }
            
            // 待复习提示
            if entry.dueCount > 0 && !entry.isGoalCompleted {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                    Text("还有 \(entry.dueCount) 个单词待复习")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(colorScheme == .dark ? 0.2 : 0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
    }
}

struct ProgressCard: View {
    let title: String
    let icon: String
    let color: Color
    let current: Int
    let goal: Int
    let progress: Double
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(current)")
                    .font(.title)
                    .fontWeight(.bold)
                Text("/\(goal)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(color.opacity(colorScheme == .dark ? 0.15 : 0.1))
        .cornerRadius(12)
    }
}

// MARK: - 预览

struct TodayProgressWidget_Previews: PreviewProvider {
    static var previews: some View {
        TodayProgressWidgetEntryView(entry: TodayProgressEntry.sample())
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small")
        
        TodayProgressWidgetEntryView(entry: TodayProgressEntry.sample())
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium")
        
        TodayProgressWidgetEntryView(entry: TodayProgressEntry.sample())
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .previewDisplayName("Large")
    }
}
