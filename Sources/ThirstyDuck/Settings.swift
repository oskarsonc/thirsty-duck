import DuckCore
import Foundation

/// The choices the menu saves.
enum Settings {
    private static var defaults: UserDefaults { .standard }

    static let reminderChoices = [20, 30, 45, 60]
    static let startChoices = Array(6...12)
    static let endChoices = Array(16...24)

    /// Minutes of computer use before the duck comes.
    static var reminderMinutes: Int {
        get { reminderChoices.contains(defaults.integer(forKey: "reminderMinutes")) ? defaults.integer(forKey: "reminderMinutes") : 30 }
        set { defaults.set(newValue, forKey: "reminderMinutes") }
    }

    /// The name of the screen the duck comes in on. `nil` means the main screen.
    static var screenName: String? {
        get { defaults.string(forKey: "screenName") }
        set { defaults.set(newValue, forKey: "screenName") }
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

    static var workHours: WorkHours {
        var hours = WorkHours()
        hours.startHour = startHour
        hours.endHour = endHour
        hours.weekdays = weekends ? Set(1...7) : Set(2...6)
        return hours
    }
}
