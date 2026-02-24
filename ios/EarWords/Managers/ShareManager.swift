//
//  ShareManager.swift
//  EarWords
//
//  分享功能管理器 - 支持生成分享卡片并分享到社交媒体
//

import SwiftUI
import UIKit

// MARK: - 分享数据模型
struct ShareData {
    let streakDays: Int
    let totalWords: Int
    let newWords: Int
    let reviewWords: Int
    let accuracy: Double
    let studyDate: Date
    
    var accuracyPercentage: Int {
        Int(accuracy * 100)
    }
    
    var shareText: String {
        var text = "📚 我在 EarWords 完成了今日学习！\n\n"
        
        if streakDays > 0 {
            text += "🔥 连续打卡 \(streakDays) 天\n"
        }
        
        text += "✅ 学习 \(totalWords) 个单词\n"
        
        if newWords > 0 {
            text += "🆕 新词 \(newWords) 个\n"
        }
        
        if reviewWords > 0 {
            text += "🔄 复习 \(reviewWords) 个\n"
        }
        
        text += "🎯 正确率 \(accuracyPercentage)%\n\n"
        text += "#EarWords #英语学习 #每日打卡"
        
        return text
    }
}

// MARK: - 分享卡片样式
enum ShareCardStyle {
    case minimal      // 简约风格
    case gradient     // 渐变风格
    case achievement  // 成就风格
    
    var backgroundGradient: [Color] {
        switch self {
        case .minimal:
            return [Color(.systemBackground), Color(.systemBackground)]
        case .gradient:
            return [Color.purple, Color.blue]
        case .achievement:
            return [Color.orange, Color.red]
        }
    }
    
    var textColor: Color {
        switch self {
        case .minimal:
            return .primary
        case .gradient, .achievement:
            return .white
        }
    }
}

// MARK: - 分享管理器
class ShareManager: ObservableObject {
    static let shared = ShareManager()
    
    @Published var currentStyle: ShareCardStyle = .gradient
    
    private init() {}
    
