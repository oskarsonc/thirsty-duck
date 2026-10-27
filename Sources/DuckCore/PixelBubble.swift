import CoreGraphics

/// A speech bubble on a grid of `Layout.bubblePixel` pixels, y down: a box with an outline and its corners cut,
/// a stepped tail under the middle, a shadow one pixel down and to the right, and the text.
public struct PixelBubble: Equatable, Sendable {
    public enum Ink: Hashable, Sendable {
        case shadow, line, fill, text
        case color(UInt32)
    }

    public struct Pixel: Equatable, Sendable {
        public let x: Int
        public let y: Int
        public let ink: Ink
    }

    /// The grid, with the tail and the shadow.
    public let width: Int
    public let height: Int
    /// Shadow first, then the box, then the text.
    public let pixels: [Pixel]

    public var size: CGSize { CGSize(width: CGFloat(width) * Layout.bubblePixel, height: CGFloat(height) * Layout.bubblePixel) }

    public init(_ text: String) {
        let pad = Layout.bubblePadding
        let w = PixelFont.width(text) + 2 * pad.x
        let h = PixelFont.height + 2 * pad.y
        let mid = w / 2
        func inside(_ i: Int, _ j: Int) -> Bool {
            if (0..<h).contains(j) && (0..<w).contains(i) {
                return min(i, w - 1 - i) + min(j, h - 1 - j) >= 1
            }
            let row = j - h
            guard (0..<Layout.bubbleTail).contains(row) else { return false }
            let half = Layout.bubbleTail - row
            return (mid - half..<mid + half).contains(i)
        }
        let shape = (0..<h + Layout.bubbleTail).flatMap { j in (0..<w).map { i in (i, j) } }.filter { inside($0.0, $0.1) }

        var pixels = shape.filter { !inside($0.0 + 1, $0.1 + 1) }.map { Pixel(x: $0.0 + 1, y: $0.1 + 1, ink: .shadow) }
        for (i, j) in shape {
            let edge = !(inside(i - 1, j) && inside(i + 1, j) && inside(i, j - 1) && inside(i, j + 1))
            pixels.append(Pixel(x: i, y: j, ink: edge ? .line : .fill))
        }
        var x = pad.x
        for c in text {
            guard let rows = PixelFont.glyph(c) else { continue }
            for (r, row) in rows.enumerated() {
                for (k, ch) in row.enumerated() where ch != "." {
                    pixels.append(Pixel(x: x + k, y: pad.y + r, ink: ch == "#" ? .text : .color(PixelFont.colors[ch]!)))
                }
            }
            x += rows[0].count + 1
        }
        width = w + 1
        height = h + Layout.bubbleTail + 1
        self.pixels = pixels
    }
}
