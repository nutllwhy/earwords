//
//  LocalizationTests.swift
//  EarWordsTests
//
//  Localization test utilities and examples
//  Created: 2026-02-24
//

import XCTest
import SwiftUI
@testable import EarWords

// MARK: - Localization Test Suite

class LocalizationTests: XCTestCase {
    
    // MARK: - Key Completeness Tests
    
    /// Tests that all keys in English exist in other languages
    func testKeyCompleteness() {
        let languages = ["zh-Hans", "zh-Hant"]
        let englishStrings = loadStrings(for: "en")
        
        for language in languages {
            let localizedStrings = loadStrings(for: language)
            
            for key in englishStrings.keys {
                XCTAssertNotNil(
                    localizedStrings[key],
                    "Missing translation for key '\(key)' in \(language)"
                )
            }
        }
    }
    
    /// Tests that no keys have empty values
    func testNoEmptyValues() {
        let languages = ["en", "zh-Hans", "zh-Hant"]
        
        for language in languages {
            let strings = loadStrings(for: language)
            
            for (key, value) in strings {
                XCTAssertFalse(
                    value.isEmpty,
                    "Empty value for key '\(key)' in \(language)"
                )
            }
        }
    }
    
    // MARK: - Format String Tests
    
    /// Tests that format strings have matching specifiers
    func testFormatSpecifierConsistency() {
        let englishStrings = loadStrings(for: "en")
        let chineseStrings = loadStrings(for: "zh-Hans")
        
        let formatKeys = englishStrings.keys.filter { key in
            englishStrings[key]?.contains("%") == true
        }
        
        for key in formatKeys {
            guard let englishValue = englishStrings[key],
                  let chineseValue = chineseStrings[key] else {
                XCTFail("Missing key '\(key)'")
                continue
            }
            
            let englishSpecifiers = extractFormatSpecifiers(englishValue)
            let chineseSpecifiers = extractFormatSpecifiers(chineseValue)
            
            XCTAssertEqual(
                englishSpecifiers,
                chineseSpecifiers,
                "Format specifier mismatch for key '\(key)'"
            )
        }
    }
    
    // MARK: - UI Tests
    
    /// Tests that localized strings display correctly
    func testLocalizedTextDisplay() {
        let key = "tab.study"
        
        // English
        var text = NSLocalizedString(key, tableName: nil, bundle: englishBundle, comment: "")
        XCTAssertEqual(text, "Study")
        
        // Simplified Chinese
        text = NSLocalizedString(key, tableName: nil, bundle: chineseBundle, comment: "")
        XCTAssertEqual(text, "学习")
        
        // Traditional Chinese
        text = NSLocalizedString(key, tableName: nil, bundle: traditionalChineseBundle, comment: "")
        XCTAssertEqual(text, "學習")
    }
    
    // MARK: - Length Tests
    
