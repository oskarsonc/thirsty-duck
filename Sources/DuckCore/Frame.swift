import CoreGraphics
import Foundation

/// Everything `DuckView` draws at one moment. The app redraws only when it changes.
public struct Frame: Equatable, Sendable {
    public var pose: Pose
    public var facingRight: Bool
    public var effect: Effect
    public var bubble: Bubble?
    public var bubbleScale: Double
    public var look: Look
    public var particles: [Particle]
    public var lookClock: Int
    public var waterPhase: Double

    /// A small spring from 0.4 to 1 that overshoots on the way.
    static func bubbleScale(age: TimeInterval) -> Double {
        age < Motion.bubblePop ? 1 - 0.6 * exp(-7 * age) * cos(16 * age) : 1
    }

    static let maxBubbleScale = stride(from: 0, through: Motion.bubblePop, by: 0.001).map(bubbleScale).max()!
}

public enum Effect: Equatable, Sendable {
    case none
    /// Progress through the animation loop, 0 to 1.
    case sweat(Double), snooze(Double)
    /// Seconds since the click.
    case cheer(TimeInterval)
}

public enum Eyes: Sendable {
    case open, closed, happy, x, wide, focus
}

public enum Feet: Sendable {
    case a, b, kick, hidden
}

public struct Particle: Equatable, Sendable {
    public var emoji: String
    public var x: CGFloat
    public var y: CGFloat
    public var size: CGFloat
    public var opacity: Double

    public init(emoji: String, x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double) {
        self.emoji = emoji
        self.x = x
        self.y = y
        self.size = size
        self.opacity = opacity
    }
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
        let pose = Pose(duck: self, now: now)
        return Frame(pose: pose, facingRight: facingRight, effect: effect,
                     bubble: bubble, bubbleScale: Frame.bubbleScale(age: now.timeIntervalSince(bubbleSince)),
                     look: look, particles: pose.particles, lookClock: look.isAnimated ? Int(w * 12) : 0,
                     waterPhase: pose.water ? w * 4 : 0)
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
    public var feet = Feet.a
    public var dx: CGFloat = 0
    public var sink: CGFloat = 0
    public var spin: Double = 0
    public var scaleX: Double = 1
    public var scaleY: Double = 1
    public var beakOpen = false
    public var wingUp = false
    public var item: HeldItem?
    public var glasses: Glasses?
    public var bottleFill: Int?
    public var puddle = false
    public var water = false
    public var clipsAtGround = false

    var particles: [Particle] = []
    var speech: String?

