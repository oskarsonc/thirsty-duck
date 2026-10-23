import DuckCore
import SwiftUI

struct DuckView: View {
    let frame: Frame

    private var groundY: CGFloat { Layout.panel.height - Layout.ground }
    private var spriteTop: CGFloat { groundY - Sprite.size.height }
    private var headX: CGFloat { Layout.panel.width / 2 + (frame.facingRight ? 3 : -3) }

    var body: some View {
        let pose = frame.pose
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.black.opacity(0.13))
                .frame(width: 49, height: 3)
                .position(x: Layout.panel.width / 2 + (frame.facingRight ? 1.5 : -1.5), y: groundY + 1.5)

            SpriteView(eyes: pose.eyes, step: pose.step)
                .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
                .scaleEffect(x: pose.mirrored ? -1 : 1, y: 1)
                .position(x: Layout.panel.width / 2 + pose.jitter, y: groundY - Sprite.size.height / 2 - pose.lift)

            extras

            if let bubble = frame.bubble {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    BubbleView(bubble: bubble)
                        .scaleEffect(frame.bubbleScale, anchor: .bottom)
                }
                .frame(width: Layout.panel.width, height: spriteTop - Layout.bubbleGap)
            }
        }
        .frame(width: Layout.panel.width, height: Layout.panel.height)
    }

    @ViewBuilder private var extras: some View {
        switch frame.effect {
        case .sweat(let loop):
            ForEach(0..<2, id: \.self) { i in
                let k = (loop + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                let side: CGFloat = i == 0 ? -1 : 1
                Text("💦").font(.system(size: 11))
                    .opacity(1 - k)
                    .position(x: headX + side * (16 + k * 10), y: spriteTop - 4 + k * 12)
            }
        case .snooze(let k):
            Text("💤").font(.system(size: 12 + k * 6))
                .opacity(1 - k)
                .position(x: headX + (frame.facingRight ? 22 : -22) + k * 8, y: spriteTop - k * 30)
        case .cheer(let t):
            ForEach(Array(["💧", "💛", "✨"].enumerated()), id: \.offset) { i, emoji in
                let k = t - Double(i) * 0.12
                if (0..<1).contains(k) {
                    Text(emoji).font(.system(size: 16))
                        .scaleEffect(0.6 + 0.6 * k)
                        .opacity(1 - k)
                        .position(x: headX + CGFloat(i - 1) * 18, y: spriteTop + 6 - k * 46)
                }
            }
        case .none:
            EmptyView()
        }
    }
}

private struct BubbleView: View {
    let bubble: Bubble

    var body: some View {
        Text(bubble.text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(bubble.alarm ? Color(hex: 0xC92A2A) : Color(hex: 0x1F2937))
            .fixedSize()
            .padding(.horizontal, Layout.bubblePadding.width)
            .padding(.vertical, Layout.bubblePadding.height)
            .padding(.bottom, Layout.bubbleTail)
            .background(
                BubbleShape(tail: Layout.bubbleTail)
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
