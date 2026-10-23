import Foundation

/// The two choices the menu saves.
enum Settings {
    private static var defaults: UserDefaults { .standard }

    static let reminderChoices = [20, 30, 45, 60]

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
}
