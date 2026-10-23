import AppKit
import DuckCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let timings = Timings.from(environment: ProcessInfo.processInfo.environment)
let fast = timings.workHours == nil
let controller = DuckController(timings: timings)
controller.applySettings()
let statusMenu = StatusMenu(controller: controller, fast: fast)
controller.start()
app.run()
