import Foundation

/// Định dạng ngày giờ kiểu Việt Nam.
enum VN {
    static let locale = Locale(identifier: "vi_VN")

    /// Lịch tuần bắt đầu từ Thứ Hai.
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = locale
        c.timeZone = .current
        c.firstWeekday = 2
        return c
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "HH:mm"
        return f
    }()

    static func time(_ d: Date) -> String { timeFormatter.string(from: d) }

    static func weekdayName(_ d: Date) -> String {
        switch Calendar.current.component(.weekday, from: d) {
        case 1: return "Chủ Nhật"
        case 2: return "Thứ Hai"
        case 3: return "Thứ Ba"
        case 4: return "Thứ Tư"
        case 5: return "Thứ Năm"
        case 6: return "Thứ Sáu"
        default: return "Thứ Bảy"
        }
    }

    static func weekdayShort(_ d: Date) -> String {
        let w = Calendar.current.component(.weekday, from: d)
        return w == 1 ? "CN" : "T\(w)"
    }

    /// "Thứ Hai, 17/11"
    static func dayTitle(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.day, .month], from: d)
        return "\(weekdayName(d)), \(c.day ?? 1)/\(c.month ?? 1)"
    }

    /// "17/11/2026"
    static func shortDate(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.day, .month, .year], from: d)
        return "\(c.day ?? 1)/\(c.month ?? 1)/\(c.year ?? 2000)"
    }

    /// "Tháng 11, 2026"
    static func monthTitle(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .year], from: d)
        return "Tháng \(c.month ?? 1), \(c.year ?? 2000)"
    }

    /// "Hôm nay", "Ngày mai", "Hôm qua" hoặc tên ngày.
    static func relativeDay(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Hôm nay" }
        if cal.isDateInTomorrow(d) { return "Ngày mai" }
        if cal.isDateInYesterday(d) { return "Hôm qua" }
        return dayTitle(d)
    }
}
