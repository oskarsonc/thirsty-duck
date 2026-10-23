import AppKit
import ServiceManagement

@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let loginItem = NSMenuItem(title: "Open at login", action: #selector(toggleLogin), keyEquivalent: "")
    private let reminderMenu = NSMenu()
    private let screenItem = NSMenuItem(title: "Show on", action: nil, keyEquivalent: "")
    private let screenMenu = NSMenu()
    private let controller: DuckController

    init(controller: DuckController, fast: Bool) {
        self.controller = controller
        super.init()
        item.button?.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Thirsty Duck")
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Call the duck now", action: #selector(call), keyEquivalent: "").target = self
        menu.addItem(.separator())
        if !fast {
            for minutes in Settings.reminderChoices {
                let choice = reminderMenu.addItem(withTitle: "\(minutes) min", action: #selector(pickReminder), keyEquivalent: "")
                choice.target = self
                choice.tag = minutes
            }
            let reminderItem = NSMenuItem(title: "Remind every", action: nil, keyEquivalent: "")
            reminderItem.submenu = reminderMenu
            menu.addItem(reminderItem)
        }
        screenItem.submenu = screenMenu
        menu.addItem(screenItem)
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q").target = NSApp
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        for choice in reminderMenu.items { choice.state = choice.tag == Settings.reminderMinutes ? .on : .off }

        let names = NSScreen.screens.map(\.localizedName)
        screenItem.isHidden = names.count < 2
        screenMenu.removeAllItems()
        let picked = Settings.screenName.flatMap { names.contains($0) ? $0 : nil }
        for (i, name) in names.enumerated() {
            let choice = screenMenu.addItem(withTitle: i == 0 ? "\(name) (main)" : name, action: #selector(pickScreen), keyEquivalent: "")
            choice.target = self
            choice.representedObject = i == 0 ? nil : name
            choice.state = (picked ?? names[0]) == name ? .on : .off
        }
    }

    @objc private func call() { controller.callNow() }

    @objc private func pickReminder(_ sender: NSMenuItem) {
        Settings.reminderMinutes = sender.tag
        controller.setReminderMinutes(sender.tag)
    }

    @objc private func pickScreen(_ sender: NSMenuItem) {
        Settings.screenName = sender.representedObject as? String
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
