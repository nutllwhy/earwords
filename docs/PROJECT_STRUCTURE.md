# EarWords 项目结构说明

> 本文档详细说明 EarWords 项目的目录结构和组织方式。

---

## 📁 目录结构

```
EarWords/
├── 📂 ios/                       # iOS 项目主目录
│   └── 📂 EarWords/              # 应用主项目
│       ├── 📂 Algorithms/        # 算法实现
│       │   ├── SM2Algorithm.swift           # SM-2 间隔重复算法
│       │   └── SM2UsageExample.swift        # 算法使用示例
│       │
│       ├── 📂 Managers/          # 业务逻辑管理器
│       │   ├── DataManager.swift            # Core Data 数据管理
│       │   ├── StudyManager.swift           # 学习会话管理
│       │   ├── AudioPlayerManager.swift     # 音频播放管理
│       │   ├── NotificationManager.swift    # 本地通知管理
│       │   └── VocabularyImporter.swift     # 词库导入
│       │
│       ├── 📂 Models/            # 数据模型
│       │   ├── WordEntity.swift             # 单词实体
│       │   ├── ReviewLogEntity.swift        # 复习记录实体
│       │   ├── StudyRecord.swift            # 学习记录模型
│       │   └── UserSettingsEntity.swift     # 用户设置
│       │
│       ├── 📂 Views/             # SwiftUI 视图
│       │   ├── MainTabView.swift            # 主 Tab 框架
│       │   ├── StudyView.swift              # 学习界面
│       │   ├── AudioReviewView.swift        # 磨耳朵界面
│       │   ├── StatisticsView.swift         # 统计界面
│       │   ├── ChapterListView.swift        # 章节列表
│       │   ├── WordCardView.swift           # 单词卡片
│       │   ├── WordDetailView.swift         # 单词详情
│       │   ├── ImportPreviewView.swift      # 导入预览
│       │   ├── OnboardingView.swift         # 引导页
│       │   └── LaunchScreenView.swift       # 启动屏
│       │
│       ├── 📂 ViewModels/        # 视图模型
│       │   ├── StudyViewModel.swift         # 学习视图模型
│       │   └── UserSettingsViewModel.swift  # 设置视图模型
│       │
│       ├── 📂 Utils/             # 工具类
│       │   └── CoreDataExtensions.swift     # Core Data 扩展
│       │
│       ├── 📂 Resources/         # 资源文件
│       │   ├── Assets.xcassets/             # 图片资源
│       │   └── Theme.swift                  # 主题配置
│       │
│       ├── 📂 Widgets/           # 小组件
│       │   └── WidgetDataProvider.swift     # 小组件数据
│       │
│       ├── 📂 Docs/              # 项目内部文档
│       │   ├── COMPLETION_CHECKLIST.md
│       │   ├── APP_STORE_PREPARATION.md
│       │   ├── TEST_REPORT.md
│       │   ├── PERFORMANCE_OPTIMIZATION.md
│       │   └── APP_ICON_DESIGN.md
│       │
│       ├── EarWordsApp.swift                 # 应用入口
│       └── InfoPlistConfiguration.swift      # Plist 配置
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
│   ├── ielts-vocabulary.json                 # 原始词库
│   ├── ielts-vocabulary-with-phonetics.json  # 带音标词库
│   ├── ielts-words-simple.json               # 简化词库
│   ├── audio-index.json                      # 音频索引
│   ├── audio-progress.json                   # 音频生成进度
│   ├── phonetics-progress.json               # 音标获取进度
│   └── fetch-phonetics.mjs                   # 音标获取脚本
│
├── 📂 docs/                      # 文档
│   ├── index.html                # GitHub Pages 首页
│   ├── style.css                 # 样式文件
│   ├── PRD.md                    # 产品需求文档
│   ├── ARCHITECTURE.md           # 架构设计文档
│   ├── API.md                    # API 文档
│   ├── DEVELOPER_GUIDE.md        # 开发者指南
│   ├── CODE_REVIEW.md            # 代码审查报告
│   ├── 交互原型方案.md            # 交互设计文档
│   ├── 交互体验模拟.md            # 体验模拟文档
│   └── Figma实现方案.md           # 设计实现文档
│
├── 📂 .github/                   # GitHub 配置
│   ├── 📂 workflows/             # CI/CD 工作流
│   │   └── pages.yml             # GitHub Pages 部署
│   ├── 📂 ISSUE_TEMPLATE/        # Issue 模板
│   │   ├── bug_report.md
│   │   ├── feature_request.md
│   │   └── question.md
│   └── PULL_REQUEST_TEMPLATE.md  # PR 模板
│
├── README.md                     # 项目说明
├── CHANGELOG.md                  # 版本日志
├── LICENSE                       # 许可证
└── .swiftlint.yml                # SwiftLint 配置
```

