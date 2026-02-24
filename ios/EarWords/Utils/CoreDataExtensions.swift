//
//  CoreDataExtensions.swift
//  EarWords
//
//  Core Data 扩展和工具方法
//

import Foundation
import CoreData

// MARK: - NSManagedObjectContext 扩展

extension NSManagedObjectContext {
    
    /// 安全地获取记录数量
    /// - Parameter fetchRequest: 获取请求
    /// - Returns: 记录数量，失败时返回 0
    func count<T: NSManagedObject>(for fetchRequest: NSFetchRequest<T>) -> Int {
        (try? self.count(for: fetchRequest)) ?? 0
    }
    
    /// 安全地获取第一条记录
    /// - Parameter fetchRequest: 获取请求
    /// - Returns: 第一条记录，失败时返回 nil
    func fetchFirst<T: NSManagedObject>(for fetchRequest: NSFetchRequest<T>) -> T? {
        let originalLimit = fetchRequest.fetchLimit
        fetchRequest.fetchLimit = 1
        defer { fetchRequest.fetchLimit = originalLimit }
        return (try? self.fetch(fetchRequest))?.first
    }
    
    /// 安全地执行获取请求
    /// - Parameter fetchRequest: 获取请求
    /// - Returns: 获取结果，失败时返回空数组
    func fetchSafe<T: NSManagedObject>(for fetchRequest: NSFetchRequest<T>) -> [T] {
        (try? self.fetch(fetchRequest)) ?? []
    }
}

// MARK: - Calendar 扩展

extension Calendar {
    
    /// 获取指定日期的日期范围（开始到结束）
    /// - Parameter date: 指定日期
    /// - Returns: (开始时间, 结束时间)
    func dayRange(for date: Date) -> (start: Date, end: Date) {
        let start = startOfDay(for: date)
        guard let end = self.date(byAdding: .day, value: 1, to: start) else {
            return (start, start)
        }
        return (start, end)
    }
    
    /// 获取昨天的日期
    var yesterday: Date? {
        date(byAdding: .day, value: -1, to: Date())
    }
    
    /// 获取明天的日期
    var tomorrow: Date? {
        date(byAdding: .day, value: 1, to: Date())
    }
    
    /// 判断两个日期是否是同一天
    /// - Parameters:
    ///   - date1: 第一个日期
    ///   - date2: 第二个日期
    /// - Returns: 是否为同一天
    func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        isDate(date1, inSameDayAs: date2)
    }
    
    /// 获取指定日期所在周的周一
    /// - Parameter date: 指定日期
    /// - Returns: 周一的日期
    func startOfWeek(for date: Date) -> Date? {
        var components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components)
    }
}

// MARK: - Date 扩展

extension Date {
    
    /// 当天的开始时间
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// 当天的结束时间
    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? self
    }
    
    /// 昨天的同一时刻
    var yesterday: Date? {
        Calendar.current.date(byAdding: .day, value: -1, to: self)
    }
    
    /// 明天的同一时刻
    var tomorrow: Date? {
        Calendar.current.date(byAdding: .day, value: 1, to: self)
    }
    
    /// 是否为今天
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// 是否为昨天
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    /// 格式化日期为字符串
    /// - Parameters:
    ///   - format: 日期格式
    ///   - locale: 区域设置
    /// - Returns: 格式化后的字符串
    func formatted(_ format: String, locale: Locale = Locale(identifier: "zh_CN")) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = locale
        return formatter.string(from: self)
    }
    
    /// 格式化日期为简短星期
    var shortWeekday: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }
    
    /// 格式化日期为月份日期
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: self)
    }
}

// MARK: - Array 扩展

extension Array {
    
    /// 安全地获取元素
    /// - Parameter index: 索引
    /// - Returns: 元素，索引越界时返回 nil
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
    
    /// 将数组分割为指定大小的批次
    /// - Parameter size: 批次大小
    /// - Returns: 批次数组
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0.. Swift.min($0 + size, count)])
        }
    }
}

// MARK: - String 扩展

extension String {
    
    /// 截取指定长度的前缀
    /// - Parameter maxLength: 最大长度
    /// - Returns: 截取后的字符串
    func truncated(to maxLength: Int, trailing: String = "...") -> String {
        if count <= maxLength { return self }
        return String(prefix(maxLength)) + trailing
    }
    
    /// 移除所有空白字符
    var removingWhitespace: String {
        replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
    }
    
    /// 转换为安全的文件名
    var safeFilename: String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}

// MARK: - Double 扩展

extension Double {
    
    /// 格式化为百分比字符串
    /// - Parameter decimals: 小数位数
    /// - Returns: 百分比字符串（如 "85.5%"）
    func percentage(decimals: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: self)) ?? "0%"
    }
    
    /// 格式化为指定小数位数的字符串
    /// - Parameter decimals: 小数位数
    /// - Returns: 格式化字符串
    func formatted(decimals: Int = 2) -> String {
        String(format: "%.*f", decimals, self)
    }
}

// MARK: - TimeInterval 扩展

extension TimeInterval {
    
    /// 格式化为 mm:ss 或 hh:mm:ss
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// 格式化为 "X分钟" 或 "X小时Y分钟"
    var formattedReadable: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// MARK: - UserDefaults 扩展

extension UserDefaults {
    
    /// 设置可编码对象
    /// - Parameters:
    ///   - object: 可编码对象
    ///   - key: 键名
    func set<T: Encodable>(_ object: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(object) {
            set(data, forKey: key)
        }
    }
    
    /// 获取可解码对象
    /// - Parameters:
    ///   - type: 对象类型
    ///   - key: 键名
    /// - Returns: 解码后的对象
    func object<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - UIColor 扩展

#if canImport(UIKit)
import UIKit

extension UIColor {
    
    /// 从十六进制字符串创建颜色
    /// - Parameter hex: 十六进制字符串（如 "#FF5733" 或 "FF5733"）
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }
        
        guard hexString.count == 6 else { return nil }
        
        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)
        
        self.init(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
    
    /// 转换为十六进制字符串
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }
}
#endif
