# App Store 截图目录

## 目录结构

```
screenshots/
├── iphone-6.7-inch/      # iPhone 15 Pro Max, iPhone 15 Plus (1290×2796)
├── iphone-6.5-inch/      # iPhone 14 Pro Max, iPhone 14 Plus (1284×2778)
├── iphone-5.5-inch/      # iPhone 8 Plus, iPhone 7 Plus (1242×2208)
├── ipad-12.9-inch/       # iPad Pro 12.9" (2048×2732)
└── figma-design-guide.md # Figma设计规范
```

## 截图内容 (5张/套)

### 1. 学习界面截图
**文件名**: `screenshot-01-learning.png`
**展示内容**:
- 单词卡片正面（单词 + 音标）
- 或单词卡片背面（释义 + 例句）
- 评分按钮区域

**设计文本**:
- 中文: "科学记忆算法" / "SM-2间隔重复，高效抗遗忘"
- 英文: "Scientific Memorization" / "SM-2 Spaced Repetition"

### 2. 磨耳朵播放器截图
**文件名**: `screenshot-02-player.png`
**展示内容**:
- 音频播放界面
- 播放控制按钮
- 播放进度条
- 当前单词信息

**设计文本**:
- 中文: "磨耳朵训练" / "随时随地，听音学词"
- 英文: "Audio Learning" / "Listen & Learn Anywhere"

### 3. 学习统计截图
**文件名**: `screenshot-03-stats.png`
**展示内容**:
- 今日学习数据
- 连续打卡天数
- 学习趋势图表
- 正确率统计

**设计文本**:
- 中文: "学习数据统计" / "掌握进度，可视化进步"
- 英文: "Learning Statistics" / "Track Your Progress"

### 4. 词库浏览截图
**文件名**: `screenshot-04-library.png`
**展示内容**:
- 章节列表
- 搜索栏
- 章节进度指示
- 词汇数量统计

**设计文本**:
- 中文: "3674雅思词汇" / "22章节系统覆盖"
- 英文: "3,674 IELTS Words" / "22 Chapters Covered"

### 5. 学习完成截图
**文件名**: `screenshot-05-complete.png`
**展示内容**:
- 学习完成动画/界面
- 连续打卡徽章
- 今日学习总结
- 明日学习预告

**设计文本**:
- 中文: "连续打卡" / "坚持学习，养成习惯"
- 英文: "Daily Streaks" / "Build Study Habits"

## 截图尺寸要求

### iPhone 6.7 inch Display (必选)
- **尺寸**: 1290 x 2796 像素 (portrait)
- **设备**: iPhone 15 Pro Max, iPhone 15 Plus
- **比例**: 9:19.5

### iPhone 6.5 inch Display (必选)
- **尺寸**: 1284 x 2778 像素 (portrait)
- **设备**: iPhone 14 Pro Max, iPhone 14 Plus, iPhone 13 Pro Max, etc.
- **比例**: 9:19.5

### iPhone 5.5 inch Display (必选)
- **尺寸**: 1242 x 2208 像素 (portrait)
- **设备**: iPhone 8 Plus, iPhone 7 Plus, iPhone 6s Plus
- **比例**: 9:16

### iPad Pro (12.9-inch) (可选但推荐)
- **尺寸**: 2048 x 2732 像素 (portrait) 或 2732 x 2048 像素 (landscape)
- **设备**: iPad Pro 12.9-inch (2nd-6th generation)
- **比例**: 4:3

## 文件命名规范

```
iphone-6.7-inch/
├── screenshot-01-learning.png
├── screenshot-02-player.png
├── screenshot-03-stats.png
├── screenshot-04-library.png
└── screenshot-05-complete.png

iphone-6.5-inch/
├── screenshot-01-learning.png
├── screenshot-02-player.png
├── screenshot-03-stats.png
├── screenshot-04-library.png
└── screenshot-05-complete.png

iphone-5.5-inch/
├── screenshot-01-learning.png
├── screenshot-02-player.png
├── screenshot-03-stats.png
├── screenshot-04-library.png
└── screenshot-05-complete.png

ipad-12.9-inch/
├── screenshot-01-learning-portrait.png
├── screenshot-02-player-portrait.png
├── screenshot-03-stats-portrait.png
├── screenshot-04-library-portrait.png
└── screenshot-05-complete-portrait.png
```

## 设计注意事项

1. **状态栏**: 截图时可隐藏或显示统一的时间 (如 9:41)
2. **网络信号**: 建议显示满格WiFi
3. **电池**: 建议显示100%电量
4. **内容真实**: 使用真实数据而非占位符
5. **语言一致**: 同一套截图使用统一语言
6. **背景设计**: 使用Figma模板添加文字说明

## 截图获取方式

### 方式1: iOS Simulator
```bash
# 启动 Simulator
open -a Simulator

# 使用 xcrun 截图
xcrun simctl io booted screenshot screenshot.png
```

### 方式2: Xcode Screenshot
- Product → Scheme → Edit Scheme → Options → 设置 Application Region
- Product → Run
- Debug → View Debugging → Take Screenshot of [App Name]

### 方式3: 设备截图
- 在真机上运行 App
- 使用 QuickTime Player 录制屏幕
- 截取关键帧

## 提交前检查清单

- [ ] 所有尺寸截图完整 (至少5张/尺寸)
- [ ] 截图内容与描述一致
- [ ] 无敏感信息泄露
- [ ] 图片格式为 PNG
- [ ] 文件大小不超过 500KB/张
- [ ] 已添加文字说明 (如使用)
- [ ] 各语言版本截图已准备