---

## 📂 模块依赖关系

```
Views (SwiftUI)
    ↑
ViewModels (ObservableObject)
    ↑
Managers (Business Logic)
    ↑ ← ← ← ← ← Algorithms
    ↑
Models (Core Data Entities)
    ↑
Core Data + CloudKit
```

---

## 🎯 各目录职责

### Algorithms/ 算法

**职责**: 实现核心算法，不依赖 UI

**包含文件**:
- `SM2Algorithm.swift` - SM-2 间隔重复算法
- 纯计算逻辑，可独立测试
- 不与 UI 框架耦合

### Managers/ 管理器

**职责**: 管理业务逻辑和数据流

**设计原则**:
- 使用单例模式
- 管理应用状态
- 协调数据操作

**包含文件**:
- `DataManager` - Core Data 操作
- `StudyManager` - 学习流程管理
- `AudioPlayerManager` - 音频控制
- `NotificationManager` - 通知管理

### Models/ 模型

**职责**: 数据模型定义

**包含文件**:
- Core Data 实体定义
- 数据传输对象
- 业务逻辑扩展

### Views/ 视图

**职责**: SwiftUI 界面实现

**设计原则**:
- 只负责 UI 展示
- 状态由 ViewModel 管理
- 可组合、可复用

### ViewModels/ 视图模型

**职责**: 视图状态管理

**设计原则**:
- 遵守 `ObservableObject` 协议
- 使用 `@Published` 发布状态
- 处理用户交互逻辑

### Utils/ 工具

**职责**: 通用扩展和工具方法

**包含文件**:
- Core Data 扩展
- 日期处理扩展
- 字符串扩展
- 其他工具方法

---

## 🔌 模块依赖规则

### 允许依赖

```
Views → ViewModels
Views → Managers
Views → Models
ViewModels → Managers
ViewModels → Models
Managers → Models
Managers → Algorithms
Algorithms → (无依赖)
```

### 禁止依赖

```
Managers → Views        # 管理器不依赖视图
Algorithms → Views      # 算法不依赖视图
Models → Managers       # 模型不依赖管理器
```

---

## 📱 扩展开发指南

### 添加新功能模块

1. **创建算法** (如果需要)
   - 在 `Algorithms/` 创建新文件
   - 确保算法可独立测试

2. **创建管理器** (如果需要)
   - 在 `Managers/` 创建新文件
   - 继承 `ObservableObject`
   - 实现单例模式

3. **创建视图模型** (如果需要)
   - 在 `ViewModels/` 创建新文件
   - 管理视图状态

4. **创建视图**
   - 在 `Views/` 创建新文件
   - 遵循 SwiftUI 规范

5. **添加测试**
   - 在 `EarWordsTests/` 创建测试文件
   - 覆盖核心逻辑

---

## 📝 文件命名规范

| 类型 | 命名规则 | 示例 |
|------|----------|------|
| 视图 | `XXXView.swift` | `StudyView.swift` |
| 视图模型 | `XXXViewModel.swift` | `StudyViewModel.swift` |
| 管理器 | `XXXManager.swift` | `DataManager.swift` |
| 实体 | `XXXEntity.swift` | `WordEntity.swift` |
| 算法 | `XXXAlgorithm.swift` | `SM2Algorithm.swift` |
| 扩展 | `XXX+Extension.swift` | `Date+Extension.swift` |
| 测试 | `XXXTests.swift` | `DataManagerTests.swift` |

---

## 🔍 重要文件说明

### 应用入口

**`EarWordsApp.swift`**
- 应用启动点
- 配置全局依赖
- 初始化管理器

### 核心配置

**`InfoPlistConfiguration.swift`**
- Info.plist 配置
- 权限声明
- 应用元数据

### 主题配置

**`Theme.swift`**
- 颜色定义
- 视图修饰符
- 主题扩展
