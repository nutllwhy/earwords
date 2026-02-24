# EarWords 开发者指南

> 本文档为开发者提供项目开发、调试和贡献的详细指南。

---

## 🏗️ 项目结构

### 目录组织原则

```
EarWords/
├── Algorithms/     # 算法实现（纯逻辑，无 UI 依赖）
├── Managers/       # 业务逻辑管理器（单例模式）
├── Models/         # Core Data 实体和数据模型
├── Views/          # SwiftUI 视图
├── ViewModels/     # 视图状态管理
├── Resources/      # 主题、常量、配置
└── Widgets/        # 小组件相关
```

### 文件命名规范

| 类型 | 命名规则 | 示例 |
|------|----------|------|
| 视图 | `XXXView.swift` | `StudyView.swift` |
| 视图模型 | `XXXViewModel.swift` | `StudyViewModel.swift` |
| 管理器 | `XXXManager.swift` | `DataManager.swift` |
| 实体 | `XXXEntity.swift` | `WordEntity.swift` |
| 算法 | `XXXAlgorithm.swift` | `SM2Algorithm.swift` |
| 测试 | `XXXTests.swift` | `DataManagerTests.swift` |

---

## 🔧 开发环境

### 必要工具

- **Xcode 15.0+** - 主要开发环境
- **SwiftLint** - 代码规范检查
```bash
brew install swiftlint
```

### 可选工具

- **SwiftFormat** - 代码格式化
```bash
brew install swiftformat
```

- **Periphery** - 查找未使用代码
```bash
brew install periphery
```

### Xcode 配置

1. **启用代码折叠**
   - Editor → Code Folding → Fold All Methods

2. **设置缩进**
   - Preferences → Text Editing → Indentation
   - Tab: 4 spaces
   - Indent: 4 spaces

3. **SwiftLint 集成**
   - Build Phases → + → New Run Script Phase
   - 添加: `swiftlint`

---

## 📝 代码规范

### Swift 风格指南

