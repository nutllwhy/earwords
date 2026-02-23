//
//  StatisticsView.swift
//  统计界面原型
//

import SwiftUI

struct StatisticsView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 今日概览
                    TodayOverviewCard()
                    
                    // 连续学习天数
                    StreakCard()
                    
                    // 学习趋势图
                    LearningTrendChart()
                    
                    // 词汇掌握情况
                    MasteryOverviewCard()
                    
                    // 章节进度
                    ChapterProgressList()
                }
                .padding(.vertical)
            }
            .navigationTitle("学习统计")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct TodayOverviewCard: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("今日概览")
                    .font(.headline)
                Spacer()
                Text("2026年2月24日")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 20) {
                StatItem(icon: "sparkles", color: .yellow, value: "20", label: "新学单词")
                StatItem(icon: "repeat", color: .blue, value: "35", label: "复习单词")
                StatItem(icon: "checkmark.circle", color: .green, value: "85%", label: "正确率")
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

struct StreakCard: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("🔥 连续学习")
                    .font(.headline)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("7")
                        .font(.system(size: 48, weight: .bold))
                    Text("天")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Text("最长记录: 30 天")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 火焰动画
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

struct LearningTrendChart: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习趋势")
                .font(.headline)
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach([0.4, 0.65, 0.5, 0.8, 0.7, 0.45, 0.6], id: \.self) { height in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.purple.opacity(height == 0.8 ? 1 : 0.5))
                        .frame(height: 100 * height)
                }
            }
            .frame(height: 100)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

struct MasteryOverviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("词汇掌握")
                .font(.headline)
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: geometry.size.width * 0.27)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * 0.41)
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * 0.32)
                }
            }
            .frame(height: 12)
            .cornerRadius(6)
            
            HStack(spacing: 16) {
                LegendItem(color: .gray, label: "未学习", value: 1000)
                LegendItem(color: .blue, label: "学习中", value: 1500)
                LegendItem(color: .green, label: "已掌握", value: 1174)
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

struct ChapterProgressList: View {
    let chapters = [
        ("01_自然地理", 241, 200),
        ("02_植物研究", 130, 80),
        ("03_动物保护", 168, 100),
        ("04_太空探索", 75, 50),
        ("05_学校教育", 401, 150)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("章节进度")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(chapters, id: \.0) { chapter in
                    ChapterProgressRow(
                        name: chapter.0,
                        total: chapter.1,
                        mastered: chapter.2
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
}

struct ChapterProgressRow: View {
    let name: String
    let total: Int
    let mastered: Int
    
    var progress: Double {
        Double(mastered) / Double(total)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .purple))
            }
            
            Spacer()
            
            Text("\(mastered)/\(total)")
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
    }
}

struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView()
    }
}
