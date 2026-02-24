# EarWords P2/P3 问题修复 - 功能说明文档

## 概述
本文档详细说明 EarWords 应用的 P2/P3 级别问题修复和功能优化。

---

## P2 问题修复

### 1. TTS降级提示与设置 ⚙️

**文件**: `Views/AudioPlayerView.swift`

**功能**:
- 当本地/在线音频不存在，使用TTS时显示提示"正在使用语音合成"
- 添加TTS设置选项：
  - 语速调节 (0.1 - 1.0)
  - 音调调节 (0.5 - 2.0)
  - 音色选择 (7种内置语音)

**关键组件**:
- `TTSSettings` - TTS设置数据模型
- `TTSSettingsManager` - 设置管理器（单例）
- `TTSDowngradeBanner` - TTS降级提示横幅
- `AudioSourceBadge` - 音频来源指示器
- `TTSSettingsView` - TTS设置界面

**使用方式**:
```swift
// TTS设置管理器
TTSSettingsManager.shared.settings.speechRate = 0.5

// 在AudioPlayerManager中使用TTS设置
let ttsSettings = TTSSettingsManager.shared.settings
utterance.rate = ttsSettings.speechRate
```

---

### 2. 学习暂停功能 ⏸️

**文件**: 
- `Views/StudyView.swift`
- `ViewModels/StudyViewModel.swift`

**功能**:
- 添加暂停按钮，支持中途保存退出
- 暂停时记录当前进度
- 暂停覆盖层显示学习进度
- 支持点击背景恢复学习

**新增属性**:
```swift
@Published var isPaused: Bool
@Published var showPauseOverlay: Bool
@Published var showShareSheet: Bool
```

**新增方法**:
```swift
func togglePause()           // 切换暂停状态
func saveAndExit()          // 保存并退出
func cleanupOnExit()        // 退出时清理
```

**UI组件**:
- 暂停/播放按钮 (Toolbar)
- 保存退出按钮 (Toolbar)
- `PauseOverlay` - 暂停覆盖层视图

---

### 3. 搜索高亮功能 🔍

**文件**: `Views/WordListView.swift`

**功能**:
- 词库搜索结果中高亮匹配文本
- 支持英文/中文高亮
- 高亮颜色区分（英文-黄色，中文-橙色）

**新增组件**:
```swift
struct HighlightedText: View {
    let text: String
    let highlight: String
    var highlightColor: Color = .yellow
}
```

**使用方式**:
```swift
WordListRow(word: word, highlightText: searchText)

// 在单词文本中
HighlightedText(text: word.word, highlight: highlightText)
    .font(.headline)

// 在释义文本中
HighlightedText(text: word.meaningPreview, highlight: highlightText, highlightColor: .orange)
    .font(.subheadline)
```

---

### 4. 分享功能 📤

**文件**:
- `Views/StudyView.swift` (修改)
- `Managers/ShareManager.swift` (新增)

**功能**:
- 学习完成后支持分享成绩到社交媒体
- 生成分享卡片（连续打卡天数、学习数据）
- 三种卡片样式：渐变、简约、成就
- 支持复制分享文字

**分享数据**:
```swift
struct ShareData {
    let streakDays: Int        // 连续打卡天数
    let totalWords: Int        // 总学习单词数
    let newWords: Int          // 新学单词数
    let reviewWords: Int       // 复习单词数
    let accuracy: Double       // 正确率
    let studyDate: Date        // 学习日期
}
```

**使用方式**:
```swift
// 生成分享卡片
let image = ShareManager.shared.generateShareCard(data: shareData, style: .gradient)

// 显示分享界面
ShareManager.shared.presentShareSheet(data: shareData, from: viewController)

// 使用SwiftUI分享视图
ShareCardView(data: shareData)
```

---

## P3 问题修复

### 5. 图表时间范围 📊

**文件**: `Views/StatisticsView.swift`

**功能**:
- 统计页面支持切换7天/30天/全年视图
- 全年视图显示365天数据

**修改内容**:
```swift
enum TimeRange: String, CaseIterable {
    case week = "7天"
    case month = "30天"
    case year = "全年"  // 新增
}

func loadData(for timeRange: StatisticsView.TimeRange) {
    let days: Int
    switch timeRange {
    case .week: days = 7
    case .month: days = 30
    case .year: days = 365  // 新增
    }
    trendData = dataManager.getLearningTrendData(days: days)
}
```

---

### 6. 单词收藏功能 ❤️

**文件**:
- `Models/WordEntity.swift`
- `Views/WordCardView.swift`

**功能**:
- 支持收藏单词到"生词本"
- 收藏单词单独复习
- 支持添加收藏备注

