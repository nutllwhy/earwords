//
//  WordListView.swift
//  EarWords
//
//  单词列表 - 词库浏览
//

import SwiftUI

struct WordListView: View {
    let chapterKey: String?
    let chapterName: String
    
    @StateObject private var viewModel: WordListViewModel
    @State private var searchText = ""
    @State private var selectedStatus: WordStatusFilter = .all
    
    init(chapterKey: String?, chapterName: String) {
        self.chapterKey = chapterKey
        self.chapterName = chapterName
        _viewModel = StateObject(wrappedValue: WordListViewModel(chapterKey: chapterKey))
    }
    
    var body: some View {
        List {
            // 筛选器
            Section {
                Picker("学习状态", selection: $selectedStatus) {
                    ForEach(WordStatusFilter.allCases) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedStatus) { _ in
                    viewModel.filterWords(status: selectedStatus, searchQuery: searchText)
                }
            }
            
            // 统计信息
            Section {
                WordStatsRow(stats: viewModel.currentStats)
            }
            
            // 单词列表
            Section(header: Text("单词列表 (\(viewModel.filteredWords.count))")) {
                ForEach(viewModel.filteredWords) { word in
                    NavigationLink(destination: WordDetailView(word: word)) {
                        WordListRow(word: word, highlightText: searchText)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle(chapterName)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索单词或释义")
        .onChange(of: searchText) { query in
            viewModel.filterWords(status: selectedStatus, searchQuery: query)
        }
        .refreshable {
            viewModel.loadWords()
            viewModel.filterWords(status: selectedStatus, searchQuery: searchText)
        }
        .onAppear {
            viewModel.loadWords()
            viewModel.filterWords(status: selectedStatus, searchQuery: searchText)
        }
    }
}

// MARK: - 单词状态筛选

enum WordStatusFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case new = "new"
    case learning = "learning"
    case mastered = "mastered"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all: return "全部"
        case .new: return "未学"
        case .learning: return "学习中"
        case .mastered: return "已掌握"
        }
    }
    
    var statusString: String? {
        switch self {
        case .all: return nil
        case .new: return "new"
        case .learning: return "learning"
        case .mastered: return "mastered"
        }
    }
}

// MARK: - 统计行

struct WordStatsRow: View {
    let stats: WordListStats
    
    var body: some View {
        HStack(spacing: 20) {
            StatBadge(count: stats.new, label: "未学习", color: .gray)
            StatBadge(count: stats.learning, label: "学习中", color: .blue)
            StatBadge(count: stats.mastered, label: "已掌握", color: .green)
        }
        .padding(.vertical, 8)
    }
}

struct StatBadge: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3.weight(.bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 单词列表行

struct WordListRow: View {
    let word: WordEntity
    var highlightText: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // 状态指示器
            StatusIndicator(status: word.status)
            
            // 收藏标记
            if word.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // 单词（带高亮）
                HStack(spacing: 8) {
                    HighlightedText(text: word.word, highlight: highlightText)
                        .font(.headline)
                    
                    if let phonetic = word.phonetic, !phonetic.isEmpty {
                        Text(phonetic)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 释义（带高亮）
                HighlightedText(
                    text: word.meaningPreview,
                    highlight: highlightText,
                    highlightColor: .orange
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
            
            Spacer()
            
            // 复习次数
            if word.reviewCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("复习")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(word.reviewCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 高亮文本组件
struct HighlightedText: View {
    let text: String
    let highlight: String
    var highlightColor: Color = .yellow
    
    var body: some View {
        if highlight.isEmpty {
            Text(text)
        } else {
            highlightedText()
        }
    }
    
    private func highlightedText() -> Text {
        // 使用本地化大小写不敏感搜索
        let lowerText = text.lowercased()
        let lowerHighlight = highlight.lowercased()
        
        var result = Text("")
        var searchRange = lowerText.startIndex..<lowerText.endIndex
        
        while let range = lowerText.range(of: lowerHighlight, options: [], range: searchRange) {
            // 高亮前的文本
            let beforeRange = searchRange.lowerBound..<range.lowerBound
            if !beforeRange.isEmpty {
                let beforeText = String(text[beforeRange])
                result = result + Text(beforeText)
            }
            
            // 高亮文本
            let matchedText = String(text[range])
            result = result + Text(matchedText)
                .background(highlightColor.opacity(0.5))
                .fontWeight(.semibold)
            
            // 更新搜索范围
            searchRange = range.upperBound..<lowerText.endIndex
        }
        
        // 剩余文本
        if searchRange.lowerBound < text.endIndex {
            let remainingText = String(text[searchRange.lowerBound...])
            result = result + Text(remainingText)
        }
        
        return result
    }
}

// MARK: - 状态指示器

struct StatusIndicator: View {
    let status: String
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }
    
    var statusColor: Color {
        switch status {
        case "new":
            return .gray.opacity(0.5)
        case "learning":
            return .blue
        case "mastered":
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - WordEntity 扩展

extension WordEntity {
    var meaningPreview: String {
        let maxLength = 30
        if meaning.count > maxLength {
            return String(meaning.prefix(maxLength)) + "..."
        }
        return meaning
    }
}

// MARK: - 统计模型

struct WordListStats {
    let new: Int
    let learning: Int
    let mastered: Int
    
    var total: Int {
        new + learning + mastered
    }
}

// MARK: - ViewModel

class WordListViewModel: ObservableObject {
    @Published var words: [WordEntity] = []
    @Published var filteredWords: [WordEntity] = []
    @Published var currentStats = WordListStats(new: 0, learning: 0, mastered: 0)
    
    private let chapterKey: String?
    private let dataManager = DataManager.shared
    
    init(chapterKey: String?) {
        self.chapterKey = chapterKey
    }
    
    func loadWords() {
        if let chapterKey = chapterKey {
            words = dataManager.fetchWordsByChapter(chapterKey: chapterKey)
        } else {
            // 加载全部单词（限制数量）
            words = dataManager.fetchWordsByStatus(status: "new", limit: 100) +
                    dataManager.fetchWordsByStatus(status: "learning", limit: 100) +
                    dataManager.fetchWordsByStatus(status: "mastered", limit: 100)
        }
        updateStats()
    }
    
    func filterWords(status: WordStatusFilter, searchQuery: String) {
        var result = words
        
        // 按状态筛选
        if let statusString = status.statusString {
            result = result.filter { $0.status == statusString }
        }
        
        // 按搜索词筛选
        if !searchQuery.isEmpty {
            result = result.filter { word in
                word.word.localizedCaseInsensitiveContains(searchQuery) ||
                word.meaning.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        
        filteredWords = result
    }
    
    private func updateStats() {
        let new = words.filter { $0.status == "new" }.count
        let learning = words.filter { $0.status == "learning" }.count
        let mastered = words.filter { $0.status == "mastered" }.count
        currentStats = WordListStats(new: new, learning: learning, mastered: mastered)
    }
}

struct WordListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WordListView(chapterKey: nil, chapterName: "全部单词")
        }
    }
}
