//
//  Localization.swift
//  EarWords
//
//  Localization helper for SwiftUI
//  Created: 2026-02-24
//

import SwiftUI

// MARK: - Localization Helper
/// A centralized localization helper for the EarWords app
enum L {
    /// Returns a localized string for the given key
    static func string(_ key: String, tableName: String? = nil, comment: String = "") -> String {
        return NSLocalizedString(key, tableName: tableName, comment: comment)
    }
    
    /// Returns a localized string with format arguments
    static func string(format key: String, _ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, arguments: arguments)
    }
    
    /// Returns a localized string with a single integer argument
    static func string(format key: String, _ value: Int) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, value)
    }
    
    /// Returns a localized string with a single double argument
    static func string(format key: String, _ value: Double) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, value)
    }
}

// MARK: - View Extension for Localization
extension View {
    /// Sets the accessibility label using a localized key
    func localizedAccessibilityLabel(_ key: String) -> some View {
        self.accessibilityLabel(L.string(key))
    }
    
    /// Sets the accessibility hint using a localized key
    func localizedAccessibilityHint(_ key: String) -> some View {
        self.accessibilityHint(L.string(key))
    }
}

// MARK: - Text Extension for Localization
extension Text {
    /// Creates a Text view from a localized string key
    init(_ key: LocalizationKey) {
        self.init(LocalizedStringKey(key.rawValue))
    }
    
    /// Creates a Text view from a localized string key with format arguments
    init(format key: LocalizationKey, _ arguments: CVarArg...) {
        let format = NSLocalizedString(key.rawValue, comment: "")
        self.init(String(format: format, arguments: arguments))
    }
}

// MARK: - Localization Keys
/// Strongly typed localization keys to avoid typos
enum LocalizationKey: String {
    // App Information
    case appName = "app.name"
    case appTagline = "app.tagline"
    case appSubtitle = "app.subtitle"
    
    // Tabs
    case tabStudy = "tab.study"
    case tabAudio = "tab.audio"
    case tabStatistics = "tab.statistics"
    case tabVocabulary = "tab.vocabulary"
    case tabSettings = "tab.settings"
    
    // Common Actions
    case commonDone = "common.done"
    case commonCancel = "common.cancel"
    case commonSave = "common.save"
    case commonDelete = "common.delete"
    case commonClose = "common.close"
    case commonNext = "common.next"
    case commonSkip = "common.skip"
    case commonContinue = "common.continue"
    case commonFinish = "common.finish"
    case commonLoading = "common.loading"
    case commonRefresh = "common.refresh"
    
    // Study
    case studyEmptyTitle = "study.empty.title"
    case studyEmptyMessage = "study.empty.message"
    case studyEmptyButton = "study.empty.button"
    case studyCompleteTitle = "study.complete.title"
    
    // Status
    case statusNew = "status.new"
    case statusLearning = "status.learning"
    case statusMastered = "status.mastered"
    
    // Settings
    case settingsTitle = "settings.title"
    case settingsGoalsTitle = "settings.goals.title"
    case settingsAudioTitle = "settings.audio.title"
    case settingsRemindersTitle = "settings.reminders.title"
    case settingsAppearanceTitle = "settings.appearance.title"
    case settingsSyncTitle = "settings.sync.title"
    case settingsDataTitle = "settings.data.title"
    case settingsAboutTitle = "settings.about.title"
    
    // Audio
    case audioTitle = "audio.title"
    case audioSpeedSlow = "audio.speed.slow"
    case audioSpeedFast = "audio.speed.fast"
}

// MARK: - String Localization Extension
extension String {
    /// Localizes the string using itself as the key
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Localizes the string with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(self, comment: "")
        return String(format: format, arguments: arguments)
    }
}

// MARK: - Locale Extensions
extension Locale {
    /// Returns whether the current locale uses 24-hour time format
    static var uses24HourTime: Bool {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return !formatter.dateFormat.contains("a")
    }
    
    /// Returns the preferred language code
    static var preferredLanguage: String {
        return Locale.preferredLanguages.first ?? "en"
    }
    
    /// Returns whether the current locale is RTL
    static var isRTL: Bool {
        return Locale.characterDirection(forLanguage: preferredLanguage) == .rightToLeft
    }
    
    /// Returns whether the current locale uses metric system
    static var usesMetricSystem: Bool {
        return Locale.current.measurementSystem == .metric
    }
}

// MARK: - Number Formatter Extensions
extension NumberFormatter {
    /// Creates a localized number formatter for the current locale
    static var localized: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        return formatter
    }
    
    /// Creates a localized percentage formatter
    static var localizedPercentage: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }
}

// MARK: - Date Formatter Extensions
extension DateFormatter {
    /// Creates a localized short date formatter
    static var localizedShortDate: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
    
    /// Creates a localized medium date formatter
    static var localizedMediumDate: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    /// Creates a localized time formatter
    static var localizedTime: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Preview Support
#if DEBUG
struct LocalizationPreview: View {
    var body: some View {
        List {
            Section("App Info") {
                Text(L.string("app.name"))
                Text(L.string("app.tagline"))
            }
            
            Section("Tabs") {
                Text(L.string("tab.study"))
                Text(L.string("tab.audio"))
                Text(L.string("tab.statistics"))
            }
            
            Section("Formatted") {
                Text(L.string(format: "study.title", 42))
                Text(L.string(format: "stats.streakDays", 15))
                Text(L.string(format: "settings.audio.speechRate.value", 0.8))
            }
        }
    }
}

struct LocalizationPreview_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LocalizationPreview()
                .previewDisplayName("English")
            
            LocalizationPreview()
                .environment(\.locale, Locale(identifier: "zh-Hans"))
                .previewDisplayName("简体中文")
            
            LocalizationPreview()
                .environment(\.locale, Locale(identifier: "zh-Hant"))
                .previewDisplayName("繁體中文")
        }
    }
}
#endif
