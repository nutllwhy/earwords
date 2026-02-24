//
//  Theme.swift
//  EarWords
//
//  主题管理 - 深色模式适配 + 动态主题
//

import SwiftUI

// MARK: - 主题颜色枚举
enum ThemeColor: String, CaseIterable, Identifiable {
    case purple = "purple"
    case blue = "blue"
    case green = "green"
    case orange = "orange"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .purple: return "紫罗兰"
        case .blue: return "天空蓝"
        case .green: return "森林绿"
        case .orange: return "活力橙"
        }
    }
    
    var icon: String {
        switch self {
        case .purple: return "paintpalette.fill"
        case .blue: return "drop.fill"
        case .green: return "leaf.fill"
        case .orange: return "flame.fill"
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .purple: return Color("AccentPurple")
        case .blue: return Color("AccentBlue")
        case .green: return Color("AccentGreen")
        case .orange: return Color("AccentOrange")
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .purple: return .blue
        case .blue: return .cyan
        case .green: return .mint
        case .orange: return .yellow
        }
    }
    
    var gradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - 主题管理器
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: ThemeColor {
        didSet {
            saveTheme()
            applyTheme()
        }
    }
    
    @Published var useSystemAppearance: Bool {
        didSet {
            UserDefaults.standard.set(useSystemAppearance, forKey: Keys.useSystemAppearance)
        }
    }
    
    @Published var forceDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(forceDarkMode, forKey: Keys.forceDarkMode)
        }
    }
    
    // MARK: - Keys
    private struct Keys {
        static let themeColor = "appThemeColor"
        static let useSystemAppearance = "useSystemAppearance"
        static let forceDarkMode = "forceDarkMode"
    }
    
    // MARK: - 初始化
    private init() {
        // 加载保存的主题
        let savedTheme = UserDefaults.standard.string(forKey: Keys.themeColor) ?? "purple"
        self.currentTheme = ThemeColor(rawValue: savedTheme) ?? .purple
        
        // 加载外观设置
        self.useSystemAppearance = UserDefaults.standard.bool(forKey: Keys.useSystemAppearance)
        if !UserDefaults.standard.objectIsForced(forKey: Keys.useSystemAppearance) {
            self.useSystemAppearance = true // 默认跟随系统
        }
        self.forceDarkMode = UserDefaults.standard.bool(forKey: Keys.forceDarkMode)
    }
    
    // MARK: - 保存主题
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: Keys.themeColor)
    }
    
    // MARK: - 应用主题
    private func applyTheme() {
        // 通知主题变更
        NotificationCenter.default.post(name: .themeChanged, object: currentTheme)
        
        // 刷新小组件
        WidgetDataProvider.shared.reloadWidgetData()
    }
    
    // MARK: - 获取当前颜色方案
    var colorScheme: ColorScheme? {
        if useSystemAppearance {
            return nil // 使用系统设置
        }
        return forceDarkMode ? .dark : .light
    }
    
    // MARK: - 切换主题
    func setTheme(_ theme: ThemeColor) {
        currentTheme = theme
    }
    
    // MARK: - 切换外观模式
    func setAppearance(useSystem: Bool, darkMode: Bool = false) {
        useSystemAppearance = useSystem
        if !useSystem {
            forceDarkMode = darkMode
        }
    }
}

// MARK: - 颜色定义扩展

extension ThemeManager {
    // 主色调
    var primary: Color { currentTheme.primaryColor }
    
    // 次要色
    var secondary: Color { currentTheme.secondaryColor }
    
    // 渐变色
    var gradient: LinearGradient { currentTheme.gradient }
    
    // 成功色
    var success: Color { Color("SuccessColor") }
    
    // 警告色
    var warning: Color { Color("WarningColor") }
    
    // 错误色
    var error: Color { Color("ErrorColor") }
}

// MARK: - AppColors 扩展（兼容旧代码）

enum AppColors {
    // 使用 ThemeManager 的主色调
    static var primary: Color { ThemeManager.shared.primary }
    static var secondary: Color { ThemeManager.shared.secondary }
    static var success: Color { ThemeManager.shared.success }
    static var warning: Color { ThemeManager.shared.warning }
    static var error: Color { ThemeManager.shared.error }
    
    // 获取当前主题渐变色
    static var gradient: LinearGradient { ThemeManager.shared.gradient }
    
    // 背景色（自动适应深色模式）
    static func background(for colorScheme: ColorScheme) -> Color {
        Color(.systemBackground)
    }
    
    static func secondaryBackground(for colorScheme: ColorScheme) -> Color {
        Color(.secondarySystemBackground)
    }
    
