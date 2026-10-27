import CoreGraphics
import Testing
import DuckCore

/// The `💧?` bubble, 40 x 32 pt.
let shortBubble = Layout.bubbleSize("💧?")

func hits(_ x: CGFloat, _ y: CGFloat, lift: CGFloat = 0, jitter: CGFloat = 0, tilt: Double = 0, mirrored: Bool = false,
          bubble: CGSize? = shortBubble, bubbleScale: Double = 1) -> Bool {
    var frame = Duck(timings: .normal, seed: 1).frame(at: .now)
    frame.pose.lift = lift
    frame.pose.jitter = jitter
    frame.pose.tilt = tilt
    frame.pose.mirrored = mirrored
    frame.bubbleScale = bubbleScale
    return Layout.hitRegions(frame, bubble: bubble).contains { $0.contains(CGPoint(x: x, y: y)) }
}

@Test func spriteAndBubbleTakeClicks() {
    #expect(hits(120, 40))
    #expect(hits(120, 100))
}

@Test func clearAreasAroundTheDuckDoNotTakeClicks() {
    #expect(!hits(120, 83), "between the sprite and the bubble")
    #expect(!hits(70, 100), "left of a short bubble")
    #expect(!hits(150, 100), "right of a short bubble")
    #expect(!hits(50, 20), "beside the sprite")
    #expect(!hits(120, 100, bubble: nil), "where the bubble is when it is not shown")
}

@Test func hitRegionFollowsTheHopAndShake() {
    #expect(!hits(120, 15, lift: 14))
    #expect(hits(120, 90, lift: 14))
    #expect(hits(161, 40, jitter: 2.5))
    #expect(!hits(81, 40, jitter: 2.5))
}

@Test func bubbleRegionFollowsThePop() {
    #expect(!hits(140, 110, bubbleScale: 0.4), "clear corner of the small bubble")
    #expect(hits(120, 92, bubbleScale: 0.4))
    #expect(!hits(141, 115))
    #expect(hits(141, 115, bubbleScale: 1.15), "past the full bubble while it overshoots")
}

@Test func spriteRegionFollowsTheTilt() {
    #expect(hits(77.6, 51.4, tilt: 18, mirrored: true), "beak at the bottom of a peck to the left")
    #expect(hits(162.4, 51.4, tilt: 18), "beak at the bottom of a peck to the right")
    #expect(!hits(77.6, 51.4, tilt: 18), "the right peck leans away from the left")
}

@Test func bubbleSizeComesFromTheFont() {
    // 💧 5, gap 1, ? 5; padding 4 on each side, the shadow column.
    #expect(Layout.bubbleSize("💧?") == CGSize(width: 2 * (11 + 8 + 1), height: 2 * (7 + 6 + 2 + 1)))
    #expect(Layout.followBubble == Layout.bubbleSize("DRINK WATER! 🥵"))
}

@Test func bubblePixelsFitTheGrid() {
    let bubble = PixelBubble("hi!")
    func ink(_ x: Int, _ y: Int) -> PixelBubble.Ink? { bubble.pixels.last { $0.x == x && $0.y == y }?.ink }
    #expect(bubble.pixels.allSatisfy { (0..<bubble.width).contains($0.x) && (0..<bubble.height).contains($0.y) })
    #expect(ink(0, 0) == nil, "corner cut")
    #expect(ink(1, 0) == .line)
    #expect(ink(1, 1) == .fill)
    #expect(ink(Layout.bubblePadding.x, Layout.bubblePadding.y) == .text, "top left of the H")
    #expect(ink(bubble.width - 1, bubble.height - 2) == nil, "no tail under the right side")
    #expect(bubble.pixels.contains { $0.y == bubble.height - 1 && $0.ink == .shadow }, "shadow under the tail")
}

@Test func bubbleSnapsToWholePointsWhileItPops() {
    let size = Layout.bubbleSize("drink! 💧")
    for scale in stride(from: 0.4, through: 1.2, by: 0.013) {
        let r = Layout.bubbleRect(CGRect(x: 6, y: 4, width: 2, height: 2), size: size, headroom: 3, scale: scale)
        #expect(r.minX == r.minX.rounded() && r.minY == r.minY.rounded() && r.width == r.width.rounded())
    }
    let full = Layout.bubbleRect(CGRect(origin: .zero, size: size), size: size, headroom: 0, scale: 1)
    #expect(full == CGRect(x: (Layout.panel.width - size.width) / 2, y: 154 - size.height, width: size.width, height: size.height))
}
