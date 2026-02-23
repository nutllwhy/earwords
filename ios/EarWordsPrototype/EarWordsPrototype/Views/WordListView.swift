//
//  WordListView.swift
//  词库界面原型
//

import SwiftUI

struct WordListView: View {
    @State private var searchText = ""
    @State private var selectedChapter: String? = nil
    
    let chapters = [
        "01_自然地理", "02_植物研究", "03_动物保护", "04_太空探索",
        "05_学校教育", "06_科技发明", "07_文化历史", "08_语言演化"
    ]
    
    let words = [
        ("atmosphere", "大气层；氛围", "new"),
        ("hydrosphere", "水圈；大气中的水汽", "learning"),
        ("oxygen", "氧气", "mastered"),
        ("lion", "狮子", "learning"),
        ("tiger", "老虎", "new")
    ]
    
    var body: some View {
        NavigationView {
            List {
                // 搜索栏
                SearchBar(text: $searchText)
                
                // 章节选择
                Section("按章节") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ChapterChip(
                                title: "全部",
                                isSelected: selectedChapter == nil
                            ) {
                                selectedChapter = nil
                            }
                            
                            ForEach(chapters, id: \.self) { chapter in
                                ChapterChip(
                                    title: String(chapter.dropFirst(3)),
                                    isSelected: selectedChapter == chapter
                                ) {
                                    selectedChapter = chapter
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // 单词列表
                Section("单词列表") {
                    ForEach(words, id: \.0) { word in
                        WordListRow(
                            word: word.0,
                            meaning: word.1,
                            status: word.2
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("词库")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索单词", text: $text)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ChapterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.purple : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct WordListRow: View {
    let word: String
    let meaning: String
    let status: String
    
    var statusColor: Color {
        switch status {
        case "new": return .gray
        case "learning": return .blue
        case "mastered": return .green
        default: return .gray
        }
    }
    
    var statusLabel: String {
        switch status {
        case "new": return "未学习"
        case "learning": return "学习中"
        case "mastered": return "已掌握"
        default: return status
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(word)
                    .font(.headline)
                
                Text(meaning)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(statusLabel)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.2))
                .foregroundColor(statusColor)
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

struct WordListView_Previews: PreviewProvider {
    static var previews: some View {
        WordListView()
    }
}
