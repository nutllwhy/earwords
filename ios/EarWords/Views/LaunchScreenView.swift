//
//  LaunchScreenView.swift
//  EarWords
//
//  启动页视图 - 用于 Launch Screen
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var isAnimating = false
    @State private var showTagline = false
    
    var body: some View {
        ZStack {
            // 背景色
            Color.purple
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Logo 区域
                ZStack {
                    // 外圈光晕
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: isAnimating ? 200 : 150, height: isAnimating ? 200 : 150)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                    
                    // 中圈
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 140, height: 140)
                    
                    // 图标容器
                    Circle()
                        .fill(.white)
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                    
                    // 耳朵图标
                    Image(systemName: "ear.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.purple)
                        .rotationEffect(.degrees(isAnimating ? 5 : -5))
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isAnimating)
                }
                
                // App 名称
                VStack(spacing: 8) {
                    Text("EarWords")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                    
                    // 副标题
                    Text("听词")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // 标语
                if showTagline {
                    Text("雅思词汇 · 磨耳朵学习")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
                
                // 版本号
                Text("Version 1.0.0")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            isAnimating = true
            withAnimation(.easeOut.delay(0.5)) {
                showTagline = true
            }
        }
    }
}

// MARK: - 启动页控制器（用于 UIKit 集成）
import UIKit

class LaunchScreenViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let hostingController = UIHostingController(rootView: LaunchScreenView())
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
    }
}

// MARK: - 预览
struct LaunchScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreenView()
    }
}
