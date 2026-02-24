//
//  EarWordsWidgetBundle.swift
//  EarWordsWidgets
//
//  小组件 Bundle
//

import WidgetKit
import SwiftUI

@main
struct EarWordsWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayProgressWidget()
        LockScreenProgressWidget()
    }
}
