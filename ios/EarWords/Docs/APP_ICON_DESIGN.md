# EarWords 应用图标设计规范

## 设计理念

### 核心概念
- **耳朵**：代表"听词"的核心功能
- **声波/音符**：代表音频学习
- **书本/文字**：代表词汇学习
- **简约现代**：符合 iOS 设计规范

## 设计规格

### 主图标 (1024x1024)
```
背景：渐变紫色 (#7B61FF → #6366F1)
中心：白色耳朵轮廓图标
装饰：右下角小型声波图案（可选）
圆角：系统自动处理（原始图为方形）
```

### 设计元素

#### 颜色方案
| 元素 | 颜色 | HEX |
|-----|------|-----|
| 主背景色 | 紫罗兰 | #7B61FF |
| 次背景色 | 靛蓝 | #6366F1 |
| 图标主色 | 白色 | #FFFFFF |
| 图标阴影 | 深紫 | rgba(0,0,0,0.2) |

#### 图标比例
- 耳朵图标占画布 60-70%
- 居中放置
- 周围留白充足

### 导出规格

#### iPhone 图标尺寸
| 尺寸 | 用途 | 文件名 |
|-----|------|-------|
| 20x20@2x | 通知 | AppIcon-20x20@2x.png |
| 20x20@3x | 通知 | AppIcon-20x20@3x.png |
| 29x29@2x | 设置 | AppIcon-29x29@2x.png |
| 29x29@3x | 设置 | AppIcon-29x29@3x.png |
| 40x40@2x | Spotlight | AppIcon-40x40@2x.png |
| 40x40@3x | Spotlight | AppIcon-40x40@3x.png |
| 60x60@2x | App | AppIcon-60x60@2x.png |
| 60x60@3x | App | AppIcon-60x60@3x.png |

#### iPad 图标尺寸
| 尺寸 | 用途 | 文件名 |
|-----|------|-------|
| 20x20@1x | 通知 | AppIcon-20x20@1x.png |
| 20x20@2x | 通知 | AppIcon-20x20@2x.png |
| 29x29@1x | 设置 | AppIcon-29x29@1x.png |
| 29x29@2x | 设置 | AppIcon-29x29@2x.png |
| 40x40@1x | Spotlight | AppIcon-40x40@1x.png |
| 40x40@2x | Spotlight | AppIcon-40x40@2x.png |
| 76x76@1x | App | AppIcon-76x76@1x.png |
| 76x76@2x | App | AppIcon-76x76@2x.png |
| 83.5x83.5@2x | App | AppIcon-83.5x83.5@2x.png |
| 1024x1024@1x | App Store | AppIcon-1024x1024@1x.png |

## SwiftUI 图标预览

### Launch Screen 图标动画
```swift
struct AppIconPreview: View {
    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                colors: [Color(#colorLiteral(red: 0.482, green: 0.38, blue: 1, alpha: 1)),
                        Color(#colorLiteral(red: 0.388, green: 0.4, blue: 0.945, alpha: 1))],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 耳朵图标
            Image(systemName: "ear.fill")
                .font(.system(size: 120))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        }
        .frame(width: 1024, height: 1024)
    }
}
```

## 图标文件组织

```
Resources/
├── AppIcon.appiconset/
│   ├── Contents.json
│   ├── AppIcon-20x20@2x.png
│   ├── AppIcon-20x20@3x.png
│   ├── AppIcon-29x29@2x.png
│   ├── AppIcon-29x29@3x.png
│   ├── AppIcon-40x40@2x.png
│   ├── AppIcon-40x40@3x.png
│   ├── AppIcon-60x60@2x.png
│   ├── AppIcon-60x60@3x.png
│   ├── AppIcon-20x20@1x.png
│   ├── AppIcon-29x29@1x.png
│   ├── AppIcon-40x40@1x.png
│   ├── AppIcon-76x76@1x.png
│   ├── AppIcon-76x76@2x.png
│   ├── AppIcon-83.5x83.5@2x.png
│   └── AppIcon-1024x1024@1x.png
└── AppIcon.sketch (设计源文件)
```

## 设计检查清单

- [ ] 主图标 1024x1024 已完成
- [ ] 所有尺寸已导出
- [ ] 图标在各尺寸下都清晰可辨
- [ ] 符合 iOS 人机界面指南
- [ ] 与 App 整体风格一致
- [ ] 在不同背景下都可识别
- [ ] 不包含文字（除非品牌必须）
- [ ] 未使用透明背景

## 设计工具推荐

1. **Figma** - 在线协作设计
2. **Sketch** - Mac 专业设计工具
3. **Adobe Illustrator** - 矢量图形设计
4. **SF Symbols** - Apple 官方图标库

## 参考资源

- [Apple Human Interface Guidelines - Icons](https://developer.apple.com/design/human-interface-guidelines/ios/overview/icons/)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
- [App Icon Generator](https://appicon.co/)
