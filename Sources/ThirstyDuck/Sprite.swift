import DuckCore
import SwiftUI

enum Sprite {
    static let size = Layout.sprite
    static let cell = size.width / 16

    private static let body = [
        "......YYYY......",
        ".....YYYYYY.....",
        ".....YYYWKY.....",
        ".....YYYKKYOOO..",
        ".....YYPYYYOOO..",
        "......YYYYY.....",
        ".Y...YYYYYY.....",
        ".YY.YYYYYYYY....",
        ".YYYYYDDDYYYY...",
        ".YYYYDDDDYYYY...",
        "..YYYYYYYYYYY...",
        "...YYYYYYYYY....",
    ]

    private static let colors: [Character: Color] = [
        "Y": Color(hex: 0xFFD43B),
        "D": Color(hex: 0xFAB005),
        "O": Color(hex: 0xFF922B),
        "K": Color(hex: 0x2B2B2B),
        "W": Color(hex: 0xFFFFFF),
        "P": Color(hex: 0xFF8FA3),
    ]

    private static let feet: [[(Int, Int)]] = [
        [(12, 5), (12, 6), (13, 4), (13, 5), (13, 6), (12, 9), (12, 10), (13, 8), (13, 9), (13, 10)],
        [(12, 5), (12, 6), (13, 5), (13, 6), (13, 7), (12, 9), (12, 10), (13, 9), (13, 10)],
    ]

    private static let eyeCells = [(2, 8), (2, 9), (3, 8), (3, 9)]

    static func grid(eyes: Eyes, step: Int) -> [[Character]] {
        var g = body.map(Array.init) + Array(repeating: Array(repeating: ".", count: 16), count: 2)
        switch eyes {
        case .open, .x, .wide, .focus:
            break
        case .closed:
            for (r, c) in eyeCells { g[r][c] = "Y" }
            for (r, c) in [(3, 8), (3, 9)] { g[r][c] = "K" }
        case .happy:
            for (r, c) in eyeCells { g[r][c] = "Y" }
            for (r, c) in [(3, 7), (2, 8), (2, 9), (3, 10)] { g[r][c] = "K" }
        }
        for (r, c) in feet[step] { g[r][c] = "O" }
        return g
    }

    static func paths(eyes: Eyes, step: Int) -> [(Color, Path)] {
        var byColor: [Character: Path] = [:]
        for (r, row) in grid(eyes: eyes, step: step).enumerated() {
            for (c, ch) in row.enumerated() where ch != "." {
                byColor[ch, default: Path()].addRect(CGRect(x: CGFloat(c) * cell, y: CGFloat(r) * cell, width: cell, height: cell))
            }
        }
        return byColor.map { (colors[$0.key]!, $0.value) }
    }
}

struct SpriteView: View {
    let eyes: Eyes
    let step: Int

    var body: some View {
        Canvas { ctx, _ in
            for (color, path) in Sprite.paths(eyes: eyes, step: step) {
                ctx.fill(path, with: .color(color), style: FillStyle(antialiased: false))
            }
        }
        .frame(width: Sprite.size.width, height: Sprite.size.height)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
