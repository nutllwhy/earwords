//
//  EarWordsWidget.swift
//  EarWordsWidgetExtension
//
//  Widget Bundle - 包含所有小组件
//

import WidgetKit
import SwiftUI

// MARK: - 小组件 Bundle
@main
struct EarWordsWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayProgressWidget()
        LockScreenWidget()
        StreakWidget()
    }
}

// MARK: - 今日进度小组件
struct TodayProgressWidget: Widget {
    let kind: String = "com.earwords.widget.today"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProgressProvider()) { entry in
            TodayProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("今日学习进度")
        .description("显示今日单词学习进度和连续打卡天数")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - 锁屏小组件
struct LockScreenWidget: Widget {
    let kind: String = "com.earwords.widget.lockscreen"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("锁屏进度")
        .description("在锁屏界面显示学习进度")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - 连续打卡小组件
struct StreakWidget: Widget {
    let kind: String = "com.earwords.widget.streak"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("连续打卡")
        .description("显示连续学习天数")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

// MARK: - Timeline Entry
struct WidgetEntry: TimelineEntry {
    let date: Date
    let progress: WidgetProgress
    
    static var placeholder: WidgetEntry {
        WidgetEntry(
            date: Date(),
            progress: WidgetProgress(
                studiedCount: 15,
                newWordsGoal: 20,
                reviewCount: 30,
                reviewGoal: 50,
                dueCount: 12,
                streakDays: 7
            )
        )
    }
}

struct WidgetProgress {
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
}

// MARK: - Timeline Providers

struct TodayProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        let entry = loadWidgetData()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> ()) {
        let entry = loadWidgetData()
        
        // 每小时更新一次，或在用户学习后刷新
        let nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
    
    private func loadWidgetData() -> WidgetEntry {
        guard let defaults = UserDefaults(suiteName: "group.com.lidengdeng.earwords") else {
            return .placeholder
        }
        
        let progress = WidgetProgress(
            studiedCount: defaults.integer(forKey: "studiedCount"),
            newWordsGoal: defaults.integer(forKey: "newWordsGoal"),
            reviewCount: defaults.integer(forKey: "reviewCount"),
            reviewGoal: defaults.integer(forKey: "reviewGoal"),
            dueCount: defaults.integer(forKey: "dueCount"),
            streakDays: defaults.integer(forKey: "streakDays")
        )
        
        return WidgetEntry(date: Date(), progress: progress)
    }
}

struct LockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        let entry = loadWidgetData()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> ()) {
        let entry = loadWidgetData()
        let nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
    
    private func loadWidgetData() -> WidgetEntry {
        guard let defaults = UserDefaults(suiteName: "group.com.lidengdeng.earwords") else {
            return .placeholder
        }
        
        let progress = WidgetProgress(
            studiedCount: defaults.integer(forKey: "studiedCount"),
            newWordsGoal: defaults.integer(forKey: "newWordsGoal"),
            reviewCount: defaults.integer(forKey: "reviewCount"),
            reviewGoal: defaults.integer(forKey: "reviewGoal"),
            dueCount: defaults.integer(forKey: "dueCount"),
            streakDays: defaults.integer(forKey: "streakDays")
        )
        
        return WidgetEntry(date: Date(), progress: progress)
    }
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        let entry = loadWidgetData()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetEntry>) -> ()) {
        let entry = loadWidgetData()
        let nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
        completion(timeline)
    }
    
    private func loadWidgetData() -> WidgetEntry {
        guard let defaults = UserDefaults(suiteName: "group.com.lidengdeng.earwords") else {
            return .placeholder
        }
        
        let progress = WidgetProgress(
            studiedCount: defaults.integer(forKey: "studiedCount"),
            newWordsGoal: defaults.integer(forKey: "newWordsGoal"),
            reviewCount: defaults.integer(forKey: "reviewCount"),
            reviewGoal: defaults.integer(forKey: "reviewGoal"),
            dueCount: defaults.integer(forKey: "dueCount"),
            streakDays: defaults.integer(forKey: "streakDays")
        )
        
        return WidgetEntry(date: Date(), progress: progress)
    }
}

// MARK: - Widget Views