遵循 [Google Swift Style Guide](https://google.github.io/swift/) 基本原则：

#### 命名规范

```swift
// 类型名：大驼峰
struct StudySession { }
class DataManager { }
enum ReviewQuality { }

// 函数/变量：小驼峰
func fetchNewWords(limit: Int) -> [WordEntity]
var todayNewWordsCount: Int = 0

// 常量：小驼峰
let maxInterval: Int = 365
let defaultEaseFactor: Double = 2.5

// 布尔值：使用 is/has/should 前缀
var isLoading: Bool = false
var hasMoreData: Bool = true
```

#### 代码组织

```swift
class ExampleManager {
    
    // MARK: - Properties
    
    // MARK: - Public Properties
    @Published var publicProperty: String = ""
    
    // MARK: - Private Properties
    private var privateProperty: String = ""
    
    // MARK: - Initialization
    init() { }
    
    // MARK: - Public Methods
    func publicMethod() { }
    
    // MARK: - Private Methods
    private func privateMethod() { }
}
```

#### 文档注释

```swift
/// 计算下次复习数据
/// - Parameters:
///   - quality: 复习质量评分 (0-5)
///   - currentEaseFactor: 当前简易度
///   - currentInterval: 当前间隔天数
///   - reviewCount: 已复习次数
/// - Returns: 新的复习参数 (interval, easeFactor, shouldRepeat)
static func calculateNextReview(
    quality: ReviewQuality,
    currentEaseFactor: Double,
    currentInterval: Int,
    reviewCount: Int
) -> (interval: Int, easeFactor: Double, shouldRepeat: Bool)
```

---

## 🧪 测试指南

### 测试结构

```
EarWordsTests/
├── SM2AlgorithmTests.swift      # 算法单元测试
├── DataManagerTests.swift       # 数据管理测试
├── StudyManagerTests.swift      # 学习管理测试
├── IntegrationTests.swift       # 集成测试
└── PerformanceTests.swift       # 性能测试
```

### 编写测试

```swift
import XCTest
@testable import EarWords

final class SM2AlgorithmTests: XCTestCase {
    
    // MARK: - 基础计算测试
    
    func testCalculateNextReview_BlackOut() {
        let result = SM2Algorithm.calculateNextReview(
            quality: .blackOut,
            currentEaseFactor: 2.5,
            currentInterval: 1,
            reviewCount: 1
        )
        
        XCTAssertEqual(result.interval, 0)
        XCTAssertTrue(result.shouldRepeat)
    }
    
    func testCalculateNextReview_Perfect() {
        let result = SM2Algorithm.calculateNextReview(
            quality: .perfect,
            currentEaseFactor: 2.5,
            currentInterval: 7,
            reviewCount: 3
        )
        
        XCTAssertGreaterThan(result.interval, 7)
        XCTAssertFalse(result.shouldRepeat)
    }
    
    // MARK: - 性能测试
    
    func testPerformance_CalculateNextReview() {
        measure {
            for _ in 0..<1000 {
                _ = SM2Algorithm.calculateNextReview(
                    quality: .good,
                    currentEaseFactor: 2.5,
                    currentInterval: 7,
                    reviewCount: 5
                )
            }
        }
    }
}
```

### 测试最佳实践

1. **独立性**: 每个测试相互独立，不依赖执行顺序
2. **确定性**: 相同输入始终产生相同结果
3. **快速**: 单元测试应在毫秒级完成
4. **可读性**: 测试名称清晰描述测试场景

---

## 🐛 调试技巧

### 常用调试方法

#### 1. 打印日志

```swift
// 使用 print 进行简单调试
print("[Debug] 当前单词: \(word.word), 状态: \(word.status)")

// 更详细的日志
print("""
[学习记录] \(word.word)
- 评分: \(quality.rawValue) (\(quality.description))
- 旧间隔: \(previousInterval) 天 → 新间隔: \(newInterval) 天
- 旧简易度: \(String(format: "%.2f", previousEaseFactor)) → 新简易度: \(String(format: "%.2f", newEaseFactor))
""")
```

#### 2. 使用断点

```swift
// 条件断点: 当某个条件满足时暂停
// 在断点上右键 → Edit Breakpoint → Condition: word.status == "new"

// 符号断点: 在方法调用时暂停
// Breakpoint Navigator → + → Symbolic Breakpoint → Symbol: "-[DataManager logReview]"
```

#### 3. Core Data 调试

```swift
// 启用 SQL 日志输出
// Product → Scheme → Edit Scheme → Run → Arguments → Arguments Passed On Launch
// 添加: -com.apple.CoreData.SQLDebug 1

// 查看持久化存储
let storeURL = DataManager.shared.persistentContainer.persistentStoreDescriptions.first?.url
print("Core Data 存储路径: \(storeURL?.path ?? "未知")")
```

#### 4. 性能分析

```swift
// 测量代码执行时间
let startTime = CFAbsoluteTimeGetCurrent()
// ... 待测量的代码
let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
print("执行时间: \(timeElapsed) 秒")
```

### 常见问题排查

#### 问题: iCloud 同步不生效

```swift
// 1. 检查 CloudKit 容器配置
print("CloudKit 容器: \(DataManager.shared.persistentContainer.persistentStoreDescriptions.first?.cloudKitContainerOptions?.containerIdentifier ?? "未配置")")

// 2. 检查网络状态
if !NetworkMonitor.shared.isConnected {
    print("无网络连接，同步将延迟")
}

// 3. 强制刷新
DataManager.shared.persistentContainer.viewContext.refreshAllObjects()
```

#### 问题: 音频播放失败

```swift
// 检查音频会话配置
print("音频会话类别: \(AVAudioSession.sharedInstance().category)")
print("音频会话模式: \(AVAudioSession.sharedInstance().mode)")

// 检查音频文件
if let player = AudioPlayerManager.shared.audioPlayer {
    print("音频时长: \(player.duration) 秒")
    print("当前时间: \(player.currentTime) 秒")
}

// 检查错误
AudioPlayerManager.shared.$currentState.sink { state in
    if case .error(let message) = state {
        print("播放错误: \(message)")
    }
}.store(in: &cancellables)
```

---

## 🔌 扩展开发

### 添加新的单词数据源

```swift
// 1. 创建新的导入器
protocol VocabularyImporter {
    func importVocabulary(from source: URL) async throws -> [WordJSON]
}

// 2. 实现具体导入器
struct CSVVocabularyImporter: VocabularyImporter {
    func importVocabulary(from source: URL) async throws -> [WordJSON] {
        // 实现 CSV 解析逻辑
    }
}

// 3. 使用
let importer = CSVVocabularyImporter()
let words = try await importer.importVocabulary(from: csvURL)
```

### 添加新的学习模式

```swift
// 1. 在 StudyMode 枚举中添加新模式
enum StudyMode: String {
    case normal = "normal"
    case audio = "audio"
    case quick = "quick"
    case test = "test"
    case spelling = "spelling"  // 新增拼写模式
}

// 2. 在 StudyManager 中实现模式逻辑
extension StudyManager {
    func startSpellingMode() async -> StudySession? {
        // 实现拼写模式逻辑
    }
}

// 3. 创建对应视图
struct SpellingModeView: View {
    @StateObject private var viewModel = SpellingModeViewModel()
    // ...
}
```

### 添加新的统计图表

```swift
// 1. 创建数据模型
struct WeeklyProgressData: Identifiable {
    let id = UUID()
    let week: String
    let newWords: Int
    let reviews: Int
}

// 2. 在 DataManager 中添加计算
extension DataManager {
    func getWeeklyProgressData() -> [WeeklyProgressData] {
        // 实现周数据统计
    }
}

// 3. 创建图表视图
struct WeeklyProgressChart: View {
    let data: [WeeklyProgressData]
    
    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("Week", item.week),
                y: .value("Count", item.newWords + item.reviews)
            )
        }
    }
}
```

---

## 📦 发布流程

### 版本号规则

遵循 [Semantic Versioning](https://semver.org/):

- **MAJOR**: 不兼容的 API 更改
- **MINOR**: 向后兼容的功能添加
- **PATCH**: 向后兼容的问题修复

### 发布检查清单

- [ ] 更新 `CHANGELOG.md`
- [ ] 更新版本号（Info.plist 和项目设置）
- [ ] 运行所有测试
- [ ] 检查 SwiftLint 警告
- [ ] 更新文档
- [ ] 创建 Git Tag
- [ ] 归档构建
- [ ] 上传到 App Store Connect

### 构建脚本

```bash
#!/bin/bash
# build.sh - 自动化构建脚本

# 1. 清理
cd ios/EarWords
rm -rf build/

# 2. 运行测试
xcodebuild test -scheme EarWords -destination 'platform=iOS Simulator,name=iPhone 15'

# 3. 构建归档
xcodebuild archive \
    -scheme EarWords \
    -archivePath build/EarWords.xcarchive \
    -destination 'generic/platform=iOS'

# 4. 导出 IPA
xcodebuild -exportArchive \
    -archivePath build/EarWords.xcarchive \
    -exportPath build/ \
    -exportOptionsPlist exportOptions.plist
```

---

## 📚 参考资源

### 官方文档

- [Swift 文档](https://docs.swift.org/swift-book/)
- [SwiftUI 文档](https://developer.apple.com/documentation/swiftui)
- [Core Data 文档](https://developer.apple.com/documentation/coredata)
- [CloudKit 文档](https://developer.apple.com/documentation/cloudkit)

### 学习资源

- [SM-2 算法详解](https://www.supermemo.com/en/archives1990-2015/english/ol/sm2)
- [SwiftUI 最佳实践](https://developer.apple.com/documentation/swiftui/app-essentials)
- [iOS 人机界面指南](https://developer.apple.com/design/human-interface-guidelines/ios/overview/themes/)

---

## 💬 获取帮助

- 查看 [GitHub Issues](https://github.com/nutllwhy/earwords/issues)
- 发起 [Discussion](https://github.com/nutllwhy/earwords/discussions)
- 阅读 [FAQ](docs/FAQ.md)
