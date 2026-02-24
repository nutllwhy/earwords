# EarWords 听词

<p align="center">
  <img src="docs/images/app-icon.png" width="120" height="120" alt="EarWords App Icon">
</p>

<p align="center">
  <strong>雅思词汇真经 · 间隔重复 · 磨耳朵</strong>
</p>

<p align="center">
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9-orange.svg" alt="Swift 5.9"></a>
  <a href="https://developer.apple.com/ios/"><img src="https://img.shields.io/badge/Platform-iOS%2016%2B-lightgrey.svg" alt="iOS 16+"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License"></a>
  <a href="https://nutllwhy.github.io/earwords/"><img src="https://img.shields.io/badge/GitHub%20Pages-Live-green.svg" alt="GitHub Pages"></a>
</p>

---

## 📖 项目简介

**EarWords (听词)** 是一款专为雅思备考设计的英语词汇学习 App，基于刘洪波《雅思词汇真经》，采用科学的 **SM-2 间隔重复算法**，帮助用户高效记忆 **3674** 个雅思高频词汇。

### 核心设计理念

- **科学记忆**：基于 SM-2 间隔重复算法，在遗忘临界点复习，最大化记忆效率
- **磨耳朵模式**：通勤、运动时可进行被动学习，充分利用碎片时间
- **循序渐进**：22个主题章节，从自然地理到身心健康，系统构建词汇网络
- **数据驱动**：详细的学习统计和进度追踪，让进步可视化

---

## ✨ 功能特性

### 📚 智能学习系统

| 功能 | 描述 |
|------|------|
| **SM-2 算法** | 科学安排复习计划，根据记忆程度动态调整间隔 |
| **5级评分** | 完全忘记→错误→困难→犹豫后正确→正确→完美 |
| **智能队列** | 自动混合新词与复习词，优先处理紧急复习 |
| **手势操作** | 左滑模糊、右滑认识、长按查看详情 |
| **学习统计** | 实时显示正确率、连续打卡、学习趋势 |

### 🎧 磨耳朵模式

| 功能 | 描述 |
|------|------|
| **音频合成** | 单词+例句自动合成为连续音频 |
| **多种模式** | 顺序播放/随机播放/间隔重复智能排序 |
| **后台播放** | 支持锁屏控制、后台连续播放 |
| **语速调节** | 0.5x-1.0x 语速自由调节 |
| **智能重复** | 不熟悉的单词自动增加播放频率 |

### 📊 数据统计

- **今日概览**：新词/复习/正确率一目了然
- **连续打卡**：激励持续学习，养成好习惯
- **趋势图表**：7日/30日学习趋势可视化
- **章节进度**：22个章节掌握情况追踪
- **词汇掌握**：新词/学习中/已掌握分布

### ☁️ 数据同步

- **iCloud 同步**：跨设备同步学习进度
- **本地备份**：支持数据导出与恢复
- **增量更新**：智能处理数据冲突

---

## 📸 截图展示

<p align="center">
  <img src="docs/images/screenshot-study.png" width="200" alt="学习界面">
  <img src="docs/images/screenshot-audio.png" width="200" alt="磨耳朵界面">
  <img src="docs/images/screenshot-stats.png" width="200" alt="统计界面">
  <img src="docs/images/screenshot-chapters.png" width="200" alt="章节界面">
</p>

---

## 🛠️ 技术栈

### 核心技术

| 技术 | 用途 |
|------|------|
| **Swift 5.9** | 开发语言 |
| **SwiftUI** | 用户界面框架 |
| **Core Data** | 本地数据持久化 |
| **CloudKit** | iCloud 数据同步 |
| **Combine** | 响应式编程 |

### 音频处理

| 技术 | 用途 |
|------|------|
| **AVFoundation** | 音频播放与控制 |
| **AVSpeechSynthesizer** | TTS 语音合成 |
| **MediaPlayer** | 锁屏远程控制 |

### 算法与数据结构

| 技术 | 用途 |
|------|------|
| **SM-2 算法** | 间隔重复调度 |
| **NSPredicate** | 数据查询过滤 |
| **批量导入** | 大规模数据初始化 |

---

## 📁 项目结构

