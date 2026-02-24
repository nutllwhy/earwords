//
//  ChapterListView.swift
//  EarWords
//
//  章节列表 - 词库浏览入口
//

import SwiftUI

struct ChapterListView: View {
    @StateObject private var viewModel = ChapterListViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            List {
                // 全部单词入口
                NavigationLink(destination: WordListView(chapterKey: nil, chapterName: "全部单词")) {
                    AllWordsRow(stats: viewModel.totalStats)
                }
                
                // 章节列表
                Section(header: Text("章节列表 (\(viewModel.chapters.count)个章节)")) {
                    ForEach(viewModel.chapters) { chapter in
                        NavigationLink(destination: WordListView(chapterKey: chapter.key, chapterName: chapter.name)) {
                            ChapterRow(chapter: chapter)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("词库浏览")
            .searchable(text: $searchText, prompt: "搜索章节")
            .onChange(of: searchText) { query in
                viewModel.filterChapters(query: query)
            }
            .refreshable {
                viewModel.loadChapters()
            }
            .onAppear {
                viewModel.loadChapters()
            }
        }
    }
}

// MARK: - 全部单词行

struct AllWordsRow: View {
    let stats: VocabularyStats
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "books.vertical.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("全部单词")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label("\(stats.total)", systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    Label("\(stats.mastered) 已掌握", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            // 总进度
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int((Double(stats.mastered) / Double(max(stats.total, 1))) * 100))%")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.purple)
                
                ProgressView(value: Double(stats.mastered), total: Double(max(stats.total, 1)))
                    .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                    .frame(width: 50)
                    .scaleEffect(y: 1.2)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - 章节行

struct ChapterRow: View {
    let chapter: ChapterInfo
    
    var body: some View {
        HStack(spacing: 12) {
            // 章节编号
            Text(chapter.chapterNumber)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(colorForChapter(chapter.key))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.displayName)
                    .font(.subheadline.weight(.medium))
                
                Text("\(chapter.wordCount) 词")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
    
    private func colorForChapter(_ key: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .pink, .purple, .teal, .indigo]
        let hash = key.hashValue
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - 章节信息扩展

extension ChapterInfo {
    var chapterNumber: String {
        let components = key.split(separator: "_")
        if let first = components.first {
            return String(first)
        }
        return "01"
    }
    
    var displayName: String {
        let components = key.split(separator: "_")
        if components.count > 1 {
            return String(components[1...].joined(separator: "_"))
        }
        return name
    }
}

// MARK: - ViewModel

class ChapterListViewModel: ObservableObject {
    @Published var chapters: [ChapterInfo] = []
    @Published var totalStats = VocabularyStats(total: 0, new: 0, learning: 0, mastered: 0)
    
    private let dataManager = DataManager.shared
    private var allChapters: [ChapterInfo] = []
    
    func loadChapters() {
        allChapters = dataManager.fetchAllChapters()
        chapters = allChapters
        totalStats = dataManager.getVocabularyStats()
    }
    
    func filterChapters(query: String) {
        if query.isEmpty {
            chapters = allChapters
        } else {
            chapters = allChapters.filter { chapter in
                chapter.name.localizedCaseInsensitiveContains(query) ||
                chapter.key.localizedCaseInsensitiveContains(query)
            }
        }
    }
}

struct ChapterListView_Previews: PreviewProvider {
    static var previews: some View {
        ChapterListView()
    }
}
