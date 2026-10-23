import AppKit
import DuckCore
import SwiftUI

/// Reads the system, steps the duck, and shows it. Ticks at 60 Hz while the duck is up, else once a second.
@MainActor
final class DuckController {
    private var duck: Duck
    private let time: any TimeSource
    private let panel = DuckPanel()
    private let host: NSHostingView<DuckView>
    private var timer: Timer?
    private var timerIsFast = false
    private var bubble: Bubble?
    private var bubbleSince = Date.distantPast

    init(timings: Timings, time: any TimeSource = SystemTime()) {
        duck = Duck(timings: timings)
        self.time = time
        host = NSHostingView(rootView: DuckView(duck: duck, now: time.now, bubble: nil, bubbleSince: .distantPast))
        host.frame = NSRect(origin: .zero, size: DuckView.size)
        panel.contentView = host
        panel.onClick = { [weak self] in self?.send(.click) }
        let center = NSWorkspace.shared.notificationCenter
        for (name, input) in [(NSWorkspace.willSleepNotification, DuckInput.sleep), (NSWorkspace.didWakeNotification, .wake)] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.send(input) }
            }
        }
    }

    func start() { send(.tick) }

    func callNow() { send(.callNow) }

    private func send(_ input: DuckInput) {
        let now = time.now
        let sensors = Self.readSensors()
        duck.step(now: now, sensors: sensors, input: input)
        render(now, mouse: sensors.mouse)
        if timer == nil || duck.isVisible != timerIsFast { schedule(fast: duck.isVisible) }
    }

    private func schedule(fast: Bool) {
        timer?.invalidate()
        let t = Timer(timeInterval: fast ? 1.0 / 60 : 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.send(.tick) }
        }
        t.tolerance = fast ? 0 : 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
        timerIsFast = fast
    }

    private func render(_ now: Date, mouse: CGPoint) {
        guard duck.isVisible else {
            if panel.isVisible { panel.orderOut(nil) }
            return
        }
        let b = duck.bubble(at: now)
        if b != bubble {
            bubble = b
            bubbleSince = now
        }
        host.rootView = DuckView(duck: duck, now: now, bubble: b, bubbleSince: bubbleSince)

        let p = duck.position
        let origin = NSPoint(x: (p.x - DuckView.size.width / 2).rounded(), y: (p.y - DuckView.ground).rounded())
        if panel.frame.origin != origin { panel.setFrameOrigin(origin) }

        let hit = hitRect(origin: origin, withBubble: b != nil)
        if panel.ignoresMouseEvents == hit.contains(mouse) { panel.ignoresMouseEvents.toggle() }
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    private func hitRect(origin: NSPoint, withBubble: Bool) -> NSRect {
        let s = DuckView.size
        let sprite = NSRect(x: origin.x + (s.width - Sprite.size.width) / 2, y: origin.y + DuckView.ground,
                            width: Sprite.size.width, height: Sprite.size.height + 14)
        guard withBubble else { return sprite }
        let bubble = NSRect(x: origin.x + s.width / 2 - 80, y: sprite.minY + Sprite.size.height + DuckView.bubbleGap,
                            width: 160, height: 36)
        return sprite.union(bubble)
    }

    private static func readSensors() -> Sensors {
        Sensors(
            idleSeconds: CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!),
            mouse: NSEvent.mouseLocation,
            screens: NSScreen.screens.map { Screen(frame: $0.frame, visible: $0.visibleFrame) }
        )
    }
}