```
EarWords/
├── 📂 ios/EarWords/              # iOS 项目主目录
│   ├── 📂 Algorithms/            # 算法实现
│   │   ├── SM2Algorithm.swift    # SM-2 间隔重复算法
│   │   └── SM2UsageExample.swift # 算法使用示例
│   ├── 📂 Managers/              # 管理器
│   │   ├── DataManager.swift     # Core Data 数据管理
│   │   ├── StudyManager.swift    # 学习会话管理
│   │   ├── AudioPlayerManager.swift  # 音频播放管理
│   │   ├── NotificationManager.swift # 本地通知
│   │   └── VocabularyImporter.swift  # 词库导入
│   ├── 📂 Models/                # 数据模型
│   │   ├── WordEntity.swift      # 单词实体
│   │   ├── ReviewLogEntity.swift # 复习记录实体
│   │   ├── StudyRecord.swift     # 学习记录模型
│   │   └── UserSettingsEntity.swift  # 用户设置
│   ├── 📂 Views/                 # SwiftUI 视图
│   │   ├── MainTabView.swift     # 主 Tab 框架
│   │   ├── StudyView.swift       # 学习界面
│   │   ├── AudioReviewView.swift # 磨耳朵界面
│   │   ├── StatisticsView.swift  # 统计界面
│   │   ├── ChapterListView.swift # 章节列表
│   │   ├── WordCardView.swift    # 单词卡片
│   │   ├── WordDetailView.swift  # 单词详情
│   │   ├── ImportPreviewView.swift   # 导入预览
│   │   ├── OnboardingView.swift  # 引导页
│   │   └── LaunchScreenView.swift# 启动屏
│   ├── 📂 ViewModels/            # 视图模型
│   │   ├── StudyViewModel.swift  # 学习视图模型
│   │   └── UserSettingsViewModel.swift   # 设置视图模型
│   ├── 📂 Resources/             # 资源文件
│   │   ├── Assets.xcassets       # 图片资源
│   │   ├── Theme.swift           # 主题配置
│   │   └── ielts-vocabulary-with-phonetics.json  # 词库数据
│   ├── 📂 Widgets/               # 小组件
│   │   └── WidgetDataProvider.swift  # 小组件数据
│   ├── EarWordsApp.swift         # 应用入口
│   └── InfoPlistConfiguration.swift  #  plist 配置
│
├── 📂 ios/EarWordsTests/         # 单元测试
│   ├── SM2AlgorithmTests.swift   # SM-2 算法测试
│   ├── DataManagerTests.swift    # 数据管理测试
│   ├── StudyManagerTests.swift   # 学习管理测试
│   ├── AudioPlayerManagerTests.swift # 音频测试
│   ├── WordListTests.swift       # 词库测试
│   ├── StatisticsTests.swift     # 统计测试
│   ├── IntegrationTests.swift    # 集成测试
│   ├── StudyFlowTests.swift      # 学习流程测试
│   └── PerformanceTests.swift    # 性能测试
│
├── 📂 ios/EarWordsWidgets/       # iOS 小组件
│   ├── EarWordsWidgetBundle.swift
│   ├── TodayProgressWidget.swift
│   └── LockScreenProgressWidget.swift
│
├── 📂 ios/EarWordsUITests/       # UI 测试
│   └── EarWordsUITests.swift
│
├── 📂 data/                      # 数据处理
│   ├── ielts-vocabulary.json     # 原始词库
│   ├── ielts-vocabulary-with-phonetics.json  # 带音标词库
│   ├── ielts-words-simple.json   # 简化词库
│   ├── audio-index.json          # 音频索引
│   ├── audio-progress.json       # 音频生成进度
│   ├── phonetics-progress.json   # 音标获取进度
│   └── fetch-phonetics.mjs       # 音标获取脚本
│
├── 📂 docs/                      # 文档
│   ├── index.html                # GitHub Pages 首页
│   ├── style.css                 # 样式文件
│   ├── PRD.md                    # 产品需求文档
│   ├── 交互原型方案.md            # 交互设计
│   ├── 交互体验模拟.md            # 体验模拟
│   └── Figma实现方案.md           # 设计实现
│
├── 📂 .github/                   # GitHub 配置
│   ├── workflows/                # CI/CD 工作流
│   │   └── pages.yml             # GitHub Pages 部署
│   ├── ISSUE_TEMPLATE/           # Issue 模板
│   └── PULL_REQUEST_TEMPLATE.md  # PR 模板
│
├── README.md                     # 项目说明
├── CHANGELOG.md                  # 版本日志
├── LICENSE                       # 许可证
└── .gitignore                    # Git 忽略配置
```

