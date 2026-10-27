import DuckCore
import SwiftUI

struct DuckView: View {
    let frame: Frame

    private var pose: Pose { frame.pose }
    private var groundY: CGFloat { Layout.panel.height - Layout.ground }
    private var spriteTop: CGFloat { groundY - Sprite.size.height }
    private var headX: CGFloat { Layout.panel.width / 2 + pose.dx + (frame.facingRight ? 3 : -3) }
    /// The point under the feet after `lift`, `dx` and jitter. Particles are placed from here.
    private var feet: CGPoint { CGPoint(x: Layout.panel.width / 2 + pose.dx + pose.jitter, y: groundY - pose.lift) }
    private var lookTime: Double { Double(frame.lookClock) / 12 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { ctx, _ in
                drawGround(ctx)
                drawSprite(ctx)
                drawWater(ctx)
            }
            .frame(width: Layout.panel.width, height: Layout.panel.height)

            ForEach(Array(particles.enumerated()), id: \.offset) { _, p in
                Text(p.emoji).font(.system(size: (p.size * 1.1).rounded()))
                    .foregroundStyle(Color(hex: 0x5B6B7F))
                    .opacity(max(0, min(1, p.opacity)))
                    .position(x: feet.x + p.x, y: feet.y - p.y)
            }

            extras

            if let bubble = frame.bubble {
                Canvas { ctx, _ in drawBubble(ctx, bubble) }
                    .frame(width: Layout.panel.width, height: Layout.panel.height)
            }
        }
        .frame(width: Layout.panel.width, height: Layout.panel.height)
    }

    private var particles: [Particle] {
        frame.particles + (Sprite.paint(frame.look.palette).sparkles ? Sprite.sparkles(t: lookTime) : [])
    }

    private func drawGround(_ ctx: GraphicsContext) {
        if pose.puddle {
            ctx.fill(Path(ellipseIn: CGRect(x: Layout.panel.width / 2 - 75, y: groundY - 3, width: 150, height: 8)),
                     with: .color(Color(hex: 0x74C0FC).opacity(0.6)))
        }
        guard !pose.water, !(pose.clipsAtGround && pose.sink > 40) else { return }
        let width = 49 * max(0.45, 1 - pose.lift / 60)
        let x = Layout.panel.width / 2 + pose.dx + (frame.facingRight ? 1.5 : -1.5)
        ctx.fill(Path(roundedRect: CGRect(x: x - width / 2, y: groundY, width: width, height: 3), cornerRadius: 1.5),
                 with: .color(.black.opacity(0.13)))
    }

    /// Tilt, spin and scale are in the duck's own space, so they go inside the mirror.
    private func drawSprite(_ ctx: GraphicsContext) {
        var ctx = ctx
        if pose.clipsAtGround {
            ctx.clip(to: Path(CGRect(x: 0, y: 0, width: Layout.panel.width, height: groundY + 1)))
        }
        ctx.opacity = Sprite.paint(frame.look.palette).opacity
        ctx.drawLayer { ctx in
            ctx.concatenate(Layout.spriteTransform(pose))
            Sprite.fill(Sprite.pixels(frame.look, pose, t: lookTime), in: ctx, smooth: pose.tilt != 0 || pose.spin != 0)
        }
    }

    private func drawWater(_ ctx: GraphicsContext) {
        guard pose.water else { return }
        var ctx = ctx
        // A pond with round ends, wide enough for the swim's sway, instead of a band across the whole panel.
        ctx.clip(to: Path(ellipseIn: CGRect(x: Layout.panel.width / 2 - 80, y: groundY - 20, width: 160, height: 48)))
        var band = Path()
        band.move(to: CGPoint(x: 0, y: Layout.panel.height))
        for x in stride(from: 0, through: Layout.panel.width, by: 4) {
            band.addLine(to: CGPoint(x: x, y: groundY - 12 + 2 * sin(x / 9 + frame.waterPhase)))
        }
        band.addLine(to: CGPoint(x: Layout.panel.width, y: Layout.panel.height))
        ctx.fill(band, with: .color(Color(hex: 0x4DABF7).opacity(0.82)))
        for i in 0..<2 {
            let k = (frame.waterPhase / 4 * 0.6 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
            let r = CGSize(width: 30 + k * 40, height: 3 + k * 3)
            var ring = ctx
            ring.opacity = 1 - k
            ring.stroke(Path(ellipseIn: CGRect(x: feet.x - r.width, y: groundY - 8 - r.height, width: 2 * r.width, height: 2 * r.height)),
                        with: .color(.white.opacity(0.7)), lineWidth: 1.5)
        }
    }

    /// One path per ink, in the bubble's order, so the text lands on the fill.
    private func drawBubble(_ ctx: GraphicsContext, _ bubble: Bubble) {
        let pixels = PixelBubble(bubble.text)
        let px = Layout.bubblePixel
        var paths: [(ink: PixelBubble.Ink, path: Path)] = []
        for p in pixels.pixels {
            let rect = Layout.bubbleRect(CGRect(x: CGFloat(p.x) * px, y: CGFloat(p.y) * px, width: px, height: px),
                                         size: pixels.size, headroom: frame.look.headroom, scale: frame.bubbleScale)
            if let i = paths.firstIndex(where: { $0.ink == p.ink }) {
                paths[i].path.addRect(rect)
            } else {
                paths.append((p.ink, Path(rect)))
            }
        }
        for (ink, path) in paths {
            let color = switch ink {
            case .shadow: Color.black.opacity(0.15)
            case .line: Color(hex: 0x2B2B2B)
            case .fill: bubble.alarm ? Color(hex: 0xFFE3E3) : .white
            case .text: Color(hex: bubble.alarm ? 0xC92A2A : 0x2B2B2B)
            case .color(let hex): Color(hex: hex)
            }
            ctx.fill(path, with: .color(color), style: FillStyle(antialiased: false))
        }
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
