import CoreGraphics
import Testing
import DuckCore

/// The `💧?` bubble, measured with the bubble font.
let shortBubble = Layout.bubbleSize(text: CGSize(width: 27, height: 16))

func hits(_ x: CGFloat, _ y: CGFloat, lift: CGFloat = 0, jitter: CGFloat = 0, bubble: CGSize? = shortBubble) -> Bool {
    Layout.hitRegions(lift: lift, jitter: jitter, bubble: bubble).contains { $0.contains(CGPoint(x: x, y: y)) }
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
