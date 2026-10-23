import AppKit
import DuckCore

/// A see-through panel that never takes focus. The controller turns mouse events on only while
/// the cursor is over the duck or its bubble, so the rest of the panel never blocks clicks.
final class DuckPanel: NSPanel {
    var onClick: (() -> Void)?
    /// The drawn duck and bubble, in window coordinates.
    var hitRegions: [CGRect] = []

    func hits(_ point: NSPoint) -> Bool {
        hitRegions.contains { $0.contains(point) }
    }

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: Layout.panel),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            if hits(event.locationInWindow) { onClick?() }
            return
        }
        super.sendEvent(event)
    }
}
