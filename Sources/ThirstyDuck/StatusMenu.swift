import AppKit
import ServiceManagement

@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let loginItem = NSMenuItem(title: "Open at login", action: #selector(toggleLogin), keyEquivalent: "")
    private let onCall: () -> Void

    init(onCall: @escaping () -> Void) {
        self.onCall = onCall
        super.init()
        item.button?.image = NSImage(systemSymbolName: "drop.fill", accessibilityDescription: "Thirsty Duck")
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Call the duck now", action: #selector(call), keyEquivalent: "").target = self
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q").target = NSApp
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func call() { onCall() }

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