// 今日进度小组件视图
struct TodayProgressWidgetView: View {
    var entry: WidgetEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(progress: entry.progress, colorScheme: colorScheme)
        case .systemMedium:
            MediumWidgetView(progress: entry.progress, colorScheme: colorScheme)
        case .systemLarge:
            LargeWidgetView(progress: entry.progress, colorScheme: colorScheme)
        case .accessoryCircular:
            AccessoryCircularView(progress: entry.progress)
        case .accessoryRectangular:
            AccessoryRectangularView(progress: entry.progress)
        case .accessoryInline:
            AccessoryInlineView(progress: entry.progress)
        default:
            SmallWidgetView(progress: entry.progress, colorScheme: colorScheme)
        }
    }
}

// 锁屏小组件视图
struct LockScreenWidgetView: View {
    var entry: WidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            AccessoryCircularView(progress: entry.progress)
        case .accessoryRectangular:
            AccessoryRectangularView(progress: entry.progress)
        case .accessoryInline:
            AccessoryInlineView(progress: entry.progress)
        default:
            AccessoryCircularView(progress: entry.progress)
        }
    }
}

// 连续打卡小组件视图
struct StreakWidgetView: View {
    var entry: WidgetEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        switch family {
        case .systemSmall:
            StreakSmallView(progress: entry.progress, colorScheme: colorScheme)
        case .accessoryCircular:
            StreakCircularView(progress: entry.progress)
        default:
            StreakSmallView(progress: entry.progress, colorScheme: colorScheme)
        }
    }
}

// MARK: - 小组件具体视图实现

// 小尺寸小组件
struct SmallWidgetView: View {
    let progress: WidgetProgress
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            // 标题和连续天数
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.purple)
                Spacer()
                if progress.streakDays > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("\(progress.streakDays)")
                            .font(.caption2.bold())
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // 圆形进度
            ZStack {
                Circle()
                    .stroke(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: progress.overallProgress)
                    .stroke(
                        AngularGradient(
                            colors: [.purple, .blue],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress.overallProgress)
                
                VStack(spacing: 2) {
                    Text("\(Int(progress.overallProgress * 100))%")
                        .font(.title2.bold())
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    Text("今日进度")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 80)
            
            Spacer()
            
            // 底部数据
            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("\(progress.studiedCount)/\(progress.newWordsGoal)")
                        .font(.caption.bold())
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    Text("新词")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("\(progress.reviewCount)/\(progress.reviewGoal)")
                        .font(.caption.bold())
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    Text("复习")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
    }
}

// 中尺寸小组件
struct MediumWidgetView: View {
    let progress: WidgetProgress
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: 20) {
            // 左侧圆形进度
            ZStack {
                Circle()
                    .stroke(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 10)
                
                Circle()
                    .trim(from: 0, to: progress.overallProgress)
                    .stroke(
                        AngularGradient(
                            colors: [.purple, .blue],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(Int(progress.overallProgress * 100))%")
                        .font(.title.bold())
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                }
            }
            .frame(width: 90, height: 90)
            
            // 右侧详情
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("今日学习")
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    
                    Spacer()
                    
                    if progress.streakDays > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(progress.streakDays)天")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                // 新词进度
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("新词学习")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(progress.studiedCount)/\(progress.newWordsGoal)")
                            .font(.caption.bold())
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                    }
                    ProgressView(value: progress.newWordsProgress)
                        .tint(.blue)
                }
                
                // 复习进度
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("单词复习")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(progress.reviewCount)/\(progress.reviewGoal)")
                            .font(.caption.bold())
                            .foregroundColor(colorScheme == .dark ? .white : .primary)
                    }
                    ProgressView(value: progress.reviewProgress)
                        .tint(.green)
                }
                
                // 待复习
                if progress.dueCount > 0 {
                    HStack {
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("还有 \(progress.dueCount) 个单词待复习")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
    }
}

