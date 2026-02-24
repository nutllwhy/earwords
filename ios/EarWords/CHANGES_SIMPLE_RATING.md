# EarWords SM-2 评分简化 - 修改总结

## 概述
将原有的 0-5 分 6 档评分系统简化为直观的 3 档评分系统：
- **忘记 (Forgot)** 😵 - 红色 - 完全想不起来
- **模糊 (Vague)** 😕 - 黄色 - 有点印象但不确定
- **记住 (Remembered)** 😊 - 绿色 - 确定记得

## 文件变更

### 1. 新建文件

#### `Models/SimpleRating.swift`
- 定义新的 `SimpleRating` 枚举（3档评分）
- 包含 emoji、颜色、文字描述等UI属性
- 定义 SM-2 算法映射逻辑
- 提供与旧版 `ReviewQuality` 的兼容转换
- 实现触觉反馈支持

### 2. 修改文件

#### `Views/RatingButtons.swift` (新建)
- 完全重写的评分按钮组件
- 3个大按钮垂直排列，每个占满宽度
- 高度 60pt+，易于点击防止误触
- 显示 emoji + 标题 + 描述
- 首次使用显示引导提示（2秒后自动消失）
- 包含横向布局版本（备用）

#### `Algorithms/SM2Algorithm.swift`
新增内容：
- `calculateNextReview(from:currentEaseFactor:currentInterval:reviewCount:)` - 简化评分版本的核心算法
- `calculateNextReviewDate(from:currentRecord:)` - 简化评分版本的日期计算
- `applyReview(simpleRating:timeSpent:)` - WordEntity 扩展的简化评分方法
- `SimpleReviewResult` 结构体 - 简化评分的结果类型

算法逻辑：
- **忘记**: interval = 0（当天重复），降低简易度 -0.2
- **模糊**: interval = 1（1天后），降低简易度 -0.1
- **记住**: 递增间隔 1→3→7→14→30→60→90→180→365天，提升简易度 +0.05

#### `ViewModels/StudyViewModel.swift`
修改内容：
- `rateCurrentWord(rating:)` - 使用 SimpleRating 的新方法
- `rateCurrentWord(quality:)` - 旧方法保留，内部转换为 SimpleRating
- 更新日志输出，显示新的评分档位

#### `Managers/DataManager.swift`
新增内容：
- `logReview(word:simpleRating:timeSpent:mode:)` - 支持简化评分的日志记录
- 将 SimpleRating 映射回旧的 quality 值用于数据兼容

#### `Managers/StudyManager.swift`
新增内容：
- `submitReview(word:simpleRating:timeSpent:mode:)` - 支持简化评分的提交
- 统计更新逻辑适配

#### `Views/StudyView.swift`
修改内容：
- 评分按钮从 `ImprovedRatingButtons` 改为新的 `RatingButtons`
- 手势操作：左滑→模糊，右滑→记住
- 手势提示文字更新

#### `Models/StudyRecord.swift`
新增内容：
- `applyReview(rating:timeSpent:)` - 支持简化评分的方法

## 用户界面改进

### 评分按钮
- 3个大按钮，垂直排列
- 每个按钮高度 60pt+，宽度占满
- 颜色：红/黄/绿，一目了然
- Emoji + 标题 + 描述，清晰易懂
- 选中后有放大动画和震动反馈

### 引导提示
- 首次评分显示提示："忘记：完全想不起来 / 模糊：有点印象 / 记住：确定记得"
- 2秒后自动消失
- 使用 AppStorage 记录用户是否已看过引导

### 触觉反馈
- 忘记：错误震动（UINotificationFeedbackGenerator .error）
- 模糊：轻微震动（UIImpactFeedbackGenerator intensity 0.5）
- 记住：成功震动（UINotificationFeedbackGenerator .success）

## 数据兼容性

### 向后兼容
- 旧版 `ReviewQuality` 保留，可用于转换
- 数据库中的 `quality` 字段仍存储 0-5 的整数
- 新的 SimpleRating 映射到旧的 quality 值：
  - forgot → 0 (blackOut)
  - vague → 3 (hesitation)
  - remembered → 4 (good)

### 统计兼容
- 正确/错误统计逻辑不变
- 间隔计算使用新的递增算法
- 单词状态（new/learning/mastered）更新逻辑适配

## 测试建议

1. **功能测试**
   - 3个评分按钮都能正常点击
   - 手势操作（左滑/右滑）正常工作
   - 引导提示首次显示，之后不再显示

2. **算法测试**
   - 忘记 → 当天重复
   - 模糊 → 1天后复习
   - 记住 → 间隔递增（1→3→7→14...）

3. **数据测试**
   - 评分记录正确保存到数据库
   - 旧数据可以正常显示
   - 统计数据正确更新

4. **UI测试**
   - 按钮动画流畅
   - 触觉反馈正常
   - 深色模式适配
   - 不同屏幕尺寸适配