    // MARK: - 生成分享卡片图片
    func generateShareCard(data: ShareData, style: ShareCardStyle = .gradient) -> UIImage? {
        let cardWidth: CGFloat = 1080
        let cardHeight: CGFloat = 1920
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: cardWidth, height: cardHeight), false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        
        // 绘制背景
        let colors = style.backgroundGradient.map { $0.cgColor } as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors,
                                  locations: [0, 1])!
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: cardWidth, y: cardHeight),
                                   options: [])
        
        // 绘制装饰元素
        drawDecorations(context: context, size: CGSize(width: cardWidth, height: cardHeight), style: style)
        
        // 绘制内容
        let textColor = style.textColor
        
        // App Logo区域
        let logoY: CGFloat = 120
        drawAppLogo(at: CGPoint(x: cardWidth / 2, y: logoY), size: 80, color: textColor)
        
        // 标题
        let titleY = logoY + 100
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 56, weight: .bold),
            .foregroundColor: UIColor(textColor)
        ]
        let title = "今日学习完成！"
        let titleSize = title.size(withAttributes: titleAttributes)
        title.draw(at: CGPoint(x: (cardWidth - titleSize.width) / 2, y: titleY), withAttributes: titleAttributes)
        
        // 日期
        let dateY = titleY + 90
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年MM月dd日"
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32),
            .foregroundColor: UIColor(textColor).withAlphaComponent(0.8)
        ]
        let dateText = dateFormatter.string(from: data.studyDate)
        let dateSize = dateText.size(withAttributes: dateAttributes)
        dateText.draw(at: CGPoint(x: (cardWidth - dateSize.width) / 2, y: dateY), withAttributes: dateAttributes)
        
        // 连续打卡天数（大数字）
        let streakY = dateY + 120
        if data.streakDays > 0 {
            let streakNumberAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 160, weight: .black),
                .foregroundColor: UIColor(textColor)
            ]
            let streakNumber = "\(data.streakDays)"
            let streakNumberSize = streakNumber.size(withAttributes: streakNumberAttributes)
            streakNumber.draw(at: CGPoint(x: (cardWidth - streakNumberSize.width) / 2, y: streakY), withAttributes: streakNumberAttributes)
            
            let streakLabelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .medium),
                .foregroundColor: UIColor(textColor).withAlphaComponent(0.9)
            ]
            let streakLabel = "连续打卡天数"
            let streakLabelSize = streakLabel.size(withAttributes: streakLabelAttributes)
            streakLabel.draw(at: CGPoint(x: (cardWidth - streakLabelSize.width) / 2, y: streakY + 180), withAttributes: streakLabelAttributes)
        }
        
        // 统计数据区域
        let statsY = streakY + (data.streakDays > 0 ? 320 : 50)
        let statItemWidth: CGFloat = 280
        let startX = (cardWidth - CGFloat(3) * statItemWidth) / 2 + statItemWidth / 2
        
        // 学习总数
        drawStatItem(
            value: "\(data.totalWords)",
            label: "学习单词",
            at: CGPoint(x: startX, y: statsY),
            color: textColor
        )
        
        // 正确率
        drawStatItem(
            value: "\(data.accuracyPercentage)%",
            label: "正确率",
            at: CGPoint(x: startX + statItemWidth, y: statsY),
            color: textColor
        )
        
        // 新词/复习
        let detailY = statsY + 200
        if data.newWords > 0 || data.reviewWords > 0 {
            let detailAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36),
                .foregroundColor: UIColor(textColor).withAlphaComponent(0.85)
            ]
            
            var detailText = ""
            if data.newWords > 0 {
                detailText += "新学 \(data.newWords) 个"
            }
            if data.reviewWords > 0 {
                if !detailText.isEmpty { detailText += "   " }
                detailText += "复习 \(data.reviewWords) 个"
            }
            
            let detailSize = detailText.size(withAttributes: detailAttributes)
            detailText.draw(at: CGPoint(x: (cardWidth - detailSize.width) / 2, y: detailY), withAttributes: detailAttributes)
        }
        
        // 激励语
        let quoteY = cardHeight - 300
        let quoteAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .medium),
            .foregroundColor: UIColor(textColor).withAlphaComponent(0.9)
        ]
        let quote = getEncouragementQuote(streak: data.streakDays, accuracy: data.accuracy)
        let quoteSize = quote.size(withAttributes: quoteAttributes)
        quote.draw(at: CGPoint(x: (cardWidth - quoteSize.width) / 2, y: quoteY), withAttributes: quoteAttributes)
        
        // App 名称和Slogan
        let appY = cardHeight - 150
        let appAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 40, weight: .bold),
            .foregroundColor: UIColor(textColor)
        ]
        let appText = "EarWords"
        let appSize = appText.size(withAttributes: appAttributes)
        appText.draw(at: CGPoint(x: (cardWidth - appSize.width) / 2, y: appY), withAttributes: appAttributes)
        
        let sloganAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28),
            .foregroundColor: UIColor(textColor).withAlphaComponent(0.7)
        ]
        let slogan = "让英语学习更高效"
        let sloganSize = slogan.size(withAttributes: sloganAttributes)
        slogan.draw(at: CGPoint(x: (cardWidth - sloganSize.width) / 2, y: appY + 55), withAttributes: sloganAttributes)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    // MARK: - 绘制辅助方法
    
    private func drawDecorations(context: CGContext, size: CGSize, style: ShareCardStyle) {
        // 绘制装饰圆点
        let dotColor = CGColor(gray: 1, alpha: 0.1)
        
        for i in 0..<5 {
            let x = CGFloat.random(in: 50...size.width - 50)
            let y = CGFloat.random(in: 50...size.height - 50)
            let radius = CGFloat.random(in: 20...80)
            
            context.setFillColor(dotColor)
            context.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
        }
        
        // 绘制圆形装饰环
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.1))
        context.setLineWidth(3)
        
        let circles = [
            CGRect(x: -100, y: size.height / 2 - 200, width: 400, height: 400),
            CGRect(x: size.width - 300, y: 100, width: 300, height: 300),
            CGRect(x: size.width / 2 - 250, y: size.height - 400, width: 500, height: 500)
        ]
        
        for circle in circles {
            context.strokeEllipse(in: circle)
        }
    }
    
    private func drawAppLogo(at point: CGPoint, size: CGFloat, color: Color) {
        let rect = CGRect(x: point.x - size/2, y: point.y - size/2, width: size, height: size)
        
        // 绘制简单的耳机图标
        let context = UIGraphicsGetCurrentContext()!
        
        // 耳机头梁
        context.setStrokeColor(UIColor(color).cgColor)
        context.setLineWidth(8)
        context.setLineCap(.round)
        
        let headbandPath = UIBezierPath()
        headbandPath.move(to: CGPoint(x: rect.minX + 20, y: rect.midY))
        headbandPath.addQuadCurve(to: CGPoint(x: rect.maxX - 20, y: rect.midY),
                                  controlPoint: CGPoint(x: rect.midX, y: rect.minY - 20))
        headbandPath.stroke()
        
        // 左耳罩
        let leftEarPath = UIBezierPath(roundedRect: CGRect(x: rect.minX, y: rect.midY - 15, width: 25, height: 50),
                                       cornerRadius: 12)
        UIColor(color).setFill()
        leftEarPath.fill()
        
        // 右耳罩
        let rightEarPath = UIBezierPath(roundedRect: CGRect(x: rect.maxX - 25, y: rect.midY - 15, width: 25, height: 50),
                                        cornerRadius: 12)
        rightEarPath.fill()
    }
    
    private func drawStatItem(value: String, label: String, at point: CGPoint, color: Color) {
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 72, weight: .bold),
            .foregroundColor: UIColor(color)
        ]
        let valueSize = value.size(withAttributes: valueAttributes)
        value.draw(at: CGPoint(x: point.x - valueSize.width / 2, y: point.y), withAttributes: valueAttributes)
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28),
            .foregroundColor: UIColor(color).withAlphaComponent(0.8)
        ]
        let labelSize = label.size(withAttributes: labelAttributes)
        label.draw(at: CGPoint(x: point.x - labelSize.width / 2, y: point.y + 90), withAttributes: labelAttributes)
    }
    
    private func getEncouragementQuote(streak: Int, accuracy: Double) -> String {
        if streak >= 30 {
            return "坚持一个月，你真的很棒！"
        } else if streak >= 7 {
            return "一周打卡完成，继续保持！"
        } else if streak >= 3 {
            return "连续打卡中，好习惯养成中！"
        } else if accuracy >= 0.9 {
            return "准确率超高，记忆力惊人！"
        } else if accuracy >= 0.7 {
            return "今天学得很不错！"
        } else {
            return "每一天都在进步！"
        }
    }
    
    // MARK: - 分享功能
    
    /// 生成分享活动项
    func createShareActivityItems(data: ShareData) -> [Any] {
        var items: [Any] = []
        
        // 文字内容
        items.append(data.shareText)
        
        // 图片
        if let image = generateShareCard(data: data, style: currentStyle) {
            items.append(image)
        }
        
        // URL（如果有的话）
        if let url = URL(string: "https://earwords.app") {
            items.append(url)
        }
        
        return items
    }
    
    /// 显示分享界面
    func presentShareSheet(data: ShareData, from viewController: UIViewController) {
        let items = createShareActivityItems(data: data)
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // 排除一些不需要的分享选项
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks,
            .saveToCameraRoll
        ]
        
        // iPad适配
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityVC, animated: true)
    }
}

