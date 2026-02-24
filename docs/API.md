# EarWords API 文档

> 本文档描述 EarWords 的核心 API 和公开接口。

---

## 📦 DataManager

`DataManager` 是数据层的核心管理器，负责所有 Core Data 操作。

### 单例访问

```swift
let dataManager = DataManager.shared
```

### 发布属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `todayNewWordsCount` | `Int` | 今日新学单词数 |
| `todayReviewCount` | `Int` | 今日复习单词数 |
| `dueWordsCount` | `Int` | 待复习单词数 |
| `isImporting` | `Bool` | 是否正在导入词库 |
| `importProgress` | `Double` | 导入进度 (0.0-1.0) |
| `totalWordsCount` | `Int` | 总单词数 |
| `newWordsCount` | `Int` | 新单词数 |
| `learningWordsCount` | `Int` | 学习中单词数 |
| `masteredWordsCount` | `Int` | 已掌握单词数 |

### 词库导入

#### `importVocabularyFromBundle()`

从应用 Bundle 导入词库。

```swift
func importVocabularyFromBundle() async throws
```

**示例**:
```swift
do {
    try await DataManager.shared.importVocabularyFromBundle()
    print("词库导入成功")
} catch {
    print("导入失败: \(error)")
}
```

**错误**:
- `ImportError.fileNotFound` - 找不到词库文件
- `ImportError.invalidJSON` - JSON 格式错误
- `ImportError.importFailed(String)` - 导入过程失败

---

### 单词查询

#### `fetchNewWords(limit:)`

获取新单词（未学习）。

```swift
func fetchNewWords(limit: Int = 20) -> [WordEntity]
```

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `limit` | `Int` | `20` | 返回数量限制 |

**返回**: `WordEntity` 数组

**示例**:
```swift
let newWords = DataManager.shared.fetchNewWords(limit: 10)
```

---

#### `fetchDueWords(limit:)`

获取需要复习的单词。

```swift
func fetchDueWords(limit: Int = 50) -> [WordEntity]
```

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `limit` | `Int` | `50` | 返回数量限制 |

**返回**: `WordEntity` 数组

---

#### `fetchWordsByChapter(chapterKey:)`

按章节获取单词。

```swift
func fetchWordsByChapter(chapterKey: String) -> [WordEntity]
```

| 参数 | 类型 | 说明 |
|------|------|------|
| `chapterKey` | `String` | 章节键（如 "01_自然地理"） |

**示例**:
```swift
let words = DataManager.shared.fetchWordsByChapter(chapterKey: "05_学校教育")
```

---

#### `searchWords(query:status:)`

搜索单词。

```swift
func searchWords(query: String, status: String? = nil) -> [WordEntity]
```

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `query` | `String` | - | 搜索关键词 |
| `status` | `String?` | `nil` | 状态筛选（可选） |

**示例**:
```swift
// 搜索所有包含 "apple" 的单词
let results = DataManager.shared.searchWords(query: "apple")

// 只搜索已掌握的单词
let mastered = DataManager.shared.searchWords(query: "app", status: "mastered")
```

---

### 学习记录

#### `logReview(word:quality:timeSpent:mode:)`

记录单词复习。

```swift
func logReview(
    word: WordEntity,
    quality: ReviewQuality,
    timeSpent: Double = 0,
    mode: String = "normal"
) -> ReviewLogEntity
```

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `word` | `WordEntity` | - | 复习的单词 |
| `quality` | `ReviewQuality` | - | 复习质量评分 |
| `timeSpent` | `Double` | `0` | 学习耗时（秒） |
| `mode` | `String` | `"normal"` | 学习模式 |

**返回**: 创建的复习记录

**示例**:
```swift
let log = DataManager.shared.logReview(
    word: word,
    quality: .good,
    timeSpent: 3.5,
    mode: "normal"
)
```

---

### 统计计算

#### `getTodayStatistics()`

获取今日统计。

```swift
func getTodayStatistics() -> TodayStatistics
```

**返回**:
```swift
struct TodayStatistics {
    let newWords: Int      // 新学单词数
    let reviews: Int       // 复习数
    let accuracy: Double   // 正确率 (0.0-1.0)
}
```

---

#### `calculateStreak()`

计算连续学习天数。

```swift
func calculateStreak() -> (current: Int, longest: Int)
```

**返回**:
- `current`: 当前连续天数
- `longest`: 历史最长连续天数

---

