import CoreGraphics
import Foundation

public struct WorkHours: Sendable {
    /// Calendar weekdays, 1 is Sunday.
    public var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    public var startHour = 8
    public var endHour = 18
    public var calendar = Calendar.current

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func contains(_ date: Date) -> Bool {
        let parts = calendar.dateComponents([.weekday, .hour], from: date)
        guard let weekday = parts.weekday, let hour = parts.hour else { return false }
        return weekdays.contains(weekday) && (startHour..<endHour).contains(hour)
    }
}

public struct Timings: Sendable {
    public var reminderInterval: TimeInterval
    public var levelStep: TimeInterval
    public var awayAfter: TimeInterval
    public var longBreak: TimeInterval
    /// `nil` means always work time.
    public var workHours: WorkHours?
    /// A wall-clock gap this long between two ticks means the Mac slept.
    public var sleepGap: TimeInterval = 60

    public static let normal = Timings(
        reminderInterval: 45 * 60,
        levelStep: 5 * 60,
        awayAfter: 5 * 60,
        longBreak: 30 * 60,
        workHours: WorkHours()
    )

    public static let fast = Timings(
        reminderInterval: normal.reminderInterval / 60,
        levelStep: normal.levelStep / 60,
        awayAfter: normal.awayAfter / 60,
        longBreak: normal.longBreak / 60,
        workHours: nil
    )

    public static func from(environment: [String: String]) -> Timings {
        environment["DUCK_FAST"] == "1" ? .fast : .normal
    }
}

/// Speeds and distances in points, durations in seconds.
public enum Motion {
    public static let walkSpeed: CGFloat = 70
    public static let leaveSpeed: CGFloat = 90
    public static let followSpeed: CGFloat = 220
    public static let strollSpeed: CGFloat = 40
    public static let homeInset: CGFloat = 140
    public static let halfWidth: CGFloat = 40
    public static let offscreen: CGFloat = 50
    public static let followGap: CGFloat = 60
    public static let followDrop: CGFloat = 35
    public static let followSlack: CGFloat = 30
    public static let happyDuration: TimeInterval = 1.3
    public static let chillBubbleCycle: TimeInterval = 9
    public static let chillBubbleShown: Range<TimeInterval> = 2..<5
}
