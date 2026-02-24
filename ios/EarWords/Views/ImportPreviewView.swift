//
//  ImportPreviewView.swift
//  EarWords
//
//  导入功能预览测试视图 - 用于 SwiftUI Preview
//

import SwiftUI
import CoreData

struct ImportPreviewView: View {
    @StateObject private var viewModel = ImportViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 统计卡片
                StatsCard(viewModel: viewModel)
                
                // 导入控制
                ImportControlSection(viewModel: viewModel)
                
                // 章节列表
                ChapterListSection(viewModel: viewModel)
                
                Spacer()
            }
            .padding()
            .navigationTitle("词库导入测试")
            .onAppear {
                viewModel.loadStats()
            }
        }
    }
}

// MARK: - ViewModel

class ImportViewModel: ObservableObject {
    @Published var stats = VocabularyStats(total: 0, new: 0, learning: 0, mastered: 0)
    @Published var isImporting = false
    @Published var importProgress: Double = 0
    @Published var chapters: [ChapterInfo] = []
    @Published var importResult: String = ""
    
    func loadStats() {
        stats = DataManager.shared.getVocabularyStats()
        chapters = DataManager.shared.fetchAllChapters()
    }
    
    func startImport() {
        guard !isImporting else { return }
        
        isImporting = true
        importProgress = 0
        importResult = ""
        
        Task {
            do {
                // 使用绝对路径读取 JSON 文件
                let jsonPath = "/Users/nutllwhy/.openclaw/workspace/plans/earwords/data/ielts-vocabulary-with-phonetics.json"
                let jsonURL = URL(fileURLWithPath: jsonPath)
                let jsonData = try Data(contentsOf: jsonURL)
                
                try await DataManager.shared.importVocabulary(from: jsonData)
                
                await MainActor.run {
                    self.isImporting = false
                    self.importProgress = 1.0
                    self.importResult = "✅ 导入成功"
                    self.loadStats()
                }
            } catch {
                await MainActor.run {
                    self.isImporting = false
                    self.importResult = "❌ 导入失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func resetData() {
        DataManager.shared.deleteAllWords()
        loadStats()
        importResult = "数据已清空"
    }
}

// MARK: - 子视图

struct StatsCard: View {
    let viewModel: ImportViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("词库统计")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatItem(title: "总单词", value: viewModel.stats.total, color: .blue)
                StatItem(title: "新单词", value: viewModel.stats.new, color: .green)
                StatItem(title: "学习中", value: viewModel.stats.learning, color: .orange)
                StatItem(title: "已掌握", value: viewModel.stats.mastered, color: .purple)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatItem: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ImportControlSection: View {
    @ObservedObject var viewModel: ImportViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            if viewModel.isImporting {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.importProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text("导入中... \(Int(viewModel.importProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 12) {
                Button(action: { viewModel.startImport() }) {
                    Label("开始导入", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isImporting)
                
                Button(action: { viewModel.resetData() }) {
                    Label("清空数据", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(viewModel.isImporting)
            }
            
            if !viewModel.importResult.isEmpty {
                Text(viewModel.importResult)
                    .font(.caption)
                    .foregroundColor(viewModel.importResult.hasPrefix("✅") ? .green : .red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ChapterListSection: View {
    let viewModel: ImportViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("章节列表")
                    .font(.headline)
                Spacer()
                Text("共 \(viewModel.chapters.count) 章")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.chapters.isEmpty {
                Text("暂无章节数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                List(viewModel.chapters) { chapter in
                    HStack {
                        Text(chapter.name)
                        Spacer()
                        Text("\(chapter.wordCount) 词")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .listStyle(PlainListStyle())
                .frame(height: 300)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

struct ImportPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ImportPreviewView()
    }
}

// MARK: - 模拟数据测试

#if DEBUG
struct ImportTestData {
    /// 创建测试用的 WordJSON 数组
    static func createSampleWords(count: Int = 100) -> [WordJSON] {
        let chapters = [
            ("01_自然地理", "geography"),
            ("05_学校教育", "education"),
            ("21_身心健康", "health")
        ]
        
        return (1...count).map { i in
            let chapter = chapters[i % chapters.count]
            return WordJSON(
                id: i,
                word: "word_\(i)",
                phonetic: "/wɜːrd/",
                pos: "n.",
                meaning: "测试单词 \(i) 的释义",
                example: "This is an example sentence for word \(i).",
                extra: "-",
                chapter: chapter.0,
                difficulty: (i % 5) + 1,
                audioUrl: i % 2 == 0 ? "https://example.com/audio/\(i).mp3" : ""
            )
        }
    }
    
    /// 模拟导入过程
    static func simulateImport(words: [WordJSON], onProgress: @escaping (Double) -> Void) async {
        let batchSize = 20
        let total = words.count
        
        for batchStart in stride(from: 0, to: total, by: batchSize) {
            let progress = Double(min(batchStart + batchSize, total)) / Double(total)
            onProgress(progress)
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms 模拟延迟
        }
    }
}
#endif
