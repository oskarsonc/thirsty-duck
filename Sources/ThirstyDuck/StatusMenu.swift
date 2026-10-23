import AppKit
import DuckCore
import ServiceManagement

@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Open at login", action: #selector(toggleLogin), keyEquivalent: "")
    private let reminderMenu = NSMenu()
    private let startMenu = NSMenu()
    private let endMenu = NSMenu()
    private let weekendsItem = NSMenuItem(title: "Weekends", action: #selector(toggleWeekends), keyEquivalent: "")
    private let screenItem = NSMenuItem(title: "Show on", action: nil, keyEquivalent: "")
    private let screenMenu = NSMenu()
    private let controller: DuckController

    init(controller: DuckController, fast: Bool) {
        self.controller = controller
        super.init()
        item.button?.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Thirsty Duck")
        let menu = NSMenu()
        menu.delegate = self
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(withTitle: "Call the duck now", action: #selector(call), keyEquivalent: "").target = self
        menu.addItem(.separator())
        if !fast {
            menu.addItem(submenu("Remind every", reminderMenu, Settings.reminderChoices, #selector(pickReminder)) { "\($0) min" })
            let hoursMenu = NSMenu()
            hoursMenu.addItem(submenu("Starts at", startMenu, Settings.startChoices, #selector(pickStart), title: Self.clock))
            hoursMenu.addItem(submenu("Ends at", endMenu, Settings.endChoices, #selector(pickEnd), title: Self.clock))
            weekendsItem.target = self
            hoursMenu.addItem(weekendsItem)
            let hoursItem = NSMenuItem(title: "Active hours", action: nil, keyEquivalent: "")
            hoursItem.submenu = hoursMenu
            menu.addItem(hoursItem)
        }
        screenItem.submenu = screenMenu
        menu.addItem(screenItem)
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q").target = NSApp
        item.menu = menu
    }

    private func submenu(_ name: String, _ menu: NSMenu, _ choices: [Int], _ action: Selector, title: (Int) -> String) -> NSMenuItem {
        for value in choices {
            let choice = menu.addItem(withTitle: title(value), action: action, keyEquivalent: "")
            choice.target = self
            choice.tag = value
        }
        let item = NSMenuItem(title: name, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private static func clock(_ hour: Int) -> String { String(format: "%02d:00", hour) }

    func menuNeedsUpdate(_ menu: NSMenu) {
        statusLine.title = statusText(controller.status)
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        for (submenu, value) in [(reminderMenu, Settings.reminderMinutes), (startMenu, Settings.startHour), (endMenu, Settings.endHour)] {
            for choice in submenu.items { choice.state = choice.tag == value ? .on : .off }
        }
        weekendsItem.state = Settings.weekends ? .on : .off

        let screens = NSScreen.screens
        screenItem.isHidden = screens.count < 2
        screenMenu.removeAllItems()
        let ids = screens.map(\.displayID)
        let picked = Settings.screenID.flatMap { ids.contains($0) ? $0 : nil } ?? ids.first ?? nil
        for (i, screen) in screens.enumerated() {
            // Two screens of the same model have the same name, so number them.
            var title = screen.localizedName
            if screens.filter({ $0.localizedName == title }).count > 1 { title += " \(screens[..<i].filter { $0.localizedName == title }.count + 1)" }
            if i == 0 { title += " (main)" }
            let choice = screenMenu.addItem(withTitle: title, action: #selector(pickScreen), keyEquivalent: "")
            choice.target = self
            choice.representedObject = i == 0 ? nil : ids[i].map { NSNumber(value: $0) }
            choice.state = ids[i] == picked ? .on : .off
        }
    }

    private func statusText(_ status: DuckStatus) -> String {
        switch status {
        case .here:
            return "The duck is here 🦆"
        case .nextIn(let seconds):
            return "Next duck in \(max(1, Int((seconds / 60).rounded(.up)))) min"
        case .offUntil(let date):
            guard let date else { return "Off" }
            let format = Calendar.current.isDateInToday(date) || Calendar.current.isDateInTomorrow(date) ? "HH:mm" : "EEE HH:mm"
            let formatter = DateFormatter()
            formatter.dateFormat = format
            return "Off until \(formatter.string(from: date))"
        }
    }

    @objc private func call() { controller.callNow() }

    @objc private func pickReminder(_ sender: NSMenuItem) {
        Settings.reminderMinutes = sender.tag
        controller.applySettings()
    }

    @objc private func pickStart(_ sender: NSMenuItem) {
        Settings.startHour = sender.tag
        controller.applySettings()
    }

    @objc private func pickEnd(_ sender: NSMenuItem) {
        Settings.endHour = sender.tag
        controller.applySettings()
    }

    @objc private func toggleWeekends() {
        Settings.weekends.toggle()
        controller.applySettings()
    }

    @objc private func pickScreen(_ sender: NSMenuItem) {
        Settings.screenID = (sender.representedObject as? NSNumber)?.uint32Value
        controller.screenChoiceChanged()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Open at login failed: \(error.localizedDescription)")
        }
    }
}