// MARK: - SwiftUI分享视图
struct ShareCardView: View {
    let data: ShareData
    @State private var selectedStyle: ShareCardStyle = .gradient
    @State private var renderedImage: UIImage?
    @State private var showShareSheet = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 样式选择
                    Picker("卡片样式", selection: $selectedStyle) {
                        Text("渐变").tag(ShareCardStyle.gradient)
                        Text("简约").tag(ShareCardStyle.minimal)
                        Text("成就").tag(ShareCardStyle.achievement)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedStyle) { _ in
                        renderCard()
                    }
                    
                    // 预览
                    if let image = renderedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                            .padding(.horizontal)
                    } else {
                        // 占位符
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(9/16, contentMode: .fit)
                            .overlay(ProgressView())
                            .padding(.horizontal)
                    }
                    
                    // 分享按钮
                    Button(action: shareCard) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("分享成绩")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ThemeManager.shared.primary)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // 复制文本按钮
                    Button(action: copyText) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("复制分享文字")
                        }
                        .font(.subheadline)
                        .foregroundColor(ThemeManager.shared.primary)
                        .padding()
                    }
                    
                    Spacer()
                }
                .padding(.vertical)
            }
            .navigationTitle("分享成绩")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        // dismiss
                    }
                }
            }
            .onAppear {
                renderCard()
            }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderedImage {
                    ShareSheet(activityItems: [data.shareText, image])
                }
            }
        }
    }
    
    private func renderCard() {
        DispatchQueue.global(qos: .userInitiated).async {
            let image = ShareManager.shared.generateShareCard(data: data, style: selectedStyle)
            DispatchQueue.main.async {
                self.renderedImage = image
            }
        }
    }
    
    private func shareCard() {
        showShareSheet = true
    }
    
    private func copyText() {
        UIPasteboard.general.string = data.shareText
        // 显示提示
    }
}

// MARK: - UIActivityViewController包装
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 分享按钮修饰符
extension View {
    func shareButton(data: ShareData) -> some View {
        self.overlay(
            ShareButtonOverlay(data: data)
        )
    }
}

struct ShareButtonOverlay: View {
    let data: ShareData
    @State private var showShareSheet = false
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(ThemeManager.shared.primary)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareCardView(data: data)
        }
    }
}

// MARK: - 预览
struct ShareCardView_Previews: PreviewProvider {
    static var sampleData = ShareData(
        streakDays: 7,
        totalWords: 25,
        newWords: 10,
        reviewWords: 15,
        accuracy: 0.88,
        studyDate: Date()
    )
    
    static var previews: some View {
        ShareCardView(data: sampleData)
    }
}
