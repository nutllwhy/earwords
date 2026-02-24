# EarWords 音频播放器 - Background Mode 配置

## 1. Info.plist 配置

在 `Info.plist` 中添加以下配置以支持后台播放：

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

## 2. Capabilities 配置

在 Xcode 中打开项目，启用以下 Capability：

1. 选择 Target → Signing & Capabilities
2. 点击 "+ Capability"
3. 添加 "Background Modes"
4. 勾选 "Audio, AirPlay, and Picture in Picture"

## 3. App 权限描述

在 `Info.plist` 中添加音频使用描述：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>EarWords 需要访问麦克风以支持语音输入功能</string>
```

## 4. 项目结构

```
EarWords/
├── Managers/
│   ├── AudioPlayerManager.swift    # 音频播放器管理器
│   └── DataManager.swift           # 数据管理器
├── Views/
│   ├── AudioReviewView.swift       # 磨耳朵界面
│   └── ...
├── Models/
│   └── WordEntity.swift            # 单词模型
└── EarWords.entitlements           # 需要添加音频后台模式
```

## 5. 使用说明

### 播放模式

1. **顺序播放**：按单词 ID 顺序播放
2. **随机播放**：随机打乱播放顺序
3. **间隔重复**：根据 SM-2 算法优先级智能排序，不熟悉单词优先

### 音频加载优先级

1. 本地例句音频 (`Documents` 目录)
2. Bundle 内音频文件 (`.aiff`)
3. `Data/audio-examples/` 目录
4. 在线音频 URL
5. TTS 语音合成（降级方案）

### 锁屏控制

- 显示当前单词、音标、释义
- 支持播放/暂停/上一首/下一首
- 支持拖动进度条
- 动态生成专辑封面

## 6. API 使用示例

```swift
import SwiftUI

// 获取播放器实例
let player = AudioPlayerManager.shared

// 设置播放列表
let words = DataManager.shared.fetchDueWords(limit: 50)
player.setPlaylist(words: words, mode: .spaced)

// 播放控制
player.play()
player.pause()
player.nextTrack()
player.previousTrack()

// 切换模式
player.setPlaybackMode(.random)

// 调整播放速度
player.setPlaybackSpeed(1.5)

// 跳转到指定项
player.jumpToItem(at: 5)
```