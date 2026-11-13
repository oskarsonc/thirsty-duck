import CoreGraphics
import Foundation

public enum Thirst: Int, Comparable, Sendable {
    case chill = 1, ask, thirsty, follow

    public static func < (a: Thirst, b: Thirst) -> Bool { a.rawValue < b.rawValue }

    var oldTricks: [Trick] {
        switch self {
        case .chill: [.blink, .lookBack, .hop, .wiggle, .peck, .stroll(right: false), .stroll(right: true)]
        case .ask: [.hop, .wiggle, .hopHop]
        case .thirsty: [.shake, .blink]
        case .follow: [.shake]
        }
    }

    var newTricks: [Trick] {
        switch self {
        case .chill:
            [.moonwalk, .spin, .backflip, .roll, .wave, .hover, .dance, .tapDance, .jelly, .yawn,
             .quack, .loaf, .lookAround, .puddleJump, .swim, .bow, .peekaboo, .love, .kick,
             .sleepyNod, .jumpSpin, .skate, .juggle, .sunbathe]
        case .ask: [.wave, .quack, .drink, .pushUps, .zoomies, .sneeze, .headbang, .puddleJump]
        case .thirsty: [.dizzy, .shiver, .trip, .sneeze, .zoomies]
        case .follow: []
        }
    }

    var oldTrickWeight: Double {
        switch self {
        case .chill, .ask: 0.5
        case .thirsty: 0.6
        case .follow: 1
        }
    }

    var trickGap: ClosedRange<TimeInterval> {
        switch self {
        case .chill: 2.5...5
        case .ask: 1.2...2.5
        case .thirsty: 2...4
        case .follow: 1.5...3
        }
    }
}

public enum Visit: Equatable, Sendable {
    case water(Thirst)

    enum Place { case home, ask, still, follow }

    var place: Place {
        switch self {
        case .water(.chill): .home
        case .water(.ask): .ask
        case .water(.thirsty): .still
        case .water(.follow): .follow
        }
    }

    func level(after elapsed: TimeInterval, step: TimeInterval) -> Visit {
        let steps = max(0, Int(elapsed / step))
        switch self {
        case .water: return .water(Thirst(rawValue: min(4, 1 + steps))!)
        }
    }

    var stageBubble: Bubble {
        switch self {
        case .water(.chill): Bubble(text: "💧?", alarm: false)
        case .water(.ask): Bubble(text: "drink! 💧", alarm: false)
        case .water(.thirsty): Bubble(text: "so thirsty… 💧💧", alarm: true)
        case .water(.follow): .follow
        }
    }

    var happyBubble: Bubble { Bubble(text: "thank you! 💛", alarm: false) }
    var cyclesBubble: Bool { self == .water(.chill) }
    var allowsMoveSpeech: Bool {
        switch self {
        case .water(let thirst): thirst <= .ask
        }
    }
    var sweats: Bool {
        switch self {
        case .water(let thirst): thirst >= .thirsty
        }
    }
    var restingTrick: Trick? { place == .follow ? .shake : nil }
    var oldTricks: [Trick] {
        switch self { case .water(let thirst): thirst.oldTricks }
    }
    var newTricks: [Trick] {
        switch self { case .water(let thirst): thirst.newTricks }
    }
    var oldTrickWeight: Double {
        switch self { case .water(let thirst): thirst.oldTrickWeight }
    }
    var trickGap: ClosedRange<TimeInterval> {
        switch self { case .water(let thirst): thirst.trickGap }
    }

    func duration(of trick: Trick) -> TimeInterval { trick.duration }
}

public enum Trick: Equatable, Sendable {
    case blink, lookBack, hop, wiggle, peck, stroll(right: Bool), hopHop, shake

    case moonwalk, spin, backflip, roll, wave, hover, dance, tapDance, jelly, yawn, sneeze, quack
    case headbang, loaf, lookAround, dizzy, puddleJump, swim, drink, zoomies, pushUps, bow
    case shiver, peekaboo, love, kick, sleepyNod, jumpSpin, skate, trip, juggle, sunbathe

    public var duration: TimeInterval {
        switch self {
        case .blink: 0.25
        case .lookBack: 1.2
        case .hop: 0.5
        case .wiggle: 0.6
        case .peck: 0.5
        case .stroll: 1.5
        case .hopHop: 0.9
        case .shake: 0.6
        case .moonwalk, .loaf, .sleepyNod, .sunbathe: 3.2
        case .spin: 1.2
        case .backflip, .jelly, .quack, .jumpSpin: 1.3
        case .roll, .wave, .tapDance, .puddleJump: 1.8
        case .hover, .yawn, .dizzy, .zoomies, .pushUps, .trip: 2.4
        case .dance, .peekaboo: 2.8
        case .sneeze: 1.9
        case .headbang, .shiver: 1.6
        case .lookAround, .juggle: 2.6
        case .swim, .skate: 3
        case .drink: 3.4
        case .bow, .love: 2.2
        case .kick: 1.4
        }
    }
}

/// What the menu shows about the next duck.
public enum DuckStatus: Equatable, Sendable {
    case here
    case nextIn(TimeInterval)
    /// Outside the hours; `nil` if no hours are set in the next week.
    case offUntil(Date?)
}

public enum DuckPhase: Equatable, Sendable {
    case hidden
    case entering(Visit)
    case waiting(Visit, Trick?)
    case moving(Visit)
    case asleep(Visit)
    case happy(Visit)
    case leaving(Visit)

    public var visit: Visit? {
        switch self {
        case .hidden: nil
        case .entering(let visit), .waiting(let visit, _), .moving(let visit), .asleep(let visit),
             .happy(let visit), .leaving(let visit): visit
        }
    }
}

public struct Bubble: Equatable, Sendable {
    public let text: String
    public let alarm: Bool

    static let follow = Bubble(text: "DRINK WATER! 🥵", alarm: false)
}

public struct Screen: Sendable {
    public var frame: CGRect
    public var visible: CGRect

    public init(frame: CGRect, visible: CGRect) {
        self.frame = frame
        self.visible = visible
    }
}

/// What the app reads from the system on every tick. Global AppKit coordinates.
public struct Sensors: Sendable {
    public var idleSeconds: TimeInterval
    public var mouse: CGPoint
    /// The duck comes in on the first screen. The app puts the screen the user picked first, else the main screen.
    public var screens: [Screen]

    public init(idleSeconds: TimeInterval, mouse: CGPoint, screens: [Screen]) {
        self.idleSeconds = idleSeconds
        self.mouse = mouse
        self.screens = screens
    }
}

public enum DuckInput: Sendable {
    case tick, click, callNow, newLook
    /// The Mac goes to sleep or wakes up (`NSWorkspace` notifications).
    case sleep, wake
}

struct SplitMix64: RandomNumberGenerator, Sendable {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
