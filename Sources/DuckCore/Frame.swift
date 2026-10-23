import CoreGraphics
import Foundation

/// Everything `DuckView` draws at one moment. The app redraws only when it changes.
public struct Frame: Equatable, Sendable {
    public var pose: Pose
    public var facingRight: Bool
    public var effect: Effect
    public var bubble: Bubble?
    public var bubbleScale: Double
}

public enum Effect: Equatable, Sendable {
    case none
    /// Progress through the animation loop, 0 to 1.
    case sweat(Double), snooze(Double)
    /// Seconds since the click.
    case cheer(TimeInterval)
}

public enum Eyes: Sendable {
    case open, closed, happy
}

extension Duck {
    public func frame(at now: Date) -> Frame {
        let w = now.timeIntervalSinceReferenceDate
        let effect: Effect = switch phase {
        case .waiting(.thirsty, _), .moving(.thirsty), .waiting(.follow, _), .moving(.follow):
            .sweat((w * 0.9).truncatingRemainder(dividingBy: 1))
        case .asleep: .snooze((w / 2).truncatingRemainder(dividingBy: 1))
        case .happy: .cheer(now.timeIntervalSince(phaseStart))
        default: .none
        }
        // A small spring from 0.4 to 1.
        let age = now.timeIntervalSince(bubbleSince)
        let scale = age < Motion.bubblePop ? 1 - 0.6 * exp(-7 * age) * cos(16 * age) : 1
        return Frame(pose: Pose(duck: self, now: now), facingRight: facingRight, effect: effect,
                     bubble: bubble, bubbleScale: scale)
    }

    /// Ticks per second the app needs to show the duck smoothly.
    public func tickRate(at now: Date) -> Double {
        if bubble != nil && now.timeIntervalSince(bubbleSince) < Motion.bubblePop { return 30 }
        switch phase {
        case .hidden: return 1
        case .asleep: return 2
        // Nothing here glides, so 10 Hz is enough. Sweat drops step a little, like the pixel feet.
        case .waiting(_, nil), .waiting(_, .blink?), .waiting(_, .lookBack?): return 10
        case .entering, .moving, .leaving, .happy, .waiting: return 30
        }
    }
}

/// How the sprite is drawn at one moment.
public struct Pose: Equatable, Sendable {
    public var lift: CGFloat = 0
    public var tilt: Double = 0
    public var jitter: CGFloat = 0
    public var mirrored: Bool
    public var eyes = Eyes.open
    public var step = 0

    public init(duck: Duck, now: Date) {
        mirrored = !duck.facingRight
        let w = now.timeIntervalSinceReferenceDate
        let t = now.timeIntervalSince(duck.phaseStart)
        if duck.isWalking {
            step = Int(w * 6) % 2
            lift = 2 * abs(sin(w * .pi * 6))
            tilt = 3 * sin(w * .pi * 6)
        }
        switch duck.phase {
        case .waiting(let thirst, let trick):
            if thirst == .thirsty { tilt += 5 }
            guard let trick else { break }
            let k = min(t / trick.duration, 1)
            switch trick {
            case .blink: eyes = .closed
            case .lookBack: mirrored.toggle()
            case .hop: lift = 14 * sin(.pi * k)
            case .hopHop: lift = 14 * abs(sin(2 * .pi * k))
            case .wiggle: tilt = 8 * sin(4 * .pi * k)
            case .peck: tilt = 18 * sin(.pi * k)
            case .shake: jitter = 2.5 * sin(t * 2 * .pi * 18)
            case .stroll: break
            }
        case .asleep:
            eyes = .closed
        case .happy:
            eyes = .happy
            lift = 14 * abs(sin(2 * .pi * min(t / 0.9, 1)))
        case .leaving:
            eyes = .happy
        case .hidden, .entering, .moving:
            break
        }
    }
}
