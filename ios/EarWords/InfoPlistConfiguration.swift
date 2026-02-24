//
//  InfoPlistConfiguration.swift
//  EarWords
//
//  Info.plist 后台播放配置说明
//

/*
 ============================================================================
 INFO.PLIST 配置指南 - 后台播放支持
 ============================================================================
 
 在 Xcode 项目的 Info.plist 文件中添加以下配置：
 
 1. 后台音频模式（必需）
 ---------------------------------------------------------------------------
 键名: UIBackgroundModes
 类型: Array
 值:   - Item 0: String = "audio"
 
 或者使用原始 XML:
 
 <key>UIBackgroundModes</key>
 <array>
     <string>audio</string>
 </array>
 
 2. 音频使用描述（如果需要麦克风）
 ---------------------------------------------------------------------------
 键名: NSMicrophoneUsageDescription
 类型: String
 值: "EarWords 需要访问麦克风以支持语音输入功能"
 
 <key>NSMicrophoneUsageDescription</key>
 <string>EarWords 需要访问麦克风以支持语音输入功能</string>
 
 3. 完整 Info.plist 示例
 ---------------------------------------------------------------------------
 <?xml version="1.0" encoding="UTF-8"?>
 <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
 <plist version="1.0">
 <dict>
     <!-- 应用标识 -->
     <key>CFBundleIdentifier</key>
     <string>com.yourcompany.earwords</string>
     
     <!-- 应用名称 -->
     <key>CFBundleDisplayName</key>
     <string>EarWords</string>
     
     <!-- 后台模式 -->
     <key>UIBackgroundModes</key>
     <array>
         <string>audio</string>
     </array>
     
     <!-- 麦克风权限（如需要语音输入） -->
     <key>NSMicrophoneUsageDescription</key>
     <string>EarWords 需要访问麦克风以支持语音输入功能</string>
     
     <!-- 其他配置... -->
 </dict>
 </plist>
 
 ============================================================================
 XCODE CAPABILITIES 配置
 ============================================================================
 
 1. 打开 Xcode 项目
 2. 选择 Target → Signing & Capabilities
 3. 点击 "+ Capability"
 4. 添加 "Background Modes"
 5. 勾选以下选项：
    ☑ Audio, AirPlay, and Picture in Picture
 
 ============================================================================
 APP DELEGATE 配置（如果需要）
 ============================================================================
 
 在 AppDelegate.swift 或 EarWordsApp.swift 中确保音频会话配置：
 
 ```swift
 import AVFoundation
 
 @main
 struct EarWordsApp: App {
     @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
     
     var body: some Scene {
         WindowGroup {
             ContentView()
         }
     }
 }
 
 class AppDelegate: NSObject, UIApplicationDelegate {
     func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
         // 配置音频会话
         let session = AVAudioSession.sharedInstance()
         do {
             try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
             try session.setActive(true)
         } catch {
             print("音频会话配置失败: \(error)")
         }
         return true
     }
     
     // 处理音频中断
     func application(_ application: UIApplication,
                     handleInterruptionFor audioSession: AVAudioSession) {
         // 处理来电等中断事件
     }
 }
 ```
 
 ============================================================================
 功能验证清单
 ============================================================================
 
 [✓] 锁屏显示当前播放单词信息
 [✓] 锁屏控制播放/暂停
 [✓] 锁屏控制上一首/下一首
 [✓] 锁屏显示播放进度
 [✓] 耳机线控播放/暂停
 [✓] 耳机线控上一首/下一首
 [✓] 后台播放音频
 [✓] 其他应用音频淡入淡出（Duck）
 [✓] AirPlay 支持
 [✓] 蓝牙耳机支持
 
 ============================================================================
 */

import Foundation

// 此文件仅为配置说明，不需要编译到项目中
