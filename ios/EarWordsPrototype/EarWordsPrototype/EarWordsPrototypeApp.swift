//
//  EarWordsPrototypeApp.swift
//  EarWords SwiftUI 原型
//

import SwiftUI

@main
struct EarWordsPrototypeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            StudyView()
                .tabItem {
                    Label("学习", systemImage: "book.fill")
                }
                .tag(0)
            
            AudioReviewView()
                .tabItem {
                    Label("磨耳朵", systemImage: "headphones")
                }
                .tag(1)
            
            StatisticsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar.fill")
                }
                .tag(2)
            
            WordListView()
                .tabItem {
                    Label("词库", systemImage: "list.bullet")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .accentColor(.purple)
    }
}
