import CoreGraphics
import Foundation

public enum Thirst: Int, Comparable, Sendable {
    case chill = 1, ask, thirsty, follow

    public static func < (a: Thirst, b: Thirst) -> Bool { a.rawValue < b.rawValue }

    var tricks: [Trick] {
        switch self {
        case .chill: [.blink, .lookBack, .hop, .wiggle, .peck, .stroll(right: false), .stroll(right: true)]
        case .ask: [.hop, .wiggle, .hopHop]
        case .thirsty: [.shake, .blink]
        case .follow: [.shake]
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

public enum Trick: Equatable, Sendable {
    case blink, lookBack, hop, wiggle, peck, stroll(right: Bool), hopHop, shake

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
        }
    }
}

public enum DuckPhase: Equatable, Sendable {
    case hidden
    case entering(Thirst)
    case waiting(Thirst, Trick?)
    case moving(Thirst)
    case asleep(Thirst)
    case happy
    case leaving
}

public struct Bubble: Equatable, Sendable {
    public let text: String
    public let alarm: Bool
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
    public var screens: [Screen]

    public init(idleSeconds: TimeInterval, mouse: CGPoint, screens: [Screen]) {
        self.idleSeconds = idleSeconds
        self.mouse = mouse
        self.screens = screens
    }
}

public enum DuckInput: Sendable {
    case tick, click, callNow
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
