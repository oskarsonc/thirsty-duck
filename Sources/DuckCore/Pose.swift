import CoreGraphics
import Foundation

public enum Eyes: Sendable {
    case open, closed, happy
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