**新增字段**:
```swift
@NSManaged public var isFavorite: Bool        // 是否收藏
@NSManaged public var favoriteNote: String?   // 收藏备注
@NSManaged public var favoritedAt: Date?      // 收藏时间
```

**新增方法**:
```swift
// WordEntity 扩展
func toggleFavorite(note: String? = nil)      // 切换收藏状态
func addToFavorites(note: String? = nil)      // 添加收藏
func removeFromFavorites()                    // 取消收藏
func updateFavoriteNote(_ note: String?)      // 更新备注

// 获取收藏单词的请求
static func favoriteWordsRequest(limit: Int = 500) -> NSFetchRequest<WordEntity>
static func favoriteWordsDueForReviewRequest() -> NSFetchRequest<WordEntity>
```

**UI组件**:
- `FavoriteButton` - 收藏按钮（带动画效果）
- `FavoriteNoteSheet` - 收藏备注弹窗

**使用方式**:
```swift
// 收藏单词
word.addToFavorites(note: "很难记住")

// 切换收藏状态
word.toggleFavorite()

// 获取收藏单词
let request = WordEntity.favoriteWordsRequest()
let favorites = try? context.fetch(request)
```

---

### 7. 深色模式过渡动画 🌙

**文件**: `Resources/Theme.swift`

**功能**:
- 添加平滑的深色/浅色模式切换动画
- 使用CATransaction实现0.35秒过渡动画

**新增组件**:
```swift
// 深色模式过渡动画修饰符
struct AppearanceTransitionModifier: ViewModifier

// 平滑颜色过渡修饰符
struct SmoothColorModifier: ViewModifier

// View扩展
extension View {
    func appearanceTransition() -> some View
    func smoothColorTransition() -> some View
}
```

**使用方式**:
```swift
// 在主题管理器中应用过渡
private func applyAppearanceTransition() {
    CATransaction.begin()
    CATransaction.setAnimationDuration(0.35)
    CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
    NotificationCenter.default.post(name: .appearanceTransition, object: nil)
    CATransaction.commit()
}

// 在视图中使用
SomeView()
    .appearanceTransition()
    .smoothColorTransition()
```

---

## 文件变更汇总

### 新增文件
| 文件路径 | 说明 |
|---------|------|
| `Views/AudioPlayerView.swift` | TTS降级提示与设置界面 |
| `Managers/ShareManager.swift` | 分享功能管理器 |

### 修改文件
| 文件路径 | 修改内容 |
|---------|---------|
| `Models/WordEntity.swift` | 添加收藏字段(isFavorite, favoriteNote, favoritedAt) |
| `Views/WordCardView.swift` | 添加收藏按钮和备注弹窗 |
| `Views/WordListView.swift` | 添加搜索高亮功能 |
| `Views/StatisticsView.swift` | 添加全年时间范围选项 |
| `Views/StudyView.swift` | 添加暂停功能、分享按钮、暂停覆盖层 |
| `ViewModels/StudyViewModel.swift` | 添加暂停相关属性和方法 |
| `Resources/Theme.swift` | 添加深色模式过渡动画 |
| `Managers/AudioPlayerManager.swift` | 集成TTS设置 |

---

## 测试建议

### TTS降级提示
1. 删除某个单词的本地音频文件
2. 播放该单词，确认显示TTS降级提示
3. 点击设置按钮，确认能打开TTS设置

### 学习暂停
1. 开始学习后点击暂停按钮
2. 确认显示暂停覆盖层，进度正确
3. 点击继续学习，确认恢复正常
4. 点击保存并退出，确认进度保存

### 搜索高亮
1. 进入词库页面
2. 在搜索框输入中英文关键词
3. 确认匹配的文本被高亮显示

### 分享功能
1. 完成一次学习
2. 点击分享成绩按钮
3. 测试不同样式卡片的生成
4. 测试分享到社交媒体

### 图表时间范围
1. 进入统计页面
2. 切换7天/30天/全年视图
3. 确认图表数据正确更新

### 单词收藏
1. 在学习页面点击心形按钮收藏单词
2. 添加收藏备注
3. 确认在生词本中能查看收藏单词

### 深色模式过渡
1. 在设置中切换深色/浅色模式
2. 确认有过渡动画效果（0.35秒）

---

## 注意事项

1. **数据模型变更**: WordEntity添加了新字段，需要进行数据迁移或重置Core Data存储
2. **TTS设置**: 首次使用会使用默认设置，用户可以在设置中自定义
3. **分享功能**: 需要真机测试才能分享到实际社交媒体
4. **深色模式过渡**: 过渡动画在iOS 15+ 效果最佳

---

*文档版本: 1.0*
*更新日期: 2026-02-24*