    // 卡片背景（自动适应深色模式）
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        Color("CardBackground")
    }
    
    // 文字颜色
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .primary
    }
    
    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.gray.opacity(0.8) : .secondary
    }
    
    // 进度条渐变（当前主题色）
    static func progressGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let colors: [Color]
        switch ThemeManager.shared.currentTheme {
        case .purple:
            colors = colorScheme == .dark ? 
                [Color.purple.opacity(0.8), Color.blue.opacity(0.8)] :
                [.purple, .blue]
        case .blue:
            colors = colorScheme == .dark ?
                [Color.blue.opacity(0.8), Color.cyan.opacity(0.8)] :
                [.blue, .cyan]
        case .green:
            colors = colorScheme == .dark ?
                [Color.green.opacity(0.8), Color.mint.opacity(0.8)] :
                [.green, .mint]
        case .orange:
            colors = colorScheme == .dark ?
                [Color.orange.opacity(0.8), Color.yellow.opacity(0.8)] :
                [.orange, .yellow]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
    
    // 图表颜色（当前主题色系）
    static func chartColors(for colorScheme: ColorScheme) -> [Color] {
        let opacity = colorScheme == .dark ? 0.8 : 1.0
        switch ThemeManager.shared.currentTheme {
        case .purple:
            return [Color.purple.opacity(opacity), Color.blue.opacity(opacity), Color.cyan.opacity(opacity)]
        case .blue:
            return [Color.blue.opacity(opacity), Color.cyan.opacity(opacity), Color.mint.opacity(opacity)]
        case .green:
            return [Color.green.opacity(opacity), Color.mint.opacity(opacity), Color.teal.opacity(opacity)]
        case .orange:
            return [Color.orange.opacity(opacity), Color.yellow.opacity(opacity), Color.red.opacity(opacity)]
        }
    }
}

// MARK: - 视图修饰符

struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.cardBackground(for: colorScheme))
                    .shadow(
                        color: colorScheme == .dark ? .clear : .black.opacity(0.08),
                        radius: 10, x: 0, y: 5
                    )
            )
    }
}

struct ThemedBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: colorScheme == .dark ?
                        [ThemeManager.shared.primary.opacity(0.1), ThemeManager.shared.secondary.opacity(0.05)] :
                        [ThemeManager.shared.primary.opacity(0.05), ThemeManager.shared.secondary.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
    }
}

struct AdaptiveText: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    let style: TextStyle
    
    enum TextStyle {
        case primary
        case secondary
        case accent
    }
    
    func body(content: Content) -> some View {
        switch style {
        case .primary:
            content.foregroundColor(AppColors.primaryText(for: colorScheme))
        case .secondary:
            content.foregroundColor(AppColors.secondaryText(for: colorScheme))
        case .accent:
            content.foregroundColor(ThemeManager.shared.primary)
        }
    }
}

// MARK: - View 扩展

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }
    
    func adaptiveText(_ style: AdaptiveText.TextStyle = .primary) -> some View {
        modifier(AdaptiveText(style: style))
    }
}

// MARK: - 主题选择器视图

struct ThemePickerView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("主题颜色") {
                    ForEach(ThemeColor.allCases) { theme in
                        Button(action: {
                            themeManager.setTheme(theme)
                        }) {
                            HStack {
                                // 颜色预览
                                ZStack {
                                    Circle()
                                        .fill(theme.gradient)
                                        .frame(width: 32, height: 32)
                                    
                                    if themeManager.currentTheme == theme {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                Text(theme.displayName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                        }
                    }
                }
                
                Section("外观模式") {
                    Toggle("跟随系统", isOn: $themeManager.useSystemAppearance)
                    
                    if !themeManager.useSystemAppearance {
                        Picker("外观", selection: $themeManager.forceDarkMode) {
                            Text("浅色").tag(false)
                            Text("深色").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                Section("预览") {
                    ThemePreviewCard()
                }
            }
            .navigationTitle("主题设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 主题预览卡片

struct ThemePreviewCard: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            Text("主题预览")
                .font(.headline)
                .adaptiveText(.primary)
            
            // 渐变色展示
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.gradient)
                .frame(height: 60)
                .overlay(
                    Text("渐变色")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                )
            
            // 按钮样式
            HStack(spacing: 12) {
                Button {} label: {
                    Text("主按钮")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(themeManager.primary)
                        .cornerRadius(8)
                }
                
                Button {} label: {
                    Text("次要按钮")
                        .font(.caption)
                        .foregroundColor(themeManager.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(themeManager.primary.opacity(colorScheme == .dark ? 0.2 : 0.1))
                        .cornerRadius(8)
                }
            }
            
            // 状态颜色
            HStack(spacing: 16) {
                Label("成功", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(themeManager.success)
                
                Label("警告", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(themeManager.warning)
                
                Label("错误", systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(themeManager.error)
            }
        }
        .padding()
        .cardStyle()
    }
}

// MARK: - 通知扩展

extension Notification.Name {
    static let themeChanged = Notification.Name("themeChanged")
}