---

## 🚀 安装与使用

### 系统要求

- **iOS**: 16.0+
- **Xcode**: 15.0+
- **Swift**: 5.9+
- **设备**: iPhone / iPad (支持 iPad 多任务)

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/nutllwhy/earwords.git
   cd earwords/ios/EarWords
   ```

2. **打开项目**
   ```bash
   open EarWords.xcodeproj
   # 或使用
   open EarWords.xcworkspace
   ```

3. **配置签名**
   - 在 Xcode 中选择项目
   - 进入 Signing & Capabilities
   - 选择你的开发团队
   - 修改 Bundle Identifier

4. **配置 iCloud**
   - 开启 iCloud 能力
   - 设置 CloudKit 容器标识符
   - 启用 CloudKit 仪表板

5. **构建运行**
   - 选择目标设备
   - 点击 Run (⌘+R)

### 首次使用

1. **词库导入**
   - 首次启动自动导入 3674 个雅思词汇
   - 支持增量更新，不会重复导入

2. **设置学习目标**
   - 设置每日新词数量（默认 20）
   - 设置复习上限（默认 50）
   - 配置学习提醒时间

3. **开始学习**
   - 进入「学习」Tab 开始每日学习
   - 使用手势或评分按钮进行复习
   - 完成学习后查看统计

---

## 📊 词库数据

### 数据来源

- **词库**: [my-ielts](https://github.com/hefengxian/my-ielts) - 刘洪波《雅思词汇真经》
- **音标**: [dictionaryapi.dev](https://dictionaryapi.dev)
- **例句**: 内置精选例句

### 数据统计

| 指标 | 数值 |
|------|------|
| 单词总数 | 3,674 |
| 章节数 | 22 |
| 例句数 | ~3,500 |
| 词库大小 | 1.6 MB |

### 章节分布

| 编号 | 章节名 | 词数 |
|------|--------|------|
| 01 | 自然地理 | 241 |
| 02 | 植物研究 | 130 |
| 03 | 动物保护 | 168 |
| 04 | 太空探索 | 75 |
| 05 | 学校教育 | 401 |
| ... | ... | ... |
| 22 | 时间日期 | - |

---

## 🤝 贡献指南

我们欢迎所有形式的贡献！

### 提交 Issue

- 使用 [Issue 模板](.github/ISSUE_TEMPLATE) 提交
- 清晰描述问题和复现步骤
- 标注相关标签（bug/feature/question）

### 提交 PR

1. **Fork 仓库** 并创建你的分支
   ```bash
   git checkout -b feature/amazing-feature
   ```

2. **提交更改**
   ```bash
   git commit -m 'Add some amazing feature'
   ```

3. **推送到分支**
   ```bash
   git push origin feature/amazing-feature
   ```

4. **创建 Pull Request**
   - 使用 PR 模板
   - 关联相关 Issue
   - 确保 CI 通过

### 代码规范

- 遵循 [Swift Style Guide](https://google.github.io/swift/)
- 使用 SwiftLint 检查代码
- 添加适当的文档注释
- 编写单元测试

---

## 📚 文档

- [产品需求文档 (PRD)](docs/PRD.md)
- [架构设计文档](docs/ARCHITECTURE.md)
- [API 文档](docs/API.md)
- [开发者指南](docs/DEVELOPER_GUIDE.md)
- [更新日志](CHANGELOG.md)

---

## 📝 许可证

本项目采用 [MIT License](LICENSE) 开源。

---

## 👤 关于作者

**栗噔噔** - iOS 开发者

- 即刻: [@栗噔噔](https://m.okjike.com/users/xxx)
- Moltbook: [@Lidengdeng](https://moltbook.com/xxx)

---

<p align="center">
  <a href="https://nutllwhy.github.io/earwords/">📖 在线预览</a> ·
  <a href="../../issues">🐛 提交问题</a> ·
  <a href="../../discussions">💡 功能建议</a>
</p>
