import CoreGraphics

/// The duck panel's geometry, shared by the view and the hit test. Points, y up from the panel's bottom left.
public enum Layout {
    public static let panel = CGSize(width: 240, height: 240)
    /// Distance from the panel bottom to the line the duck stands on.
    public static let ground: CGFloat = 10
    public static let sprite = CGSize(width: 80, height: 70)
    public static let bubbleGap: CGFloat = 6
    /// The bubble is drawn in pixels of this many points. The padding, with the outline in it, and the tail count them.
    public static let bubblePixel: CGFloat = 2
    public static let bubblePadding = (x: 4, y: 3)
    public static let bubbleTail = 2

    public static let followBubble = bubbleSize(Bubble.follow.text)
    /// Room the level 4 duck needs around its bottom center: half its bubble at the top of the pop
    /// on each side, and the sprite with that bubble on top. The point extra is for the snap in `bubbleRect`.
    public static let followHalfWidth = followBubble.width * Frame.maxBubbleScale / 2 + 1
    public static let maxHeadroom: CGFloat = 8 * 5
    public static let followHeight = sprite.height + maxHeadroom + 16 + bubbleGap + followBubble.height * Frame.maxBubbleScale + 1

    public static func bubbleSize(_ text: String) -> CGSize { PixelBubble(text).size }

    /// Where `rect`, in points from the top left of a bubble of `size`, is drawn at the pop `scale`: panel points, y down.
    /// The bubble scales around its bottom center, and the edges snap to whole points so its pixels stay crisp.
    public static func bubbleRect(_ rect: CGRect, size: CGSize, headroom: Int, scale: Double) -> CGRect {
        let bottom = CGPoint(x: panel.width / 2, y: panel.height - ground - sprite.height - bubbleGap - CGFloat(headroom) * 5)
        let s = CGFloat(scale)
        let minX = (bottom.x + (rect.minX - size.width / 2) * s).rounded()
        let maxX = (bottom.x + (rect.maxX - size.width / 2) * s).rounded()
        let minY = (bottom.y + (rect.minY - size.height) * s).rounded()
        let maxY = (bottom.y + (rect.maxY - size.height) * s).rounded()
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    // Canvas uses y-down coordinates; the hit test converts the same drawing transform to y-up.
    public static func spriteTransform(_ pose: Pose) -> CGAffineTransform {
        CGAffineTransform(translationX: panel.width / 2 + pose.dx + pose.jitter,
                          y: panel.height - ground - pose.lift + pose.sink)
            .scaledBy(x: pose.mirrored ? -1 : 1, y: 1)
            .rotated(by: pose.tilt * .pi / 180)
            .translatedBy(x: 0, y: -35).rotated(by: pose.spin * .pi / 180)
            .translatedBy(x: 0, y: 35).scaledBy(x: pose.scaleX, y: pose.scaleY)
    }

    static func artBounds(look: Look, pose: Pose) -> CGRect {
        let headroom = CGFloat(look.headroom)
        var cells = CGRect(x: 0, y: -headroom, width: 16, height: 14 + headroom)
        if let item = pose.item ?? look.item { cells = cells.union(item.artBoundsInCells) }
        let cell = sprite.width / 16
        return CGRect(x: (cells.minX - 8) * cell, y: (cells.minY - 14) * cell,
                      width: cells.width * cell, height: cells.height * cell)
    }

    /// The sprite and bubble as `DuckView` draws `frame`. Clicks anywhere else in the panel go to the app below.
    public static func hitRegions(_ frame: Frame, bubble: CGSize?) -> [CGRect] {
        let pose = frame.pose
        let drawn = artBounds(look: frame.look, pose: pose).applying(spriteTransform(pose))
        var duck = CGRect(x: drawn.minX, y: panel.height - drawn.maxY, width: drawn.width, height: drawn.height)
        if pose.clipsAtGround {
            duck = duck.intersection(CGRect(x: 0, y: ground - 1, width: panel.width, height: panel.height - ground + 1))
        }
        guard let bubble else { return [duck] }
        let shown = bubbleRect(CGRect(origin: .zero, size: bubble), size: bubble, headroom: frame.look.headroom, scale: frame.bubbleScale)
        return [duck, CGRect(x: shown.minX, y: panel.height - shown.maxY, width: shown.width, height: shown.height)]
    }
}
