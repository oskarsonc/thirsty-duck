import DuckCore
import Foundation

/// The choices the menu saves.
enum Settings {
    private static var defaults: UserDefaults { .standard }

    static let reminderChoices = [20, 30, 45, 60]
    static let startChoices = Array(6...12)
    static let endChoices = Array(16...24)
    static let stretchChoices = Array(stride(from: 10 * 60, through: 16 * 60, by: 30))

    /// Minutes of computer use before the duck comes.
    static var reminderMinutes: Int {
        get { reminderChoices.contains(defaults.integer(forKey: "reminderMinutes")) ? defaults.integer(forKey: "reminderMinutes") : 30 }
        set { defaults.set(newValue, forKey: "reminderMinutes") }
    }

    /// The display ID of the screen the duck comes in on. `nil` means the main screen.
    static var screenID: UInt32? {
        get { (defaults.object(forKey: "screenID") as? NSNumber)?.uint32Value }
        set { defaults.set(newValue.map { NSNumber(value: $0) }, forKey: "screenID") }
    }

    static var startHour: Int {
        get { startChoices.contains(defaults.integer(forKey: "startHour")) ? defaults.integer(forKey: "startHour") : 8 }
        set { defaults.set(newValue, forKey: "startHour") }
    }

    /// 24 means midnight.
    static var endHour: Int {
        get { endChoices.contains(defaults.integer(forKey: "endHour")) ? defaults.integer(forKey: "endHour") : 23 }
        set { defaults.set(newValue, forKey: "endHour") }
    }

    static var weekends: Bool {
        get { defaults.object(forKey: "weekends") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "weekends") }
    }

    /// Minutes after midnight of the daily stretch. `nil` is Off, which is saved as -1 so it differs from no choice yet.
    static var stretchMinutes: Int? {
        get {
            guard let value = defaults.object(forKey: "stretchMinutes") as? Int else { return 12 * 60 }
            if value == -1 { return nil }
            return stretchChoices.contains(value) ? value : 12 * 60
        }
        set { defaults.set(newValue ?? -1, forKey: "stretchMinutes") }
    }

    /// Calendar day (yyyy-MM-dd) of the last stretch click, kept across restarts and time zone changes.
    static var stretchDoneDay: String? {
        get { defaults.object(forKey: "stretchDoneDay") as? String }
        set { defaults.set(newValue, forKey: "stretchDoneDay") }
    }

    static var workHours: WorkHours {
        var hours = WorkHours(calendar: .autoupdatingCurrent)
        hours.startHour = startHour
        hours.endHour = endHour
        hours.weekdays = weekends ? Set(1...7) : Set(2...6)
        return hours
    }
}
