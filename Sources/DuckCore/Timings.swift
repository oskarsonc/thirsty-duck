import CoreGraphics
import Foundation

public struct WorkHours: Sendable {
    /// Calendar weekdays, 1 is Sunday.
    public var weekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
    public var startHour = 8
    public var endHour = 23
    public var calendar = Calendar.current

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func contains(_ date: Date) -> Bool {
        let parts = calendar.dateComponents([.weekday, .hour], from: date)
        guard let weekday = parts.weekday, let hour = parts.hour else { return false }
        return weekdays.contains(weekday) && (startHour..<endHour).contains(hour)
    }

    /// The next time the hours start, within a week.
    public func nextStart(after date: Date) -> Date? {
        let today = calendar.startOfDay(for: date)
        for day in 0...7 {
            // Set the clock hour on the day, so a daylight saving change does not shift it.
            guard let day = calendar.date(byAdding: .day, value: day, to: today),
                  let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: day),
                  start > date, weekdays.contains(calendar.component(.weekday, from: start)) else { continue }
            return start
        }
        return nil
    }
}

public struct Timings: Sendable {
    public var reminderInterval: TimeInterval
    public var levelStep: TimeInterval
    public var awayAfter: TimeInterval
    public var longBreak: TimeInterval
    /// `nil` means always work time.
    public var workHours: WorkHours?

    public static let normal = Timings(
        reminderInterval: 30 * 60,
        levelStep: 5 * 60,
        awayAfter: 5 * 60,
        longBreak: 30 * 60,
        workHours: WorkHours()
    )

    /// For a demo: a short wait, then long enough on each level to watch it.
    public static let fast = Timings(
        reminderInterval: 10,
        levelStep: 20,
        awayAfter: 10,
        longBreak: 30,
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
    /// Level 2 walks this far toward the middle, so it stays clear of a bottom Dock.
    public static let askWalk: CGFloat = 300
    public static let offscreen: CGFloat = 50
    public static let followGap: CGFloat = 60
    public static let followDrop: CGFloat = 35
    public static let followSlack: CGFloat = 30
    /// A waiting follow duck walks again only when the cursor is farther than this from its feet.
    public static let followLeash: CGFloat = 120
    public static let happyDuration: TimeInterval = 1.3
    public static let bubblePop: TimeInterval = 0.7
    public static let chillBubbleCycle: TimeInterval = 9
    public static let chillBubbleShown: Range<TimeInterval> = 2..<5
}
