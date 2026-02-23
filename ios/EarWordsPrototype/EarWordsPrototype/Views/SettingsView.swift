//
//  SettingsView.swift
//  设置界面原型
//

import SwiftUI

struct SettingsView: View {
    @State private var dailyNewWords = 20
    @State private var dailyReview = 50
    @State private var autoPlay = true
    @State private var showPhonetic = true
    @State private var showExample = false
    @State private var speechRate: Double = 0.8
    @State private var reminderEnabled = true
    @State private var reminderTime = Date()
    @State private var iCloudEnabled = true
    
    var body: some View {
        NavigationView {
            List {
                // 每日目标
                Section("每日目标") {
                    Stepper("新单词: \(dailyNewWords)", value: $dailyNewWords, in: 5...50)
                    Stepper("复习单词: \(dailyReview)", value: $dailyReview, in: 10...100)
                }
                
                // 播放设置
                Section("音频设置") {
                    Toggle("自动播放音频", isOn: $autoPlay)
                    Toggle("显示音标", isOn: $showPhonetic)
                    Toggle("显示例句", isOn: $showExample)
                    
                    VStack(alignment: .leading) {
                        Text("语速")
                            .font(.subheadline)
                        Slider(value: $speechRate, in: 0.5...1.0)
                        HStack {
                            Text("慢")
                            Spacer()
                            Text("快")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                // 提醒设置
                Section("学习提醒") {
                    Toggle("启用提醒", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
                
                // 同步设置
                Section("同步") {
                    Toggle("iCloud 同步", isOn: $iCloudEnabled)
                    Button("立即同步") {}
                }
                
                // 数据管理
                Section("数据管理") {
                    Button("重置学习进度", role: .destructive) {}
                    Button("导出学习数据") {}
                }
                
                // 关于
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
