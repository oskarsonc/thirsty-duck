import AppKit
import DuckCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = DuckController(timings: .from(environment: ProcessInfo.processInfo.environment))
let statusMenu = StatusMenu(onCall: { controller.callNow() })
controller.start()
app.run()
