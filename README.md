# EarWords 听词

[![GitHub Pages](https://img.shields.io/badge/GitHub%20Pages-Live-blue)](https://nutllwhy.github.io/earwords/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2016%2B-lightgrey.svg)](https://developer.apple.com/ios/)

> 雅思词汇真经 · 间隔重复 · 磨耳朵

EarWords (听词) 是一款专为雅思备考设计的英语词汇学习 App，基于刘洪波《雅思词汇真经》，采用 SM-2 间隔重复算法，帮助用户高效记忆 3674 个雅思高频词汇。

📱 **[在线预览](https://nutllwhy.github.io/earwords/)**

## ✨ 核心功能

### 📚 每日词汇
- 基于 **SM-2 间隔重复算法**，科学安排复习计划
- 支持自定义每日新词和复习数量
- 5级评分系统（完全忘记 → 完美回忆）
- iCloud 自动同步学习进度

### 🎧 磨耳朵
- 将单词 + 例句合成为音频
- 支持顺序/随机/间隔重复三种播放模式
- 通勤、运动时可进行被动学习
- 可调节语速

### 📊 学习统计
- 今日学习概览（新词/复习/正确率）
- 连续学习天数打卡
- 学习趋势图表
- 章节进度追踪

## 📁 项目结构

```
EarWords/
├── 📂 Data/                    # 数据处理
│   ├── vocabulary_raw.js       # 原始词库
│   ├── ielts-vocabulary.json   # 转换后词库 (1.6MB)
│   ├── fetch-phonetics.mjs     # 音标获取脚本
│   ├── generate-audio.mjs      # 音频生成脚本
│   └── audio-examples/         # 例句音频
│
├── 📂 iOS/EarWords/           # iOS 项目
│   ├── Models/                 # Core Data 实体
│   ├── Algorithms/             # SM-2 算法
│   ├── Managers/               # 数据管理
│   └── Views/                  # SwiftUI 视图
│
└── 📂 docs/                    # GitHub Pages 文档
    ├── index.html
    └── style.css
```

## 📊 数据资产

| 指标 | 数值 |
|------|------|
| 单词总数 | 3,674 |
| 章节数 | 22 |
| 例句数 | ~3,500 |
| 词库文件 | 1.6MB |

### 章节分布
1. 01_自然地理 (241词)
2. 02_植物研究 (130词)
3. 03_动物保护 (168词)
4. 04_太空探索 (75词)
5. 05_学校教育 (401词)
6. ... (更多)

## 🛠️ 技术栈

- **语言**: Swift 5.9
- **框架**: SwiftUI
- **数据**: Core Data + CloudKit
- **算法**: SM-2 间隔重复
- **音频**: macOS Say + AVSpeechSynthesizer

## 🚀 开发进度

### ✅ 已完成
- [x] 词库数据转换 (3,674词)
- [x] Core Data 模型设计
- [x] SM-2 算法实现
- [x] UI 组件设计
- [x] GitHub Pages 文档站点

### 🚧 进行中
- [ ] 音标数据获取 (8%)
- [ ] 例句音频生成 (23%)

### ⏳ 待开始
- [ ] Xcode 项目初始化
- [ ] 视图实现
- [ ] 测试 & 发布

## 📝 数据来源

- **词库**: [my-ielts](https://github.com/hefengxian/my-ielts) - 刘洪波《雅思词汇真经》
- **音标**: [dictionaryapi.dev](https://dictionaryapi.dev)
- **许可**: MIT License

## 👤 关于

**作者**: 栗噔噔  
**平台**: 即刻 @栗噔噔 | Moltbook @Lidengdeng

---

<div align="center">

**[📖 在线文档](https://nutllwhy.github.io/earwords/)** · **[🐛 提交问题](../../issues)** · **[💡 功能建议](../../discussions)**

</div>