// 大尺寸小组件
struct LargeWidgetView: View {
    let progress: WidgetProgress
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            // 顶部标题区
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日学习进度")
                        .font(.title3.bold())
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    Text(Date(), style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 连续打卡
                if progress.streakDays > 0 {
                    VStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                        Text("\(progress.streakDays)")
                            .font(.title3.bold())
                            .foregroundColor(.orange)
                        Text("连续天数")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 大圆形进度
            ZStack {
                Circle()
                    .stroke(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 16)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .trim(from: 0, to: progress.overallProgress)
                    .stroke(
                        AngularGradient(
                            colors: [.purple, .blue, .purple],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 140, height: 140)
                
                VStack(spacing: 4) {
                    Text("\(Int(progress.overallProgress * 100))%")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .primary)
                    if progress.isGoalCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
            }
            
            // 详细统计
            HStack(spacing: 20) {
                StatBox(
                    icon: "sparkles",
                    color: .blue,
                    value: "\(progress.studiedCount)/\(progress.newWordsGoal)",
                    label: "新词学习",
                    progress: progress.newWordsProgress,
                    colorScheme: colorScheme
                )
                
                StatBox(
                    icon: "arrow.clockwise",
                    color: .green,
                    value: "\(progress.reviewCount)/\(progress.reviewGoal)",
                    label: "单词复习",
                    progress: progress.reviewProgress,
                    colorScheme: colorScheme
                )
                
                StatBox(
                    icon: "bell.fill",
                    color: .orange,
                    value: "\(progress.dueCount)",
                    label: "待复习",
                    progress: nil,
                    colorScheme: colorScheme
                )
            }
            
            // 底部提示
            if progress.isGoalCompleted {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("今日目标已完成！继续保持！")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            } else {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundColor(.purple)
                    Text("点击开始学习")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
    }
}

struct StatBox: View {
    let icon: String
    let color: Color
    let value: String
    let label: String
    let progress: Double?
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title3.bold())
                .foregroundColor(colorScheme == .dark ? .white : .primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let progress = progress {
                ProgressView(value: progress)
                    .tint(color)
                    .scaleEffect(y: 1.5)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(color.opacity(colorScheme == .dark ? 0.15 : 0.1))
        .cornerRadius(12)
    }
}

// MARK: - 锁屏小组件视图

struct AccessoryCircularView: View {
    let progress: WidgetProgress
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            Circle()
                .stroke(.gray.opacity(0.3), lineWidth: 6)
            
            Circle()
                .trim(from: 0, to: progress.overallProgress)
                .stroke(.purple, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 0) {
                Text("\(Int(progress.overallProgress * 100))%")
                    .font(.system(size: 16, weight: .bold))
                if progress.streakDays > 0 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

struct AccessoryRectangularView: View {
    let progress: WidgetProgress
    
    var body: some View {
        HStack(spacing: 12) {
            // 进度环
            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 36, height: 36)
                
                Circle()
                    .trim(from: 0, to: progress.overallProgress)
                    .stroke(.purple, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(progress.overallProgress * 100))")
                    .font(.system(size: 12, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("今日学习")
                    .font(.system(size: 14, weight: .semibold))
                
                HStack(spacing: 8) {
                    Label("\(progress.studiedCount)/\(progress.newWordsGoal)", systemImage: "sparkles")
                        .font(.system(size: 11))
                    Label("\(progress.reviewCount)/\(progress.reviewGoal)", systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                
                if progress.streakDays > 0 {
                    Label("\(progress.streakDays)天", systemImage: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

struct AccessoryInlineView: View {
    let progress: WidgetProgress
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "book.fill")
            Text("\(progress.studiedCount)/\(progress.newWordsGoal)")
            if progress.streakDays > 0 {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("\(progress.streakDays)")
            }
        }
    }
}

// MARK: - 连续打卡小组件

struct StreakSmallView: View {
    let progress: WidgetProgress
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                Spacer()
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("\(progress.streakDays)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : .primary)
                Text("连续天数")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("继续保持！")
                .font(.caption2)
                .foregroundColor(.orange)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    colorScheme == .dark ? Color.orange.opacity(0.2) : Color.orange.opacity(0.1),
                    colorScheme == .dark ? Color.red.opacity(0.15) : Color.red.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct StreakCircularView: View {
    let progress: WidgetProgress
    
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            Image(systemName: "flame.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            Text("\(progress.streakDays)")
                .font(.system(size: 14, weight: .bold))
                .offset(y: 14)
        }
    }
}

// MARK: - Preview

struct EarWordsWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TodayProgressWidgetView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")
            
            TodayProgressWidgetView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")
            
            TodayProgressWidgetView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large")
            
            TodayProgressWidgetView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("Circular")
            
            TodayProgressWidgetView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("Rectangular")
        }
    }
}
