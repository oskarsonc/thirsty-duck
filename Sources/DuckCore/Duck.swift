import CoreGraphics
import Foundation

/// The whole duck. The app sends inputs to `step` and only reads the rest.
public struct Duck: Sendable {
    public let timings: Timings
    public private(set) var phase: DuckPhase = .hidden
    public private(set) var phaseStart: Date = .distantPast
    public private(set) var shownAt: Date = .distantPast
    /// Counted work time since the last reset. It drives both the reminder and the thirst level.
    public private(set) var workTime: TimeInterval = 0
    /// Bottom center of the duck, in global AppKit coordinates.
    public private(set) var position: CGPoint = .zero
    public private(set) var facingRight = true
    public private(set) var bubble: Bubble?
    public private(set) var bubbleSince: Date = .distantPast

    private var stage: CGRect = .zero
    private var home: CGPoint = .zero
    private var exitX: CGFloat = 0
    private var nextTrickAt: Date = .distantPast
    private var lastTrick: Trick?
    private var lastTick: Date?
    /// The last real user input. Every break is measured from it.
    private var lastInput: Date = .distantPast
    private var wokeAt: Date = .distantPast
    private var macAsleep = false
    private var wasWorkHours: Bool?
    private var rng: SplitMix64

    public init(timings: Timings, seed: UInt64 = .random(in: 0...UInt64.max)) {
        self.timings = timings
        rng = SplitMix64(state: seed)
    }

    public var isVisible: Bool { phase != .hidden }

    public var level: Thirst {
        let over = workTime - timings.reminderInterval
        guard over > 0 else { return .chill }
        return Thirst(rawValue: min(Thirst.follow.rawValue, 1 + Int(over / timings.levelStep)))!
    }

    public var isWalking: Bool {
        switch phase {
        case .entering, .moving, .leaving, .waiting(_, .stroll?): true
        default: false
        }
    }

    private func bubble(at now: Date) -> Bubble? {
        switch phase {
        case .entering(let t), .moving(let t), .waiting(let t, _):
            switch t {
            case .chill:
                let t = now.timeIntervalSince(shownAt).truncatingRemainder(dividingBy: Motion.chillBubbleCycle)
                return Motion.chillBubbleShown.contains(t) ? Bubble(text: "💧?", alarm: false) : nil
            case .ask: return Bubble(text: "drink! 💧", alarm: false)
            case .thirsty: return Bubble(text: "so thirsty… 💧💧", alarm: true)
            case .follow: return Bubble(text: "DRINK WATER! 🥵", alarm: false)
            }
        case .happy: return Bubble(text: "thank you! 💛", alarm: false)
        case .hidden, .asleep, .leaving: return nil
        }
    }

    public mutating func step(now: Date, sensors: Sensors, input: DuckInput = .tick) {
        switch input {
        case .tick: tick(now, sensors)
        case .click: click(now)
        case .callNow: callNow(now, sensors)
        case .sleep:
            tick(now, sensors)
            macAsleep = true
        case .wake:
            macAsleep = false
            lastTick = now
            wokeAt = now
            tick(now, sensors)
        }
        let b = bubble(at: now)
        if b != bubble {
            bubble = b
            bubbleSince = now
        }
    }

    /// The idle counter can read as fresh input right after a wake, from the wake itself.
    static let wakeGrace: TimeInterval = 5

    private mutating func click(_ now: Date) {
        switch phase {
        case .entering, .waiting, .moving, .asleep:
            workTime = 0
            lastInput = now
            set(.happy, now)
        case .hidden, .happy, .leaving:
            break
        }
    }

    private mutating func callNow(_ now: Date, _ s: Sensors) {
        guard phase == .hidden else { return }
        workTime = timings.reminderInterval
        enter(now, s)
    }

    private mutating func tick(_ now: Date, _ s: Sensors) {
        let last = lastTick ?? now
        let dt = max(0, now.timeIntervalSince(last))
        lastTick = now
        guard !macAsleep else { return }

        let before = lastInput
        let seen = now - s.idleSeconds
        if seen > lastInput && seen > wokeAt + Self.wakeGrace { lastInput = seen }
        let split = min(max(last, lastInput), now)
        let worked = present(last, split, since: before) + present(split, now, since: lastInput)
        let longestBreak = max(lastInput.timeIntervalSince(before), now.timeIntervalSince(lastInput))
        let away = now.timeIntervalSince(lastInput) >= timings.awayAfter
        let inWorkHours = timings.workHours?.contains(now) ?? true
        defer { wasWorkHours = inWorkHours }

        if longestBreak >= timings.longBreak {
            workTime = 0
            if phase != .hidden { set(.hidden, now) }
            return
        }
        if wasWorkHours == true && !inWorkHours {
            workTime = 0
            leave(now, s)
        }
        if inWorkHours { workTime += worked }

        switch phase {
        case .hidden:
            if workTime >= timings.reminderInterval { enter(now, s) }
        case .asleep(let t):
            if !away { set(.moving(t), now) }
        case .entering(let t), .moving(let t), .waiting(let t, _):
            if away {
                set(.asleep(t), now)
            } else if level > t {
                set(level == .thirsty ? .waiting(.thirsty, nil) : .moving(level), now)
            } else {
                act(now, min(dt, 0.1), s)
            }
        case .happy:
            if now.timeIntervalSince(phaseStart) >= Motion.happyDuration { leave(now, s) }
        case .leaving:
            if walk(to: CGPoint(x: exitX, y: position.y), speed: Motion.leaveSpeed, dt: min(dt, 0.1)) {
                set(.hidden, now)
            }
        }
    }

