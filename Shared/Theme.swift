import SwiftUI

extension TaskColor {
    var color: Color {
        switch self {
        case .blue: return .blue
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .teal: return .teal
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .gray: return .gray
        }
    }

    static func from(_ raw: String) -> TaskColor { TaskColor(rawValue: raw) ?? .blue }
}

extension EventSnapshot {
    var color: Color { Color(red: red, green: green, blue: blue) }

    var timeText: String {
        isAllDay ? "Cả ngày" : VN.time(start)
    }
}
