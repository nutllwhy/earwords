//
//  LockScreenProgressWidget.swift
//  EarWordsWidgets
//
//  锁屏小组件 - iOS 17+
//

import WidgetKit
import SwiftUI

// MARK: - 数据提供器

struct LockScreenProgressProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> LockScreenProgressEntry {
        LockScreenProgressEntry.sample()
    }
    
    func getSnapshot(in context: Context, completion: @escaping (LockScreenProgressEntry) -> Void) {
        completion(LockScreenProgressEntry.current())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenProgressEntry>) -> Void) {
        let entry = LockScreenProgressEntry.current()
        
        // 锁屏小组件更新更频繁
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

// MARK: - 时间线条目

struct LockScreenProgressEntry: TimelineEntry {
    let date: Date
    let studiedCount: Int
    let newWordsGoal: Int
    let reviewCount: Int
    let reviewGoal: Int
    let streakDays: Int
    let isGoalCompleted: Bool
    
    var overallProgress: Double {
        let totalGoal = newWordsGoal + reviewGoal
        let totalDone = studiedCount + reviewCount
        guard totalGoal > 0 else { return 0 }
        return min(Double(totalDone) / Double(totalGoal), 1.0)
    }
    
    static func sample() -> LockScreenProgressEntry {
        LockScreenProgressEntry(
            date: Date(),
            studiedCount: 15,
            newWordsGoal: 20,
            reviewCount: 30,
            reviewGoal: 50,
            streakDays: 5,
            isGoalCompleted: false
        )
    }
    
    static func current() -> LockScreenProgressEntry {
        guard let progress = WidgetDataReader.read() else {
            return sample()
        }
        
        return LockScreenProgressEntry(
            date: Date(),
            studiedCount: progress.studiedCount,
            newWordsGoal: progress.newWordsGoal,
            reviewCount: progress.reviewCount,
            reviewGoal: progress.reviewGoal,
            streakDays: progress.streakDays,
            isGoalCompleted: progress.isGoalCompleted
        )
    }
}

// MARK: - 锁屏小组件视图

struct LockScreenProgressWidgetEntryView: View {
    var entry: LockScreenProgressProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularLockScreenView(entry: entry)
        case .accessoryRectangular:
            RectangularLockScreenView(entry: entry)
        case .accessoryInline:
            InlineLockScreenView(entry: entry)
        @unknown default:
            CircularLockScreenView(entry: entry)
        }
    }
}

// MARK: - 小组件定义

struct LockScreenProgressWidget: Widget {
    let kind: String = "com.earwords.widget.lockscreen"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProgressProvider()) { entry in
            LockScreenProgressWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("学习进度")
        .description("在锁屏界面查看今日学习进度")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - 子视图

struct CircularLockScreenView: View {
    let entry: LockScreenProgressEntry
    @Environment(\.widgetRenderingMode) var renderingMode
    
    var body: some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(.gray.opacity(0.3), lineWidth: 6)
            
            // 进度圆环
            Circle()
                .trim(from: 0, to: entry.overallProgress)
                .stroke(
                    renderingMode == .fullColor ? 
                        Color.purple.gradient :
                        Color.white.gradient,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // 中心内容
            VStack(spacing: 0) {
                if entry.isGoalCompleted {
                    Image(systemName: "checkmark")
                        .font(.title3)
                        .fontWeight(.bold)
                } else {
                    Text("\(Int(entry.overallProgress * 100))%")
                        .font(.system(size: 14, weight: .bold))
                }
                
                if entry.streakDays > 0 {
                    HStack(spacing: 1) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                        Text("\(entry.streakDays)")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }
}

struct RectangularLockScreenView: View {
    let entry: LockScreenProgressEntry
    @Environment(\.widgetRenderingMode) var renderingMode
    
    var accentColor: Color {
        renderingMode == .fullColor ? .purple : .white
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 左侧进度环
            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 36, height: 36)
                
                Circle()
                    .trim(from: 0, to: entry.overallProgress)
                    .stroke(
                        accentColor,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                
                if entry.isGoalCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                } else {
                    Text("\(Int(entry.overallProgress * 100))")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            
            // 右侧信息
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.caption)
                    Text("\(entry.studiedCount)/\(entry.newWordsGoal)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(accentColor)
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                    Text("\(entry.reviewCount)/\(entry.reviewGoal)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.blue)
                
                if entry.streakDays > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                        Text("\(entry.streakDays) 天连续")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
        }
    }
}

struct InlineLockScreenView: View {
    let entry: LockScreenProgressEntry
    @Environment(\.widgetRenderingMode) var renderingMode
    
    var accentColor: Color {
        renderingMode == .fullColor ? .purple : .white
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.isGoalCompleted ? "checkmark.circle.fill" : "book.fill")
                .foregroundColor(entry.isGoalCompleted ? .green : accentColor)
            
            Text("\(entry.studiedCount)/\(entry.newWordsGoal) 词")
                .fontWeight(.medium)
            
            if entry.streakDays > 0 {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("\(entry.streakDays)")
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - 预览

struct LockScreenProgressWidget_Previews: PreviewProvider {
    static var previews: some View {
        LockScreenProgressWidgetEntryView(entry: LockScreenProgressEntry.sample())
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular")
        
        LockScreenProgressWidgetEntryView(entry: LockScreenProgressEntry.sample())
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Rectangular")
        
        LockScreenProgressWidgetEntryView(entry: LockScreenProgressEntry.sample())
            .previewContext(WidgetPreviewContext(family: .accessoryInline))
            .previewDisplayName("Inline")
    }
}
