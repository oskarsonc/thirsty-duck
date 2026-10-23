import AppKit
import DuckCore
import SwiftUI

/// Reads the system, steps the duck, and shows it. The duck decides how often it needs a tick.
@MainActor
final class DuckController {
    private var duck: Duck
    private let time: any TimeSource
    private let panel = DuckPanel()
    private let host: NSHostingView<DuckView>
    private var timer: Timer?
    private var rate: Double = 0
    private var frame: Frame?
    private var screens = DuckController.readScreens()
    private var bubbleSizes: [String: CGSize] = [:]
    private let debug = ProcessInfo.processInfo.environment["DUCK_DEBUG"] == "1"
    private var logged: (phase: DuckPhase, rate: Double, at: Date, redraws: Int)?
    private var redraws = 0
    private var pointerMonitors: [Any] = []

    init(timings: Timings, time: any TimeSource = SystemTime()) {
        duck = Duck(timings: timings)
        self.time = time
        host = NSHostingView(rootView: DuckView(frame: duck.frame(at: time.now)))
        host.frame = NSRect(origin: .zero, size: Layout.panel)
        panel.contentView = host
        panel.onClick = { [weak self] in self?.send(.click) }
        let center = NSWorkspace.shared.notificationCenter
        for (name, input) in [(NSWorkspace.willSleepNotification, DuckInput.sleep), (NSWorkspace.didWakeNotification, .wake)] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.send(input) }
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screens = DuckController.readScreens() }
        }
    }

    func start() { send(.tick) }

    func callNow() { send(.callNow) }

    /// Fast mode keeps its own short times.
    func setReminderMinutes(_ minutes: Int) {
        guard duck.timings.workHours != nil else { return }
        duck.timings.reminderInterval = TimeInterval(minutes * 60)
        send(.tick)
    }

    func screenChoiceChanged() { screens = DuckController.readScreens() }

    private func send(_ input: DuckInput) {
        let now = time.now
        let mouse = NSEvent.mouseLocation
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        duck.step(now: now, sensors: Sensors(idleSeconds: idle, mouse: mouse, screens: screens), input: input)
        render(now, mouse: mouse)
        let wanted = duck.tickRate(at: now)
        if debug { log(now, wanted) }
        if wanted != rate { schedule(wanted) }
    }

    private func schedule(_ rate: Double) {
        timer?.invalidate()
        let t = Timer(timeInterval: 1 / rate, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.send(.tick) }
        }
        t.tolerance = 0.1 / rate
        RunLoop.main.add(t, forMode: .common)
        timer = t
        self.rate = rate
    }

    private func render(_ now: Date, mouse: CGPoint) {
        guard duck.isVisible else {
            if panel.isVisible {
                panel.orderOut(nil)
                pointerMonitors.forEach(NSEvent.removeMonitor)
                pointerMonitors = []
            }
            frame = nil
            return
        }
        let f = duck.frame(at: now)
        if f != frame {
            frame = f
            host.rootView = DuckView(frame: f)
            redraws += 1
        }

        let p = duck.position
        let origin = NSPoint(x: (p.x - Layout.panel.width / 2).rounded(), y: (p.y - Layout.ground).rounded())
        if panel.frame.origin != origin { panel.setFrameOrigin(origin) }

        panel.hitRegions = Layout.hitRegions(f, bubble: f.bubble.map { bubbleSize($0.text) })
        routeClicks(mouse)
        if !panel.isVisible {
            panel.orderFrontRegardless()
            watchPointer()
        }
    }

    /// The panel takes mouse events only while the cursor is on the duck or its bubble.
    private func routeClicks(_ mouse: CGPoint) {
        let o = panel.frame.origin
        let over = panel.hits(NSPoint(x: mouse.x - o.x, y: mouse.y - o.y))
        if panel.ignoresMouseEvents == over { panel.ignoresMouseEvents = !over }
    }

    /// Ticks can be 0.5 s apart, so the cursor also routes clicks as it moves.
    private func watchPointer() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        let route = { [weak self] in self?.routeClicks(NSEvent.mouseLocation) }
        pointerMonitors = [
            NSEvent.addGlobalMonitorForEvents(matching: mask) { _ in MainActor.assumeIsolated { route() } },
            NSEvent.addLocalMonitorForEvents(matching: mask) { event in
                MainActor.assumeIsolated { route() }
                return event
            },
        ].compactMap { $0 }
    }

    /// `DUCK_DEBUG=1` prints each phase or rate change, with the redraws per second since the last line.
    private func log(_ now: Date, _ wanted: Double) {
        if let l = logged, l.phase == duck.phase, l.rate == wanted { return }
        let perSecond = logged.map { Double(redraws - $0.redraws) / max(now.timeIntervalSince($0.at), 0.001) } ?? 0
        FileHandle.standardError.write(Data(String(format: "%.1f %@ %g Hz (%.1f redraws/s before)\n",
                                                   now.timeIntervalSince1970, "\(duck.phase)", wanted, perSecond).utf8))
        logged = (duck.phase, wanted, now, redraws)
    }

    private func bubbleSize(_ text: String) -> CGSize {
        if let size = bubbleSizes[text] { return size }
        let measured = (text as NSString).size(withAttributes: [.font: Self.bubbleFont])
        let size = Layout.bubbleSize(text: CGSize(width: measured.width.rounded(.up), height: measured.height.rounded(.up)))
        bubbleSizes[text] = size
        return size
    }

    /// Matches the bubble font in `DuckView`.
    private static let bubbleFont: NSFont = {
        let bold = NSFont.systemFont(ofSize: 13, weight: .bold)
        return bold.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 13) } ?? bold
    }()

    /// The picked screen goes first, so the duck comes in there. If it is not connected, the main screen stays first.
    private static func readScreens() -> [Screen] {
        var all = NSScreen.screens
        if let i = all.firstIndex(where: { $0.localizedName == Settings.screenName }) { all.insert(all.remove(at: i), at: 0) }
        return all.map { Screen(frame: $0.frame, visible: $0.visibleFrame) }
    }
}
