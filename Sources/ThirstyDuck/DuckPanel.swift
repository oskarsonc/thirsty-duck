import AppKit

/// A see-through panel that never takes focus. The controller turns mouse events on only while
/// the cursor is over the duck or its bubble, so the rest of the panel never blocks clicks.
final class DuckPanel: NSPanel {
    var onClick: (() -> Void)?

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: DuckView.size),
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
            onClick?()
            return
        }
        super.sendEvent(event)
    }
}
