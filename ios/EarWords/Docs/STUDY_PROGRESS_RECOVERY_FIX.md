# EarWords P0级问题修复 - 学习进度自动保存/恢复机制

## 问题描述
当App被杀后台或用户接打电话后返回，学习进度可能丢失，用户需要重新开始。

## 修复方案

### 1. 新增文件：StudyProgressManager.swift
**位置**: `Managers/StudyProgressManager.swift`

**功能**:
- 使用 UserDefaults 自动保存当前学习状态
- 保存内容：
  - 当前单词索引 (`currentIndex`)
  - 学习队列单词ID列表 (`wordIds`)
  - 已评分单词记录 (`ratedWordIds`, `ratings`)
  - 正确/错误计数
  - 会话开始时间 (`sessionStartTime`)
  - 最后保存时间 (`lastSaveTime`)
  - 学习模式 (`studyMode`)

**自动保存触发时机**:
- App进入后台 (`didEnterBackgroundNotification`)
- App即将终止 (`willTerminateNotification`)
- 内存警告 (`didReceiveMemoryWarningNotification`)
- 每次评分后自动保存
- 跳过单词时自动保存

**进度过期机制**:
- 超过30分钟未活动的会话视为过期
- 过期的进度会自动清除，避免恢复过时的会话

### 2. 更新文件：StudyViewModel.swift
**位置**: `ViewModels/StudyViewModel.swift`

**新增功能**:
- `checkForRecovery()` - 检查是否存在可恢复的进度
- `restoreProgress()` - 恢复上次学习进度
- `startNewSession()` - 开始新的学习会话（放弃旧进度）
- `saveProgress()` - 手动保存当前进度
- `autoSaveProgress()` - 自动保存进度（后台通知触发）

**新增属性**:
- `showRecoveryDialog` - 控制恢复对话框显示
- `recoveryMessage` - 恢复对话框的消息内容
- `showRecoveryToast` - 控制恢复成功提示显示
- `isRestoredSession` - 标识当前是否是恢复的会话

**修改的原有方法**:
- `loadStudyQueue()` - 初始化时不再自动加载，改为由 View 控制
- `rateCurrentWord()` - 评分后自动保存进度
- `skipCurrentWord()` - 跳过后自动保存进度
- `completeStudySession()` - 完成后清除保存的进度

### 3. 更新文件：StudyView.swift
**位置**: `Views/StudyView.swift`

**新增UI组件**:
- `RecoveryToast` - 恢复成功提示（顶部绿色浮动提示）
- 恢复进度对话框（Alert）- 询问用户"继续上次学习"或"重新开始"

**修改的原有逻辑**:
- `onAppear` - 先检查是否需要恢复进度，没有才加载新队列
- 添加 `.alert` 和 `.overlay` 修饰符显示恢复UI

## 用户交互流程

### 场景1：App被杀后台后重启
1. 用户打开App进入学习界面
2. `checkForRecovery()` 检测到有效进度
3. 显示恢复对话框："检测到未完成的会话（5分钟前）\n当前进度：第 5/20 个单词，剩余 15 个"
4. 用户选择"继续上次学习"
5. 恢复进度，显示绿色提示"已恢复上次学习进度"
6. 用户从第5个单词继续学习

### 场景2：用户选择重新开始
1. 用户打开App进入学习界面
2. 检测到有效进度，显示恢复对话框
3. 用户选择"重新开始"
4. 清除旧进度，加载新的学习队列
5. 从第1个单词开始学习

### 场景3：正常学习过程
1. 用户正在学习第10个单词
2. 接到来电，App进入后台
3. 自动保存当前进度（第10个单词）
4. 通话结束，用户返回App
5. 进度保持，用户继续学习

### 场景4：进度过期
1. 用户昨天学习了10个单词后关闭App
2. 今天打开App（超过30分钟）
3. `checkForRecovery()` 检测到进度已过期
4. 自动清除过期进度
5. 直接加载新的学习队列

## 测试场景

### ✅ App被杀后台后重启
- **测试步骤**: 
  1. 开始学习，记住当前单词
  2. 杀掉App进程
  3. 重新打开App
- **期望结果**: 显示恢复对话框，可选择继续或重新开始

### ✅ 接电话后返回
- **测试步骤**:
  1. 开始学习
  2. 接听电话（App进入后台）
  3. 挂断电话返回App
- **期望结果**: 进度自动恢复，回到离开时的单词

### ✅ 锁屏后解锁
- **测试步骤**:
  1. 开始学习
  2. 锁屏
  3. 解锁后返回App
- **期望结果**: 进度保持，继续学习

### ✅ 切换应用后返回
- **测试步骤**:
  1. 开始学习
  2. 切换到其他应用
  3. 切回EarWords
- **期望结果**: 进度自动恢复

### ✅ 30分钟过期机制
- **测试步骤**:
  1. 开始学习后关闭App
  2. 等待30分钟以上
  3. 重新打开App
- **期望结果**: 不显示恢复对话框，直接加载新队列

### ✅ 完成学习后清除进度
- **测试步骤**:
  1. 完成所有单词学习
  2. 杀掉App进程
  3. 重新打开App
- **期望结果**: 不显示恢复对话框，显示空状态或完成状态

## 技术细节

### 数据存储
- 使用 `UserDefaults` 存储进度数据
- 数据使用 `JSONEncoder` 编码为 JSON 格式
- Key: `com.earwords.study.progress`

### 进度数据结构
```swift
struct StudyProgress: Codable {
    let currentIndex: Int           // 当前单词索引
    let wordIds: [Int32]            // 单词ID列表
    let ratedWordIds: [Int32]       // 已评分单词ID
    let ratings: [Int]              // 对应评分
    let correctCount: Int           // 正确计数
    let incorrectCount: Int         // 错误计数
    let sessionStartTime: Date      // 会话开始时间
    let lastSaveTime: Date          // 最后保存时间
    let studyMode: String           // 学习模式
}
```

### 过期时间计算
```swift
let expirationMinutes: TimeInterval = 30
let timeSinceLastSave = Date().timeIntervalSince(progress.lastSaveTime)
if timeSinceLastSave > expirationMinutes * 60 {
    // 过期处理
}
```

## 注意事项

1. **进度与Core Data数据同步**: 恢复时从Core Data重新加载单词实体，确保数据一致性
2. **评分记录恢复**: 当前版本只恢复进度位置，不恢复评分历史（已评分单词的SM-2状态已保存在Core Data中）
3. **多设备同步**: 进度保存在本地 UserDefaults，不支持跨设备同步
4. **内存警告**: 收到内存警告时会自动保存进度，尽可能防止数据丢失

## 后续优化建议

1. **iCloud同步**: 可考虑将进度保存到iCloud，支持多设备同步
2. **更精确的评分恢复**: 可以记录每个单词的评分历史，恢复时重建完整状态
3. **学习计时恢复**: 恢复时可以继续累加学习时间，而不是重置
4. **断点续传**: 对于长单词列表，可以支持更细粒度的恢复点
