# EarWords 架构设计文档

> 本文档描述 EarWords 应用的整体架构、模块设计和数据流。

---

## 📐 架构概览

### 架构模式

EarWords 采用 **MVVM (Model-View-ViewModel)** 架构模式，结合 **Repository 模式** 进行数据管理。

```
┌─────────────────────────────────────────────────────────────┐
│                        Presentation Layer                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Views     │  │  ViewModels │  │     Widgets         │  │
│  │  (SwiftUI)  │◄─┤   (State)   │  │  (WidgetKit)        │  │
│  └─────────────┘  └──────┬──────┘  └─────────────────────┘  │
└──────────────────────────┼──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                        Business Logic Layer                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Managers   │  │  Algorithms │  │   Importers         │  │
│  │  (Use Cases)│  │   (SM-2)    │  │  (Data Import)      │  │
│  └──────┬──────┘  └─────────────┘  └─────────────────────┘  │
└─────────┼─────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│                         Data Layer                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Core Data  │  │   Models    │  │    CloudKit         │  │
│  │ (Local DB)  │  │  (Entities) │  │   (Sync)            │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🗂️ 模块划分

### 1. Presentation Layer (表现层)

#### Views (视图)
- **StudyView** - 主学习界面
- **AudioReviewView** - 磨耳朵界面
- **StatisticsView** - 统计界面
- **ChapterListView** - 章节列表
- **SettingsView** - 设置界面

#### ViewModels (视图模型)
- **StudyViewModel** - 学习状态管理
- **UserSettingsViewModel** - 用户设置管理

#### Widgets (小组件)
- **TodayProgressWidget** - 今日进度
- **LockScreenProgressWidget** - 锁屏进度

### 2. Business Logic Layer (业务逻辑层)

#### Managers (管理器)
| 管理器 | 职责 |
|--------|------|
| **DataManager** | Core Data 操作、数据查询、统计计算 |
| **StudyManager** | 学习队列管理、复习调度 |
| **AudioPlayerManager** | 音频播放控制、队列管理 |
| **NotificationManager** | 本地通知管理 |
| **VocabularyImporter** | 词库导入处理 |

#### Algorithms (算法)
| 算法 | 说明 |
|------|------|
| **SM2Algorithm** | 间隔重复核心算法 |
| **ReviewQuality** | 复习质量评分枚举 |

### 3. Data Layer (数据层)

#### Core Data Entities
| 实体 | 用途 |
|------|------|
| **WordEntity** | 单词数据 |
| **ReviewLogEntity** | 复习记录 |
| **UserSettingsEntity** | 用户设置 |

#### CloudKit
- 自动同步 Core Data 到 iCloud
- 跨设备数据同步

---

## 🔄 数据流

### 学习流程数据流

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  User       │     │  StudyView  │     │ StudyViewModel
│  Action     │────▶│  (SwiftUI)  │────▶│   (State)   │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                                               ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Core Data  │◄────│ DataManager │◄────│ StudyManager│
│  (Persist)  │     │  (Repository)│     │  (Logic)    │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐
                                        │ SM2Algorithm│
                                        │  (Calculate)│
                                        └─────────────┘
```

### 音频播放数据流

```
┌─────────────────┐
│ AudioReviewView │
│   (UI Control)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│AudioPlayerManager│────▶│  AVAudioPlayer  │
│  (Controller)   │     │   (Playback)    │
└────────┬────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│ PlaybackQueue   │────▶│  MPNowPlaying   │
│   (Queue)       │     │  (Lock Screen)  │
└─────────────────┘     └─────────────────┘
```

---

## 🧩 核心组件详解

### DataManager

**职责**: 管理所有 Core Data 操作

```swift
class DataManager: ObservableObject {
    // 单例访问
    static let shared: DataManager
    
    // 发布属性（UI 订阅）
    @Published var todayNewWordsCount: Int
    @Published var todayReviewCount: Int
    @Published var dueWordsCount: Int
    
    // 数据操作
    func fetchNewWords(limit: Int) -> [WordEntity]
    func fetchDueWords(limit: Int) -> [WordEntity]
    func logReview(word: WordEntity, quality: ReviewQuality) -> ReviewLogEntity
    
    // 统计计算
    func getTodayStatistics() -> TodayStatistics
    func calculateStreak() -> (current: Int, longest: Int)
    func getLearningTrendData(days: Int) -> [DailyDataPoint]
}
```

### StudyManager

**职责**: 管理学习会话和队列

```swift
class StudyManager: ObservableObject {
    // 学习队列
    func generateTodayStudyQueue() async -> (newWords: [WordEntity], reviewWords: [WordEntity])
    func createStudySession() async -> StudySession?
    
    // 评分记录
    func submitReview(word: WordEntity, quality: ReviewQuality, timeSpent: TimeInterval)
    
    // 统计
    var todayStats: DailyStudyStats
}
```

### AudioPlayerManager

**职责**: 音频播放控制

```swift
class AudioPlayerManager: NSObject, ObservableObject {
    // 播放状态
    @Published var currentState: PlayerState
    @Published var currentItem: PlaybackQueueItem?
    @Published var progress: Double
    
    // 队列管理
    func setPlaylist(words: [WordEntity], mode: PlaybackMode)
    func play(), pause(), stop()
    func nextTrack(), previousTrack()
    
    // 设置
    func setPlaybackSpeed(_ speed: Float)
    func setPlaybackMode(_ mode: PlaybackMode)
}
```

### SM2Algorithm

**职责**: 计算复习间隔

