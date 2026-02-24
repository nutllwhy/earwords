# EarWords 国际化 (i18n) 指南

> 创建时间: 2026-02-24
> 版本: 1.0

## 目录

1. [支持语言](#支持语言)
2. [文件结构](#文件结构)
3. [添加新语言](#添加新语言)
4. [代码国际化](#代码国际化)
5. [界面布局适配](#界面布局适配)
6. [RTL支持](#rtl支持)
7. [测试验证](#测试验证)
8. [应用商店本地化](#应用商店本地化)
9. [文化适配](#文化适配)

---

## 支持语言

### 当前支持

| 语言 | 代码 | 地区 | 状态 |
|------|------|------|------|
| English | `en` | 美国/英国 | ✅ 完成 |
| 简体中文 | `zh-Hans` | 中国大陆 | ✅ 完成 |
| 繁體中文 | `zh-Hant` | 台湾/香港 | ✅ 完成 |

### 计划支持

| 语言 | 代码 | 优先级 | 说明 |
|------|------|--------|------|
| 日本語 | `ja` | 🔴 高 | 日本是英语学习大市场 |
| 한국어 | `ko` | 🔴 高 | 韩国英语教育需求大 |
| Deutsch | `de` | 🟡 中 | 欧洲市场 |
| Español | `es` | 🟡 中 | 拉美市场 |
| Français | `fr` | 🟡 中 | 欧洲市场 |
| العربية | `ar` | 🟢 低 | 需要RTL支持 |
| Русский | `ru` | 🟢 低 | 俄罗斯市场 |

---

## 文件结构

```
EarWords/
├── Resources/
│   ├── Localizations/
│   │   ├── en.lproj/
│   │   │   └── Localizable.strings      # 英文主文件
│   │   ├── zh-Hans.lproj/
│   │   │   └── Localizable.strings      # 简体中文
│   │   ├── zh-Hant.lproj/
│   │   │   └── Localizable.strings      # 繁體中文
│   │   └── ... (其他语言)
│   └── Localization.swift               # 本地化工具类
├── Docs/
│   ├── LOCALIZATION.md                  # 本文件
│   └── APPSTORE_LOCALIZATION.md         # 应用商店本地化
└── Views/
    └── ... (使用NSLocalizedString的代码)
```

---

## 添加新语言

### 步骤 1: 创建语言目录

```bash
mkdir -p EarWords/Resources/Localizations/xx.lproj
```

### 步骤 2: 复制基础文件

```bash
cp EarWords/Resources/Localizations/en.lproj/Localizable.strings \
   EarWords/Resources/Localizations/xx.lproj/Localizable.strings
```

### 步骤 3: 翻译内容

参考 [本地化键值对照表](#本地化键值对照表) 进行翻译。

### 步骤 4: 更新 Xcode 项目

1. 将新语言文件夹添加到 Xcode 项目
2. 在 Project Settings → Info → Localizations 中添加新语言
3. 确保 `Localizable.strings` 文件已勾选新语言

### 步骤 5: 测试

```swift
// 在模拟器中测试
let locale = Locale(identifier: "xx")
```

---

## 代码国际化

### 基础用法

#### SwiftUI Text
```swift
// ❌ 不要使用硬编码字符串
Text("学习")

// ✅ 使用 LocalizedStringKey
Text("tab.study")

// ✅ 使用辅助函数
Text(L.string("tab.study"))
```

#### 格式化字符串
```swift
// 带参数的本地化
Text(L.string(format: "study.title", wordCount))
Text(L.string(format: "stats.streakDays", streakDays))

// SwiftUI 原生支持
Text("study.title \(wordCount)")
```

#### 复数形式
```swift
// 使用 .stringsdict 处理复数
Text("word.count \(count)")
```

### 完整示例

```swift
struct StudyView: View {
    @State private var wordCount = 20
    
    var body: some View {
        VStack {
            // 标题
            Text(L.string(format: "study.title", wordCount))
                .font(.title)
            
            // 空状态
            Text(L.string("study.empty.title"))
            Text(L.string("study.empty.message"))
            
            // 按钮
            Button(L.string("study.empty.button")) {
                refresh()
            }
        }
    }
}
```

---

## 界面布局适配

### 文本长度差异

不同语言的文本长度可能差异很大：

| 英语 | 德语 | 增长 |
|------|------|------|
| Settings | Einstellungen | +60% |
| Skip | Überspringen | +130% |
| Study | Lernen | +25% |

### 适配策略

#### 1. 使用自适应布局
```swift
// ✅ 使用 Frame 约束
Text(L.string("settings.title"))
    .frame(maxWidth: .infinity, alignment: .leading)
    .lineLimit(1)
    .minimumScaleFactor(0.7)

// ✅ 允许多行
Text(L.string("study.empty.message"))
    .fixedSize(horizontal: false, vertical: true)
    .multilineTextAlignment(.center)
```

#### 2. 使用 SF Symbols
```swift
// ✅ 图标不需要翻译
Image(systemName: "gear")
Label(L.string("tab.settings"), systemImage: "gearshape.fill")
```

#### 3. 动态字体
```swift
Text(L.string("app.name"))
    .font(.system(size: 24, weight: .bold))
    .adjustsFontSizeToFitWidth(true)
```

---

## RTL支持

### RTL语言列表

- العربية (阿拉伯语)
- עברית (希伯来语)
- اردو (乌尔都语)
- فارسی (波斯语)

### 准备工作

#### 1. 检查界面方向
```swift
@Environment(\.layoutDirection) private var layoutDirection

var isRTL: Bool {
    layoutDirection == .rightToLeft
}
```

#### 2. 自动镜像图标
```swift
Image(systemName: "arrow.right")
    .flipsForRightToLeftLayoutDirection(true)
```

#### 3. 布局适配
```swift
HStack {
    // 内容会根据 RTL 自动调整
}
.environment(\.layoutDirection, .rightToLeft) // 测试用
```

### 需要特别注意的控件

```swift
// ✅ Slider - 自动适配
Slider(value: $progress)

// ✅ ProgressView - 自动适配
ProgressView(value: progress)

// ⚠️ 自定义进度条需要处理
GeometryReader { geometry in
    HStack(spacing: 0) {
        // 使用 HStack 会自动适配 RTL
        Rectangle()
            .frame(width: geometry.size.width * progress)
    }
}
```

---

## 测试验证

### 手动测试

```swift
// 在 Preview 中测试不同语言
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewDisplayName("English")
            
            ContentView()
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .previewDisplayName("简体中文")
            
            ContentView()
                .environment(\.locale, Locale(identifier: "ar"))
                .environment(\.layoutDirection, .rightToLeft)
                .previewDisplayName("العربية (RTL)")
        }
    }
}
```

### 自动化检查清单

- [ ] 所有用户界面文本都使用 `NSLocalizedString`
- [ ] 日期/时间格式使用 `DateFormatter`
- [ ] 数字格式使用 `NumberFormatter`
- [ ] 文本截断处理
- [ ] RTL 布局测试
- [ ] 不同屏幕尺寸测试
- [ ] 长文本溢出测试

### 伪本地化测试

创建伪语言文件测试布局：

```strings
/* Pseudo-language for testing */
"tab.study" = "Šţûðý˙˙˙";
"study.title" = "Šţûðý˙˙˙ (%d) 》》》";
```

---

## 应用商店本地化

见 [APPSTORE_LOCALIZATION.md](APPSTORE_LOCALIZATION.md) 文件。

### 关键要素

| 项目 | 长度限制 | 说明 |
|------|----------|------|
| App名称 | 30字符 | 需要简洁 |
| 副标题 | 30字符 | 补充说明 |
| 关键词 | 100字符 | 搜索优化 |
| 描述 | 4000字符 | 详细介绍 |
| 更新说明 | 4000字符 | 版本更新内容 |

---

## 文化适配

### 图标/颜色检查

| 元素 | 文化差异 | 建议 |
|------|----------|------|
| 👍 手势 | 部分地区有负面含义 | 使用中性图标 |
| 🐷 猪 | 伊斯兰教地区禁忌 | 避免使用 |
| 🍀 四叶草 | 西方幸运符号 | 亚洲可能不理解 |
| 红色 | 中国喜庆/西方危险 | 注意上下文 |

### 日期格式

```swift
// ✅ 使用本地化日期
let formatter = DateFormatter()
formatter.dateStyle = .medium
formatter.timeStyle = .short

// 美国: Jan 1, 2026 at 3:30 PM
// 中国: 2026年1月1日 下午3:30
// 日本: 2026/01/01 15:30
```

### 数字格式

```swift
// ✅ 使用 NumberFormatter
let formatter = NumberFormatter()
formatter.numberStyle = .decimal

// 美国: 1,234,567.89
// 德国: 1.234.567,89
// 法国: 1 234 567,89
```

### 示例内容本地化

原应用中的雅思词汇内容应保持英文，但界面说明需要本地化：

```swift
// 词汇内容保持英文
Text(word.word)  // "atmosphere"
Text(word.meaning) // 根据用户语言显示翻译
```

---

## 本地化键值对照表

### 命名规范

```
[模块].[子模块].[描述]

示例:
tab.study                    # 标签栏-学习
tab.audio                    # 标签栏-磨耳朵
study.empty.title            # 学习页-空状态-标题
study.empty.message          # 学习页-空状态-消息
settings.audio.autoPlay      # 设置-音频-自动播放
```

### 常用键值速查

| 键值 | 英文 | 简体中文 | 繁體中文 |
|------|------|----------|----------|
| tab.study | Study | 学习 | 學習 |
| tab.audio | Audio | 磨耳朵 | 磨耳朵 |
| tab.statistics | Stats | 统计 | 統計 |
| tab.vocabulary | Vocabulary | 词库 | 詞庫 |
| tab.settings | Settings | 设置 | 設定 |
| status.new | New | 未学习 | 未學習 |
| status.learning | Learning | 学习中 | 學習中 |
| status.mastered | Mastered | 已掌握 | 已掌握 |

---

## 更新维护

### 添加新字符串流程

1. 在 `en.lproj/Localizable.strings` 中添加英文原文
2. 在 `zh-Hans.lproj/Localizable.strings` 中添加简体中文
3. 在 `zh-Hant.lproj/Localizable.strings` 中添加繁體中文
4. 代码中使用新的 key
5. 更新本文档的键值对照表

### 质量检查

```bash
# 检查各语言文件的 key 是否一致
diff <(grep -o '"[^"]*"' en.lproj/Localizable.strings | sort) \
     <(grep -o '"[^"]*"' zh-Hans.lproj/Localizable.strings | sort)
```

---

## 参考资源

- [Apple Localization Guide](https://developer.apple.com/documentation/xcode/localization)
- [SwiftUI Localization](https://developer.apple.com/documentation/swiftui/app-essentials/localization)
- [String Catalogs](https://developer.apple.com/documentation/xcode/localizing-strings-using-string-catalogs) (iOS 15+)
- [RTL Best Practices](https://material.io/design/usability/bidirectionality.html)

---

*最后更新: 2026-02-24*
