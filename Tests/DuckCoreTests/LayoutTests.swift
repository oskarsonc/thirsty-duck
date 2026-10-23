import CoreGraphics
import Testing
import DuckCore

/// The `💧?` bubble, measured with the bubble font.
let shortBubble = Layout.bubbleSize(text: CGSize(width: 27, height: 16))

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
    #expect(hits(145, 115, bubbleScale: 1.15), "past the full bubble while it overshoots")
}

@Test func spriteRegionFollowsTheTilt() {
    #expect(hits(77.6, 51.4, tilt: 18, mirrored: true), "beak at the bottom of a peck to the left")
    #expect(hits(162.4, 51.4, tilt: 18), "beak at the bottom of a peck to the right")
    #expect(!hits(77.6, 51.4, tilt: 18), "the right peck leans away from the left")
}
