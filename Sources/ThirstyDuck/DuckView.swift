import DuckCore
import SwiftUI

struct DuckView: View {
    static let size = CGSize(width: 240, height: 200)
    /// Distance from the panel bottom to the line the duck stands on.
    static let ground: CGFloat = 10
    static let bubbleGap: CGFloat = 6

    let duck: Duck
    let now: Date
    let bubble: Bubble?
    let bubbleSince: Date

    private var groundY: CGFloat { Self.size.height - Self.ground }
    private var spriteTop: CGFloat { groundY - Sprite.size.height }
    private var headX: CGFloat { Self.size.width / 2 + (duck.facingRight ? 3 : -3) }

    var body: some View {
        let pose = Pose(duck: duck, now: now)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.black.opacity(0.13))
                .frame(width: 49, height: 3)
                .position(x: Self.size.width / 2 + (duck.facingRight ? 1.5 : -1.5), y: groundY + 1.5)

            SpriteView(eyes: pose.eyes, step: pose.step)
                .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
                .scaleEffect(x: pose.mirrored ? -1 : 1, y: 1)
                .position(x: Self.size.width / 2 + pose.jitter, y: groundY - Sprite.size.height / 2 - pose.lift)

            extras

            if let bubble {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    BubbleView(bubble: bubble)
                        .scaleEffect(pop(now.timeIntervalSince(bubbleSince)), anchor: .bottom)
                }
                .frame(width: Self.size.width, height: spriteTop - Self.bubbleGap)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    @ViewBuilder private var extras: some View {
        let w = now.timeIntervalSinceReferenceDate
        switch duck.phase {
        case .waiting(.thirsty, _), .moving(.thirsty), .waiting(.follow, _), .moving(.follow):
            ForEach(0..<2, id: \.self) { i in
                let k = (w * 0.9 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                let side: CGFloat = i == 0 ? -1 : 1
                Text("💦").font(.system(size: 11))
                    .opacity(1 - k)
                    .position(x: headX + side * (16 + k * 10), y: spriteTop - 4 + k * 12)
            }
        case .asleep:
            let k = (w / 2).truncatingRemainder(dividingBy: 1)
            Text("💤").font(.system(size: 12 + k * 6))
                .opacity(1 - k)
                .position(x: headX + (duck.facingRight ? 22 : -22) + k * 8, y: spriteTop - k * 30)
        case .happy:
            let t = now.timeIntervalSince(duck.phaseStart)
            ForEach(Array(["💧", "💛", "✨"].enumerated()), id: \.offset) { i, emoji in
                let k = t - Double(i) * 0.12
                if (0..<1).contains(k) {
                    Text(emoji).font(.system(size: 16))
                        .scaleEffect(0.6 + 0.6 * k)
                        .opacity(1 - k)
                        .position(x: headX + CGFloat(i - 1) * 18, y: spriteTop + 6 - k * 46)
                }
            }
        default:
            EmptyView()
        }
    }

    /// A small spring from 0.4 to 1.
    private func pop(_ t: TimeInterval) -> CGFloat {
        1 - 0.6 * exp(-7 * t) * cos(16 * t)
    }
}

private struct Pose {
    var lift: CGFloat = 0
    var tilt: Double = 0
    var jitter: CGFloat = 0
    var mirrored: Bool
    var eyes = Eyes.open
    var step = 0

    init(duck: Duck, now: Date) {
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

private struct BubbleView: View {
    static let tail: CGFloat = 6
    let bubble: Bubble

    var body: some View {
        Text(bubble.text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(bubble.alarm ? Color(hex: 0xC92A2A) : Color(hex: 0x1F2937))
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .padding(.bottom, Self.tail)
            .background(
                BubbleShape(tail: Self.tail)
                    .fill(bubble.alarm ? Color(hex: 0xFFE3E3) : .white)
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            )
    }
}

private struct BubbleShape: Shape {
    let tail: CGFloat

    func path(in rect: CGRect) -> Path {
        var body = rect
        body.size.height -= tail
        var p = Path(roundedRect: body, cornerRadius: 12)
        p.move(to: CGPoint(x: rect.midX - tail, y: body.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX + tail, y: body.maxY))
        p.closeSubpath()
        return p
    }
}
