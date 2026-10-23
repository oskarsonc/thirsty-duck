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

    /// Room the level 4 duck needs around its bottom center: half its 137 pt bubble on each side,
    /// and the sprite with the 34 pt bubble on top.
    public static let followHalfWidth: CGFloat = 70
    public static let followHeight: CGFloat = sprite.height + bubbleGap + 34

    public static func bubbleSize(text: CGSize) -> CGSize {
        CGSize(width: text.width + 2 * bubblePadding.width,
               height: text.height + 2 * bubblePadding.height + bubbleTail)
    }

    /// The drawn sprite and bubble. Clicks anywhere else in the panel go to the app below.
    public static func hitRegions(lift: CGFloat, jitter: CGFloat, bubble: CGSize?) -> [CGRect] {
        let duck = CGRect(x: (panel.width - sprite.width) / 2 + jitter, y: ground + lift,
                          width: sprite.width, height: sprite.height)
        guard let bubble else { return [duck] }
        return [duck, CGRect(x: (panel.width - bubble.width) / 2, y: ground + sprite.height + bubbleGap,
                             width: bubble.width, height: bubble.height)]
    }
}