    public init(duck: Duck, now: Date) {
        mirrored = !duck.facingRight
        let w = now.timeIntervalSinceReferenceDate
        let t = max(0, now.timeIntervalSince(duck.phaseStart))
        if duck.isWalking { walk(w) }
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
            case .moonwalk:
                if k < 0.75 {
                    walk(w, frequency: 5)
                    dx = 22 - 44 * (k / 0.75)
                    tilt = -5 + 3 * sin(w * .pi * 5)
                } else {
                    let q = ease((k - 0.75) / 0.25)
                    dx = -22 + 22 * q
                    tilt = -6 * (1 - q)
                    eyes = .happy
                }
            case .spin:
                scaleX = cos(4 * .pi * k)
                lift = 4 * sin(.pi * k)
                eyes = .happy
            case .backflip:
                let q = clamp((k - 0.15) / 0.7)
                let sq = k < 0.15 ? sin(.pi * k / 0.15) : k > 0.85 ? sin(.pi * (k - 0.85) / 0.15) : 0
                lift = 34 * sin(.pi * q)
                spin = -360 * ease(q)
                scaleY = 1 - 0.18 * sq
                scaleX = 1 + 0.1 * sq
                eyes = q > 0 && q < 1 ? .closed : .open
            case .roll:
                let q = ease(k < 0.5 ? k * 2 : (k - 0.5) * 2)
                let v = k < 0.5 ? q : 1 - q
                spin = 360 * v
                dx = 24 * v
                eyes = .closed
            case .wave:
                wingUp = Int(w * 5) % 2 != 0
                eyes = .happy
                tilt = 3 * sin(w * 10)
                speech = k > 0.1 && k < 0.9 ? "hi!" : nil
            case .hover:
                lift = k < 0.15 ? 14 * ease(k / 0.15) : k > 0.85 ? 14 * (1 - ease((k - 0.85) / 0.15)) : 14 + 3 * sin(w * 8)
                wingUp = Int(w * 14) % 2 != 0
                feet = .b
            case .dance:
                dx = 7 * sin(4 * .pi * k)
                tilt = 10 * sin(8 * .pi * k)
                feet = Int(w * 5) % 2 == 0 ? .a : .b
                lift = 3 * abs(sin(8 * .pi * k))
                eyes = Int(w * 2.5) % 2 != 0 ? .happy : .open
                particles = notes(w)
            case .tapDance:
                feet = Int(w * 14) % 2 == 0 ? .a : .b
                lift = 1.5 * abs(sin(w * 44))
                tilt = 2 * sin(w * 7)
                particles = notes(w, emoji: "♫")
            case .jelly:
                let s = sin(5 * .pi * k) * (1 - k)
                scaleY = 1 - 0.28 * s
                scaleX = 1 + 0.22 * s
                eyes = k < 0.3 ? .closed : .open
            case .yawn:
                let m = sin(.pi * k)
                scaleY = 1 + 0.14 * m
                scaleX = 1 - 0.05 * m
                tilt = -7 * m
                beakOpen = m > 0.5
                eyes = m > 0.25 ? .closed : .open
                wingUp = m > 0.6
                speech = m > 0.7 ? "yaawn" : nil
            case .sneeze:
                if k < 0.55 {
                    let q = k / 0.55
                    tilt = -12 * ease(q)
                    eyes = .closed
                    beakOpen = q > 0.6
                } else if k < 0.65 {
                    tilt = 16
                    jitter = 2 * sin(w * 90)
                    beakOpen = true
                    eyes = .closed
                    speech = "achoo!"
                    particles = spray(k)
                } else {
                    let q = (k - 0.65) / 0.35
                    tilt = 16 * (1 - ease(q))
                    eyes = q < 0.5 ? .x : .open
                    speech = q < 0.6 ? "achoo!" : nil
                    particles = spray(k)
                }
            case .quack:
                beakOpen = k < 0.6 && Int(k * 10) % 2 == 0
                lift = k < 0.6 ? 3 * abs(sin(k * .pi * 4)) : 0
                speech = k < 0.95 ? "quack!" : nil
            case .headbang:
                tilt = 16 * sin(w * 2 * .pi * 3.2)
                eyes = .closed
                feet = Int(w * 6) % 2 == 0 ? .a : .b
                particles = [Particle(emoji: "🤘", x: -36, y: 60, size: 15, opacity: 1)]
            case .loaf:
                let m = k < 0.15 ? ease(k / 0.15) : k > 0.85 ? 1 - ease((k - 0.85) / 0.15) : 1
                sink = 10 * m
                feet = m > 0.5 ? .hidden : .a
                scaleX = 1 + 0.06 * m
                scaleY = 1 - 0.06 * m
                eyes = k > 0.3 && k < 0.8 ? .closed : .open
            case .lookAround:
                if (k > 0.2 && k < 0.45) || (k > 0.6 && k < 0.75) { mirrored.toggle() }
                eyes = k > 0.45 && k < 0.6 ? .wide : .open
                if eyes == .wide { particles = [Particle(emoji: "❓", x: 26, y: 80, size: 14, opacity: 1)] }
            case .dizzy:
                tilt = 12 * sin(w * 7)
                dx = 5 * sin(w * 3.5)
                eyes = .x
                feet = Int(w * 3) % 2 == 0 ? .a : .b
                particles = stars(w, x: 4, y: -80, radius: 22)
            case .puddleJump:
                let q = clamp(k / 0.5)
                let kk = clamp((k - 0.5) / 0.5)
                puddle = true
                lift = 22 * sin(.pi * q)
                scaleY = k > 0.5 && k < 0.6 ? 0.85 : 1
                eyes = k > 0.5 ? .happy : .open
                if k > 0.5 {
                    particles = [-1.0, 1, -1, 1].enumerated().map { i, d in
                        Particle(emoji: "💧", x: d * (14 + kk * (26 + Double(i) * 6)),
                                 y: 4 + sin(.pi * kk) * (22 + Double(i) * 6), size: 12, opacity: 1 - kk)
                    }
                }
            case .swim:
                water = true
                sink = 14 + 2 * sin(w * 3)
                dx = 10 * sin(2 * .pi * k)
                eyes = Int(w) % 3 == 2 ? .happy : .open
                feet = .hidden
            case .drink:
                tilt = k < 0.15 ? -30 * ease(k / 0.15) : k < 0.7 ? -30 : -30 * (1 - ease((k - 0.7) / 0.3))
                let q = clamp((k - 0.15) / 0.55)
                bottleFill = Int((5 * (1 - q)).rounded())
                eyes = k > 0.15 && k < 0.7 ? .closed : k >= 0.7 ? .happy : .open
                speech = k > 0.2 && k < 0.68 ? "glug glug" : k > 0.72 ? "ahh 💙" : nil
            case .zoomies:
                if k < 0.3 {
                    walk(w, frequency: 10)
                    dx = 45 * (k / 0.3)
                    tilt = 8
                    particles = dust(dx, direction: 1)
                } else if k < 0.7 {
                    walk(w, frequency: 10)
                    mirrored.toggle()
                    dx = 45 - 90 * ((k - 0.3) / 0.4)
                    tilt = -8
                    particles = dust(dx, direction: -1)
                } else {
                    walk(w, frequency: 8)
                    dx = -45 + 45 * ease((k - 0.7) / 0.3)
                }
            case .pushUps:
                let d = abs(sin(4 * .pi * k))
                scaleY = 1 - 0.18 * d
                scaleX = 1 + 0.05 * d
                tilt = 6 * d
                eyes = .focus
                speech = k > 0.82 ? "💪" : nil
            case .bow:
                let m = k < 0.3 ? ease(k / 0.3) : k < 0.7 ? 1 : 1 - ease((k - 0.7) / 0.3)
                let a = 1 - clamp((k - 0.72) / 0.28)
                tilt = 30 * m
                eyes = m > 0.5 ? .closed : .open
                if k > 0.72 {
                    particles = [Particle(emoji: "✨", x: -28, y: 70, size: 14, opacity: a),
                                 Particle(emoji: "✨", x: 30, y: 58, size: 11, opacity: a)]
                }
            case .shiver:
                jitter = 1.6 * sin(w * 2 * .pi * 25)
                eyes = .focus
                speech = "brrr"
                particles = (0..<2).map { i in
                    let kk = (w * 0.7 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                    return Particle(emoji: "❄️", x: i == 1 ? 36 : -38, y: 90 - kk * 50, size: 11, opacity: 1 - kk)
                }
            case .peekaboo:
                if k < 0.25 { sink = 78 * ease(k / 0.25) }
                else if k < 0.6 { sink = 78 }
                else if k < 0.7 { sink = 78 * (1 - ease((k - 0.6) / 0.1)) }
                clipsAtGround = true
                eyes = k >= 0.6 ? .wide : .open
                speech = k > 0.66 ? "boo!" : nil
                lift = k > 0.7 && k < 0.82 ? 10 * sin(.pi * (k - 0.7) / 0.12) : 0
            case .love:
                eyes = .happy
                tilt = 6 * sin(w * 4)
                particles = (0..<3).map { i in
                    let kk = (w * 0.6 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    return Particle(emoji: i == 1 ? "💙" : "💛", x: -24 + Double(i) * 24 + 4 * sin(kk * 6),
                                    y: 72 + kk * 40, size: 13, opacity: 1 - kk)
                }
            case .kick:
                let kick = Int(w * 4) % 2 == 0
                feet = kick ? .kick : .a
                tilt = kick ? -6 : 0
            case .sleepyNod:
                let c = w.truncatingRemainder(dividingBy: 1.6) / 1.6
                if c < 0.8 {
                    tilt = 16 * ease(c / 0.8)
                    eyes = .closed
                    particles = [Particle(emoji: "💤", x: 28, y: 80 + c * 10, size: 12, opacity: c)]
                } else if c < 0.9 { eyes = .wide }
            case .jumpSpin:
                let q = clamp((k - 0.1) / 0.75)
                let sq = k < 0.1 ? sin(.pi * k / 0.1) : k > 0.85 ? sin(.pi * (k - 0.85) / 0.15) : 0
                lift = 26 * sin(.pi * q)
                scaleX = cos(2 * .pi * q) * (1 + 0.1 * sq)
                scaleY = 1 - 0.15 * sq
                eyes = q > 0 && q < 1 ? .happy : .open
            case .skate:
                let v = cos(2 * .pi * k)
                item = .skateboard
                dx = 30 * sin(2 * .pi * k)
                if v < 0 { mirrored.toggle() }
                tilt = -3 * abs(v)
            case .trip:
                if k < 0.25 { walk(w) }
                else if k < 0.35 {
                    tilt = 80 * ease((k - 0.25) / 0.1)
                    eyes = .x
                } else if k < 0.6 {
                    tilt = 80
                    eyes = .x
                    particles = stars(w, x: 58, y: -22, radius: 14)
                } else if k < 0.75 {
                    tilt = 80 * (1 - ease((k - 0.6) / 0.15))
                    eyes = .closed
                } else {
                    eyes = .happy
                    speech = "oops!"
                }
            case .juggle:
                wingUp = Int(w * 4) % 2 != 0
                tilt = -5
                particles = (0..<3).map { i in
                    let ph = (w * 1.1 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    return Particle(emoji: "💧", x: 22 * cos(2 * .pi * ph) + 4,
                                    y: 86 + 26 * abs(sin(2 * .pi * ph)), size: 12, opacity: 1)
                }
            case .sunbathe:
                let m = k < 0.15 ? ease(k / 0.15) : k > 0.85 ? 1 - ease((k - 0.85) / 0.15) : 1
                glasses = .sunglasses
                sink = 10 * m
                feet = m > 0.5 ? .hidden : .a
                tilt = -10 * m
                particles = [Particle(emoji: "☀️", x: -46, y: 98, size: 18, opacity: m)]
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
        // Prototype offsets face right; a trick's mirror flip must not change their panel-space direction.
        if !duck.facingRight {
            dx = -dx
            for i in particles.indices { particles[i].x = -particles[i].x }
        }
        if (item ?? duck.look.item) == .skateboard { lift += 10 }
        if duck.look.palette == .ghost { lift += 3 + 3 * sin(2.2 * w) }
        switch duck.phase {
        case .waiting(_, .roll?), .waiting(_, .backflip?), .waiting(_, .trip?):
            var bounds = Layout.artBounds(look: duck.look, pose: self)
            if tilt != 0 || spin != 0 {
                // Sprite.fill extends turned cells right and down to hide seams.
                bounds.size.width += 0.4
                bounds.size.height += 0.4
            }
            let bottom = bounds.applying(Layout.spriteTransform(self)).maxY
            lift += max(0, bottom - (Layout.panel.height - Layout.ground))
        default: break
        }
    }

    private mutating func walk(_ w: Double, frequency: Double = 6) {
        feet = Int(w * frequency) % 2 == 0 ? .a : .b
        lift = 2 * abs(sin(w * .pi * frequency))
        tilt = 3 * sin(w * .pi * frequency)
    }
}

private func clamp(_ x: Double) -> Double { max(0, min(1, x)) }
private func ease(_ k: Double) -> Double { k < 0.5 ? 2 * k * k : 1 - pow(-2 * k + 2, 2) / 2 }

private func notes(_ t: Double, emoji: String? = nil) -> [Particle] {
    (0..<2).map { i in
        let k = (t * 0.8 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
        return Particle(emoji: emoji ?? (i == 1 ? "♫" : "♪"), x: (i == 1 ? 1 : -1) * (30 + k * 8),
                        y: 62 + k * 34, size: 15, opacity: 1 - k)
    }
}

private func spray(_ k: Double) -> [Particle] {
    let kk = clamp((k - 0.55) / 0.4)
    return (0..<3).map { i in
        Particle(emoji: "💦", x: 44 + kk * (20 + Double(i) * 8), y: 48 - Double(i) * 6 - kk * 10,
                 size: 11, opacity: 1 - kk)
    }
}

private func dust(_ dx: Double, direction: Double) -> [Particle] {
    [Particle(emoji: "💨", x: dx - direction * 40, y: 12, size: 13, opacity: 0.8)]
}

private func stars(_ t: Double, x: Double, y: Double, radius: Double) -> [Particle] {
    (0..<3).map { i in
        let a = t * 5 + Double(i) * 2.094
        return Particle(emoji: "⭐", x: x + radius * cos(a), y: -(y + radius * 0.3 * sin(a)), size: 10, opacity: 1)
    }
}