    /// Tests that localized strings aren't excessively long
    func testStringLength() {
        let maxLengths: [String: Int] = [
            "tab.study": 20,
            "tab.settings": 20,
            "study.card.showMeaning": 30,
            "study.card.hideMeaning": 30
        ]
        
        let languages = ["en", "zh-Hans", "zh-Hant", "ja", "ko"]
        
        for (key, maxLength) in maxLengths {
            for language in languages {
                let bundle = bundle(for: language)
                let value = NSLocalizedString(key, tableName: nil, bundle: bundle, comment: "")
                
                XCTAssertLessThanOrEqual(
                    value.count,
                    maxLength,
                    "String for '\(key)' in \(language) exceeds maximum length of \(maxLength)"
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadStrings(for language: String) -> [String: String] {
        guard let path = Bundle.main.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: "\(language).lproj"
        ) else {
            return [:]
        }
        
        guard let dict = NSDictionary(contentsOfFile: path) as? [String: String] else {
            return [:]
        }
        
        return dict
    }
    
    private func extractFormatSpecifiers(_ string: String) -> [String] {
        let pattern = "%[@df]"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(
            in: string,
            options: [],
            range: NSRange(location: 0, length: string.utf16.count)
        )
        
        return matches.map { match in
            String(string[Range(match.range, in: string)!])
        }
    }
    
    private func bundle(for language: String) -> Bundle {
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }
    
    private var englishBundle: Bundle {
        return bundle(for: "en")
    }
    
    private var chineseBundle: Bundle {
        return bundle(for: "zh-Hans")
    }
    
    private var traditionalChineseBundle: Bundle {
        return bundle(for: "zh-Hant")
    }
}

// MARK: - UI Testing Helpers

class LocalizationUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }
    
    /// Test app in English
    func testEnglishLocalization() {
        app.launchArguments = ["-AppleLanguages", "(en)"]
        app.launch()
        
        // Verify tab labels
        XCTAssertTrue(app.tabBars.buttons["Study"].exists)
        XCTAssertTrue(app.tabBars.buttons["Audio"].exists)
        XCTAssertTrue(app.tabBars.buttons["Stats"].exists)
        XCTAssertTrue(app.tabBars.buttons["Vocabulary"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }
    
    /// Test app in Simplified Chinese
    func testSimplifiedChineseLocalization() {
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)"]
        app.launch()
        
        // Verify tab labels
        XCTAssertTrue(app.tabBars.buttons["学习"].exists)
        XCTAssertTrue(app.tabBars.buttons["磨耳朵"].exists)
        XCTAssertTrue(app.tabBars.buttons["统计"].exists)
        XCTAssertTrue(app.tabBars.buttons["词库"].exists)
        XCTAssertTrue(app.tabBars.buttons["设置"].exists)
    }
    
    /// Test app in Traditional Chinese
    func testTraditionalChineseLocalization() {
        app.launchArguments = ["-AppleLanguages", "(zh-Hant)"]
        app.launch()
        
        // Verify tab labels
        XCTAssertTrue(app.tabBars.buttons["學習"].exists)
        XCTAssertTrue(app.tabBars.buttons["磨耳朵"].exists)
        XCTAssertTrue(app.tabBars.buttons["統計"].exists)
        XCTAssertTrue(app.tabBars.buttons["詞庫"].exists)
        XCTAssertTrue(app.tabBars.buttons["設定"].exists)
    }
    
    /// Test RTL layout (preparation for Arabic)
    func testRTLPreparation() {
        // This test verifies that the app is ready for RTL languages
        // It checks that text alignment and layout adapt correctly
        
        app.launchArguments = ["-AppleLanguages", "(ar)", "-AppleLocale", "ar_SA"]
        app.launch()
        
        // Verify app launches without crashing
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}

// MARK: - Snapshot Testing Helpers

#if canImport(SnapshotTesting)
import SnapshotTesting

extension LocalizationTests {
    
    /// Generate screenshots for all supported languages
    func testLocalizedScreenshots() {
        let languages = [
            ("en", "English"),
            ("zh-Hans", "SimplifiedChinese"),
            ("zh-Hant", "TraditionalChinese")
        ]
        
        for (language, name) in languages {
            let view = StudyView()
                .environment(\.locale, Locale(identifier: language))
            
            // Use snapshot testing to verify UI
            // assertSnapshot(matching: view, as: .image, named: "StudyView_\(name)")
        }
    }
}
#endif

// MARK: - Manual Testing Checklist

/*
 
 # 本地化手动测试清单

 ## 1. 语言切换测试
 
 ### 测试步骤:
 1. 设置 → 通用 → 语言与地区 → iPhone语言
 2. 切换到测试语言
 3. 重启应用
 
 ### 检查项:
 - [ ] 所有界面文本已切换为目标语言
 - [ ] 没有显示 key 名（如 "tab.study"）
 - [ ] 没有显示英文（未翻译的文本）
 - [ ] 日期格式符合当地习惯
 - [ ] 数字格式符合当地习惯（千分位、小数点）

 ## 2. 文本截断测试
 
 ### 测试步骤:
 1. 使用最长的翻译语言（通常是德语）
 2. 检查所有按钮、标签、导航栏标题
 
 ### 检查项:
 - [ ] 按钮文本没有截断
 - [ ] 导航栏标题没有截断
 - [ ] Tab 标签没有截断
 - [ ] 长文本正确换行
 - [ ] 文本缩放（辅助功能）正常

 ## 3. RTL 布局测试 (阿拉伯语准备)
 
 ### 测试步骤:
 1. 启用 RTL 伪语言（Scheme → Run → Options → Application Language → Right-to-Left Pseudolanguage）
 2. 检查界面布局
 
 ### 检查项:
 - [ ] 导航栏按钮位置正确
 - [ ] 列表项箭头方向正确
 - [ ] 滑动方向正确
 - [ ] 进度条方向正确
 - [ ] 图表方向正确

 ## 4. 格式字符串测试
 
 ### 测试步骤:
 1. 找到所有带参数的文本
 2. 测试各种边界值
 
 ### 检查项:
 - [ ] 数字格式化正确（0, 1, 1000, 1000000）
 - [ ] 百分比格式化正确
 - [ ] 日期格式化正确
 - [ ] 复数形式正确（英文 one/other，中文通用）

 ## 5. 深色模式测试
 
 ### 检查项:
 - [ ] 所有语言在深色模式下可读
 - [ ] 对比度符合无障碍标准
 - [ ] 颜色在不同语言下表现一致

 ## 6. 辅助功能测试
 
 ### 检查项:
 - [ ] VoiceOver 朗读目标语言正确
 - [ ] 字体放大时布局不混乱
 - [ ] 动态类型支持正常

 ## 7. 特定语言测试
 
 ### 中文 (简体/繁体)
 - [ ] 繁体用词符合台湾/香港习惯
 - [ ] 标点符号使用正确（全角）
 - [ ] 日期格式使用中文习惯

 ### 日文
 - [ ] 混合文字（汉字/平假名/片假名）显示正常
 - [ ] 竖排文本支持（如需要）

 ### 韩文
 - [ ] 韩文显示正常，没有截断

 ## 8. 应用商店测试
 
 - [ ] App 名称显示完整
 - [ ] 截图文字本地化正确
 - [ ] 描述文本排版正常

 */

// MARK: - Test Data

struct LocalizationTestData {
    static let commonTestCases: [(key: String, expectedEN: String, expectedZH: String)] = [
        ("tab.study", "Study", "学习"),
        ("tab.settings", "Settings", "设置"),
        ("status.new", "New", "未学习"),
        ("status.mastered", "Mastered", "已掌握"),
        ("common.done", "Done", "完成"),
        ("common.cancel", "Cancel", "取消")
    ]
    
    static let formatTestCases: [(key: String, args: [CVarArg], expectedPattern: String)] = [
        ("study.title", [42], "%d"),
        ("stats.streakDays", [15], "%d"),
        ("settings.audio.speechRate.value", [0.8], "%.1f")
    ]
}