#### `getLearningTrendData(days:)`

获取学习趋势数据。

```swift
func getLearningTrendData(days: Int) -> [DailyDataPoint]
```

| 参数 | 类型 | 说明 |
|------|------|------|
| `days` | `Int` | 天数（如 7 或 30） |

**返回**: 每日数据点数组

```swift
struct DailyDataPoint: Identifiable {
    let id: UUID
    let date: Date
    let newWords: Int
    let reviews: Int
    var shortDate: String   // 如 "周一"
    var dayNumber: String   // 如 "15"
}
```

---

#### `getChapterProgress()`

获取所有章节进度。

```swift
func getChapterProgress() -> [ChapterProgress]
```

**返回**:
```swift
struct ChapterProgress: Identifiable {
    let id: UUID
    let name: String      // 章节名
    let key: String       // 章节键
    let total: Int        // 总单词数
    let mastered: Int     // 已掌握数
    let learning: Int     // 学习中数
    var progress: Double  // 进度百分比 (0.0-1.0)
}
```

---

## 📦 StudyManager

`StudyManager` 管理学习会话和队列。

### 单例访问

```swift
let studyManager = StudyManager.shared
```

### 发布属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `currentSession` | `StudySession?` | 当前学习会话 |
| `todayStats` | `DailyStudyStats` | 今日学习统计 |
| `isLoading` | `Bool` | 是否加载中 |
| `errorMessage` | `String?` | 错误信息 |
| `dailyNewWordsTarget` | `Int` | 每日新词目标 |
| `dailyReviewLimit` | `Int` | 每日复习上限 |

### 学习队列

#### `fetchStudyQueue(newWordCount:reviewLimit:)`

获取学习队列。

```swift
func fetchStudyQueue(
    newWordCount: Int? = nil,
    reviewLimit: Int? = nil
) async -> StudyQueue
```

**返回**:
```swift
struct StudyQueue {
    let newWords: [WordEntity]
    let reviewWords: [WordEntity]
    let generatedAt: Date
    var totalCount: Int
    var isEmpty: Bool
    var prioritized: [WordEntity]  // 复习优先排序
}
```

---

#### `submitReview(word:quality:timeSpent:mode:)`

提交复习评分。

```swift
func submitReview(
    word: WordEntity,
    quality: ReviewQuality,
    timeSpent: TimeInterval = 0,
    mode: StudyMode = .normal
)
```

---

#### `getStudyHeatmap(days:)`

获取学习热力图数据。

```swift
func getStudyHeatmap(days: Int = 30) -> [Date: Int]
```

**返回**: 日期到学习数量的映射

---

#### `predictUpcomingReviews(for:)`

预测未来复习量。

```swift
func predictUpcomingReviews(for days: Int = 7) -> [Date: Int]
```

---

## 📦 AudioPlayerManager

`AudioPlayerManager` 控制音频播放。

### 单例访问

```swift
let audioManager = AudioPlayerManager.shared
```

### 发布属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `currentState` | `PlayerState` | 播放状态 |
| `currentItem` | `PlaybackQueueItem?` | 当前播放项 |
| `currentIndex` | `Int` | 当前索引 |
| `progress` | `Double` | 播放进度 (0.0-1.0) |
| `currentTime` | `TimeInterval` | 当前时间 |
| `totalDuration` | `TimeInterval` | 总时长 |
| `playbackMode` | `PlaybackMode` | 播放模式 |
| `queue` | `[PlaybackQueueItem]` | 播放队列 |
| `playbackSpeed` | `Float` | 播放速度 (0.5-1.0) |

### 播放控制

#### `setPlaylist(words:mode:)`

设置播放列表。

```swift
func setPlaylist(
    words: [WordEntity],
    mode: PlaybackMode = .sequential
)
```

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `words` | `[WordEntity]` | - | 单词列表 |
| `mode` | `PlaybackMode` | `.sequential` | 播放模式 |

**PlaybackMode**:
- `.sequential` - 顺序播放
- `.random` - 随机播放
- `.spaced` - 间隔重复智能排序

---

#### `play()`, `pause()`, `stop()`

播放控制。

```swift
func play()
func pause()
func stop()
```

---

#### `nextTrack()`, `previousTrack()`

切换曲目。

```swift
func nextTrack()
func previousTrack()
```

---

#### `setPlaybackSpeed(_:)`

设置播放速度。

```swift
func setPlaybackSpeed(_ speed: Float)
```