```swift
struct SM2Algorithm {
    // 核心算法
    static func calculateNextReview(
        quality: ReviewQuality,
        currentEaseFactor: Double,
        currentInterval: Int,
        reviewCount: Int
    ) -> (interval: Int, easeFactor: Double, shouldRepeat: Bool)
    
    // 下次复习日期
    static func nextReviewDate(interval: Int) -> Date
}
```

---

## 📊 数据模型

### WordEntity (单词实体)

```
┌─────────────────────────────────────────────────┐
│ WordEntity                                      │
├─────────────────────────────────────────────────┤
│ id: Int32                    # 唯一标识         │
│ word: String                 # 单词文本         │
│ phonetic: String?            # 音标             │
│ pos: String?                 # 词性             │
│ meaning: String              # 释义             │
│ example: String?             # 例句             │
│ chapter: String              # 章节名           │
│ chapterKey: String           # 章节键           │
│ difficulty: Int16            # 难度 1-5        │
├─────────────────────────────────────────────────┤
│ # 学习状态 (SM-2)                               │
│ status: String               # new/learning/   │
│                              # mastered         │
│ reviewCount: Int16           # 复习次数         │
│ nextReviewDate: Date?        # 下次复习日       │
│ lastReviewDate: Date?        # 上次复习日       │
│ easeFactor: Double           # 简易度 (2.5)    │
│ interval: Int32              # 间隔天数         │
├─────────────────────────────────────────────────┤
│ # 统计                                          │
│ correctCount: Int16          # 正确次数         │
│ incorrectCount: Int16        # 错误次数         │
│ streak: Int16                # 连续正确         │
│ createdAt: Date              # 创建时间         │
│ updatedAt: Date              # 更新时间         │
└─────────────────────────────────────────────────┘
```

### ReviewLogEntity (复习记录)

```
┌─────────────────────────────────────────────────┐
│ ReviewLogEntity                                 │
├─────────────────────────────────────────────────┤
│ id: UUID                     # 唯一标识         │
│ wordId: Int32                # 单词ID           │
│ word: String                 # 单词文本         │
│ reviewDate: Date             # 复习时间         │
│ quality: Int16               # 评分 0-5        │
│ result: String               # correct/incorrect│
│ previousEaseFactor: Double   # 旧简易度         │
│ newEaseFactor: Double        # 新简易度         │
│ previousInterval: Int32      # 旧间隔           │
│ newInterval: Int32           # 新间隔           │
│ timeSpent: Double            # 学习耗时         │
│ studyMode: String            # 学习模式         │
└─────────────────────────────────────────────────┘
```

---

## 🔄 状态管理

### 应用状态流转

```
┌─────────┐    启动     ┌─────────┐   导入词库   ┌─────────┐
│  Idle   │────────────▶│ Loading │─────────────▶│  Ready  │
└─────────┘             └─────────┘              └────┬────┘
                                                      │
         ┌────────────────────────────────────────────┘
         │
         ▼
┌─────────┐   开始     ┌─────────┐   评分     ┌─────────┐
│ Studying│◄───────────│  Ready  │───────────▶│Reviewing│
└────┬────┘            └─────────┘            └────┬────┘
     │                                              │
     │ 完成                                         │
     ▼                                              │
┌─────────┐   全部完成                              │
│ Complete│─────────────────────────────────────────┘
└─────────┘
```

### 单词状态流转

```
                    ┌─────────────┐
         ┌─────────│    New      │◄────────┐
         │         │   (新词)     │         │
         │         └──────┬──────┘         │
         │                │ 第一次复习      │
         │                ▼                │
         │         ┌─────────────┐         │
         │         │  Learning   │         │
  评分&lt;2  │         │  (学习中)   │         │
         │         └──────┬──────┘         │
         │                │                │
         │                │ 连续3次正确     │
         │                │ 间隔>=7天      │
         │                ▼                │
         │         ┌─────────────┐         │
         └────────▶│  Mastered   │─────────┘
                   │  (已掌握)   │  忘记
                   └─────────────┘
```

---

## 🔐 数据安全

### 本地数据
- Core Data SQLite 数据库存储在应用沙盒
- 支持数据导出/导入备份

### iCloud 同步
- 使用 NSPersistentCloudKitContainer
- 自动处理数据冲突
- 支持离线使用，联网后自动同步

### 隐私保护
- 所有数据存储在用户设备
- 无第三方数据收集
- 支持完全离线使用

---

## 📱 平台适配

### iPhone
- 优化单手操作手势
- 适配全面屏安全区域
- 支持深色模式

### iPad
- 支持分屏多任务
- 适配大屏布局
- 键盘快捷键支持

### iOS 版本
- 最低支持 iOS 16.0
- 使用最新 SwiftUI API
- 向后兼容性考虑

---

## 🔧 扩展点

### 新增数据源
1. 实现 `VocabularyImporter` 协议
2. 创建新的 JSON 解析器
3. 调用 `DataManager.importVocabulary()`

### 新增学习模式
1. 在 `StudyMode` 枚举中添加新模式
2. 在 `StudyManager` 中实现模式逻辑
3. 创建对应的 UI 视图

### 新增音频源
1. 在 `AudioSource` 枚举中添加新来源
2. 在 `AudioPlayerManager.loadAudio()` 中添加加载逻辑
3. 更新 UI 显示标识

---

## 📝 设计原则

1. **单一职责**: 每个类/模块只负责一个功能领域
2. **依赖注入**: 通过构造函数注入依赖，便于测试
3. **响应式编程**: 使用 Combine 和 @Published 实现数据驱动 UI
4. **错误处理**: 所有可能失败的操作都返回 Result 或抛出错误
5. **性能优化**: 大数据操作使用后台线程，UI 更新在主线程