    private mutating func act(_ now: Date, _ dt: TimeInterval, _ s: Sensors) {
        switch phase {
        case .entering(let t), .moving(let t):
            let speed = t == .follow ? Motion.followSpeed : Motion.walkSpeed
            if walk(to: target(t, s), speed: speed, dt: dt) { arrive(t, now, s) }
        case .waiting(let t, let trick):
            if t == .follow {
                if distance(position, target(.follow, s)) > Motion.followSlack {
                    set(.moving(.follow), now)
                    return
                }
                facingRight = s.mouse.x > position.x
            }
            if let trick {
                if case .stroll(let right) = trick {
                    position.x += (right ? 1 : -1) * Motion.strollSpeed * dt
                    facingRight = right
                    home = position
                }
                if now.timeIntervalSince(phaseStart) >= trick.duration {
                    set(.waiting(t, nil), now)
                    scheduleTrick(t, now)
                }
            } else if now >= nextTrickAt {
                set(.waiting(t, pickTrick(t)), now)
            }
        case .hidden, .asleep, .happy, .leaving:
            break
        }
    }

    private mutating func enter(_ now: Date, _ s: Sensors) {
        guard let screen = s.screens.first(where: { $0.frame.contains(s.mouse) }) ?? s.screens.first else { return }
        stage = screen.visible
        position = CGPoint(x: stage.maxX + Motion.offscreen, y: stage.minY)
        home = CGPoint(x: stage.maxX - Motion.homeInset, y: stage.minY)
        facingRight = false
        shownAt = now
        set(.entering(level), now)
    }

    private mutating func leave(_ now: Date, _ s: Sensors) {
        guard phase != .hidden && phase != .leaving else { return }
        let screen = s.screens.first(where: { $0.frame.contains(position) })?.frame ?? stage
        exitX = screen.maxX + Motion.offscreen
        set(.leaving, now)
    }

    private mutating func arrive(_ t: Thirst, _ now: Date, _ s: Sensors) {
        switch t {
        case .chill: facingRight = position.x < stage.midX
        case .follow: facingRight = s.mouse.x > position.x
        case .ask, .thirsty: break
        }
        set(.waiting(t, t == .follow ? .shake : nil), now)
        scheduleTrick(t, now)
    }

    private func target(_ t: Thirst, _ s: Sensors) -> CGPoint {
        switch t {
        case .chill: return home
        case .ask: return CGPoint(x: stage.midX, y: stage.minY)
        case .thirsty: return position
        case .follow:
            let m = s.mouse
            let screen = s.screens.first(where: { $0.frame.contains(m) })?.frame ?? stage
            let half = Layout.followHalfWidth
            let side: CGFloat = position.x < m.x ? -1 : 1
            var x = m.x + side * Motion.followGap
            if x - half < screen.minX || x + half > screen.maxX {
                x = m.x - side * Motion.followGap
            }
            return CGPoint(x: min(max(x, screen.minX + half), screen.maxX - half),
                           y: min(max(m.y - Motion.followDrop, screen.minY), screen.maxY - Layout.followHeight))
        }
    }

    /// How much of `from..<to` lies within `awayAfter` of the input at `input`.
    private func present(_ from: Date, _ to: Date, since input: Date) -> TimeInterval {
        max(0, min(to, input + timings.awayAfter).timeIntervalSince(max(from, input)))
    }

    /// Returns true on arrival.
    private mutating func walk(to target: CGPoint, speed: CGFloat, dt: TimeInterval) -> Bool {
        let dx = target.x - position.x
        let dy = target.y - position.y
        let d = hypot(dx, dy)
        let stride = speed * dt
        if abs(dx) > 0.5 { facingRight = dx > 0 }
        if d <= max(stride, 0.5) {
            position = target
            return true
        }
        position.x += dx / d * stride
        position.y += dy / d * stride
        return false
    }

    private mutating func pickTrick(_ t: Thirst) -> Trick {
        let allowed = t.tricks.filter { trick in
            if trick == lastTrick && t.tricks.count > 1 { return false }
            guard case .stroll(let right) = trick else { return true }
            let end = position.x + (right ? 1 : -1) * Motion.strollSpeed * trick.duration
            return end > stage.minX + Motion.homeInset / 2 && end < stage.maxX - Motion.homeInset / 2
        }
        let trick = allowed.randomElement(using: &rng) ?? .blink
        lastTrick = trick
        return trick
    }

    private mutating func scheduleTrick(_ t: Thirst, _ now: Date) {
        nextTrickAt = now + .random(in: t.trickGap, using: &rng)
    }

    private mutating func set(_ phase: DuckPhase, _ now: Date) {
        self.phase = phase
        phaseStart = now
    }
}

private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
}
