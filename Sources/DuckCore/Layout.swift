import CoreGraphics

/// The duck panel's geometry, shared by the view and the hit test. Points, y up from the panel's bottom left.
public enum Layout {
    public static let panel = CGSize(width: 240, height: 200)
    /// Distance from the panel bottom to the line the duck stands on.
    public static let ground: CGFloat = 10
    public static let sprite = CGSize(width: 80, height: 70)
    public static let bubbleGap: CGFloat = 6
    public static let bubblePadding = CGSize(width: 10, height: 6)
    public static let bubbleTail: CGFloat = 6

    /// The level 4 bubble, measured with the bubble font.
    public static let followBubble = CGSize(width: 137, height: 34)
    /// Room the level 4 duck needs around its bottom center: half its bubble at the top of the pop
    /// on each side, and the sprite with that bubble on top.
    public static let followHalfWidth = followBubble.width * Frame.maxBubbleScale / 2
    public static let followHeight = sprite.height + bubbleGap + followBubble.height * Frame.maxBubbleScale

    public static func bubbleSize(text: CGSize) -> CGSize {
        CGSize(width: text.width + 2 * bubblePadding.width,
               height: text.height + 2 * bubblePadding.height + bubbleTail)
    }

    /// The sprite and bubble as `DuckView` draws `frame`. Clicks anywhere else in the panel go to the app below.
    public static func hitRegions(_ frame: Frame, bubble: CGSize?) -> [CGRect] {
        let pose = frame.pose
        let foot = CGPoint(x: panel.width / 2 + pose.jitter, y: ground + pose.lift)
        // SwiftUI turns a positive tilt clockwise on screen, then mirrors. Mirroring the
        // symmetric box turns the tilt the other way.
        let angle = (pose.mirrored ? 1 : -1) * pose.tilt * .pi / 180
        let turn = CGAffineTransform(translationX: foot.x, y: foot.y).rotated(by: angle)
            .translatedBy(x: -foot.x, y: -foot.y)
        let duck = CGRect(x: foot.x - sprite.width / 2, y: foot.y, width: sprite.width, height: sprite.height)
            .applying(turn)
        guard let bubble else { return [duck] }
        let size = CGSize(width: bubble.width * frame.bubbleScale, height: bubble.height * frame.bubbleScale)
        return [duck, CGRect(x: (panel.width - size.width) / 2, y: ground + sprite.height + bubbleGap,
                             width: size.width, height: size.height)]
    }
}