| 参数 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `speed` | `Float` | `0.5` - `1.0` | 播放速度 |

---

## 📦 SM2Algorithm

`SM2Algorithm` 实现 SM-2 间隔重复算法。

### 核心算法

#### `calculateNextReview(quality:currentEaseFactor:currentInterval:reviewCount:)`

计算下次复习数据。

```swift
static func calculateNextReview(
    quality: ReviewQuality,
    currentEaseFactor: Double,
    currentInterval: Int,
    reviewCount: Int
) -> (interval: Int, easeFactor: Double, shouldRepeat: Bool)
```

| 参数 | 类型 | 说明 |
|------|------|------|
| `quality` | `ReviewQuality` | 复习质量评分 |
| `currentEaseFactor` | `Double` | 当前简易度 |
| `currentInterval` | `Int` | 当前间隔天数 |
| `reviewCount` | `Int` | 已复习次数 |

**返回**:
- `interval`: 新的间隔天数
- `easeFactor`: 新的简易度
- `shouldRepeat`: 是否需要当天重复

**ReviewQuality**:
- `.blackOut` (0) - 完全忘记
- `.incorrect` (1) - 错误
- `.difficult` (2) - 困难
- `.hesitation` (3) - 犹豫后正确
- `.good` (4) - 正确
- `.perfect` (5) - 完美

---

#### `nextReviewDate(interval:)`

计算下次复习日期。

```swift
static func nextReviewDate(
    from date: Date = Date(),
    interval: Int
) -> Date
```

---

## 📦 WordEntity 扩展

### 应用复习

#### `applyReview(quality:timeSpent:)`

应用复习结果，更新学习状态。

```swift
func applyReview(
    quality: ReviewQuality,
    timeSpent: Double = 0
) -> ReviewResult
```

**返回**:
```swift
struct ReviewResult {
    let quality: ReviewQuality
    let previousEaseFactor: Double
    let newEaseFactor: Double
    let previousInterval: Int
    let newInterval: Int
    let shouldRepeat: Bool
    let nextReviewDate: Date
    let timeSpent: Double
    var isCorrect: Bool
    var intervalChange: Int
    var easeFactorChange: Double
}
```

---

#### `reset()`

重置单词学习状态。

```swift
func reset()
```

---

## 📦 NotificationManager

`NotificationManager` 管理本地通知。

### 权限管理

#### `requestAuthorization()`

请求通知权限。

```swift
func requestAuthorization() async -> Bool
```

---

### 学习提醒

#### `scheduleDailyReminder(at:enabled:)`

设置每日学习提醒。

```swift
func scheduleDailyReminder(
    at time: Date,
    enabled: Bool
)
```

**示例**:
```swift
var components = DateComponents()
components.hour = 20
components.minute = 0
let reminderTime = Calendar.current.date(from: components)!

NotificationManager.shared.scheduleDailyReminder(
    at: reminderTime,
    enabled: true
)
```

---

#### `sendStudyCompletionNotification(studiedCount:masteredCount:)`

发送学习完成通知。

```swift
func sendStudyCompletionNotification(
    studiedCount: Int,
    masteredCount: Int
)
```

---

## 🔄 通知名称

### 应用内通知

```swift
extension Notification.Name {
    /// 打开学习 Tab
    static let openStudyTab = Notification.Name("com.earwords.openStudyTab")
    
    /// 打开统计 Tab
    static let openStatisticsTab = Notification.Name("com.earwords.openStatisticsTab")
    
    /// 设置变更
    static let settingsChanged = Notification.Name("com.earwords.settingsChanged")
}
```

### 使用示例

```swift
// 发送通知
NotificationCenter.default.post(name: .openStudyTab, object: nil)

// 监听通知
NotificationCenter.default.publisher(for: .openStudyTab)
    .sink { _ in
        // 处理通知
    }
    .store(in: &cancellables)
```

---

## 🎨 主题常量

### 颜色

```swift
enum AppColors {
    static let primary = Color("PrimaryColor")
    static let secondary = Color("SecondaryColor")
    static let accent = Color.purple
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
}
```

### 学习相关常量

```swift
extension SM2Algorithm {
    static let minEaseFactor: Double = 1.3
    static let defaultEaseFactor: Double = 2.5
    static let maxInterval: Int = 365
}

extension StudyManager {
    static let defaultNewWordsTarget: Int = 20
    static let defaultReviewLimit: Int = 50
}
```
