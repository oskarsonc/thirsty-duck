import DuckCore
import SwiftUI

/// The duck's art, as tables in the design prototype's form. Rows are strings of color keys, `.` is transparent.
/// Row 0 is the top of the head, rows 12-13 are the feet, and the base body is columns 0-15.
enum Sprite {
    static let size = Layout.sprite
    static let cell = size.width / 16

    struct Pixel {
        let row: Int
        let col: Int
        let color: Color
    }

    /// Art placed with its top left cell at `row`, `col`. Animated art has several frames.
    struct Art {
        let row: Int
        let col: Int
        let frames: [[String]]
        let fps: Double
        let colors: [Character: Color]

        init(_ row: Int, _ col: Int, _ rows: [String], _ colors: [Character: UInt32]) {
            self.init(row, col, fps: 0, [rows], colors.mapValues { Color(hex: $0) })
        }

        init(_ row: Int, _ col: Int, fps: Double, _ frames: [[String]], _ colors: [Character: UInt32]) {
            self.init(row, col, fps: fps, frames, colors.mapValues { Color(hex: $0) })
        }

        init(_ row: Int, _ col: Int, fps: Double = 0, _ frames: [[String]], _ colors: [Character: Color]) {
            self.row = row
            self.col = col
            self.frames = frames
            self.fps = fps
            self.colors = colors
        }

        func pixels(at t: Double) -> [Pixel] {
            let rows = frames[Int(t * fps) % frames.count]
            return rows.enumerated().flatMap { i, line in
                line.enumerated().compactMap { j, ch in
                    ch == "." ? nil : Pixel(row: row + i, col: col + j, color: colors[ch]!)
                }
            }
        }
    }

    typealias Recolor = (_ row: Int, _ col: Int, _ key: Character) -> UInt32?

    struct Paint {
        var colors: [Character: Color]
        /// A color for some cells instead of the plain one. `t` is the look clock in seconds.
        var pattern: ((_ row: Int, _ col: Int, _ key: Character, _ t: Double) -> Color?)?
        var opacity = 1.0
        var sparkles = false

        init(_ y: UInt32, _ d: UInt32, _ o: UInt32, k: UInt32 = 0x2B2B2B, w: UInt32 = 0xFFFFFF, p: UInt32 = 0xFF8FA3,
             opacity: Double = 1, sparkles: Bool = false,
             pattern: ((_ row: Int, _ col: Int, _ key: Character, _ t: Double) -> Color?)? = nil) {
            colors = ["Y": y, "D": d, "O": o, "K": k, "W": w, "P": p, "M": 0xC92A2A].mapValues { Color(hex: $0) }
            self.pattern = pattern
            self.opacity = opacity
            self.sparkles = sparkles
        }
    }

    struct Clothes {
        var recolor: Recolor?
        var back: Art?
        var front: Art?
    }

    struct Held {
        var back: Art?
        var front: Art?
        var hidesHat = false
    }

    // MARK: - Base duck

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

    private static let eyeCells = [(2, 8), (2, 9), (3, 8), (3, 9)]

    private static func eyes(_ eyes: Eyes) -> (clear: Bool, cells: [(Int, Int, Character)]) {
        switch eyes {
        case .open: (false, [])
        case .closed: (true, [(3, 8, "K"), (3, 9, "K")])
        case .happy: (true, [(3, 7, "K"), (2, 8, "K"), (2, 9, "K"), (3, 10, "K")])
        case .x: (true, [(1, 7, "K"), (1, 9, "K"), (2, 8, "K"), (3, 7, "K"), (3, 9, "K")])
        case .wide: (false, [(1, 8, "W"), (1, 9, "W"), (2, 8, "W"), (2, 9, "K"), (3, 8, "W"), (3, 9, "K")])
        case .focus: (true, [(1, 8, "K"), (2, 9, "K"), (3, 8, "K"), (3, 9, "K")])
        }
    }

    private static func feet(_ feet: Feet) -> [(Int, Int)] {
        switch feet {
        case .a: [(12, 5), (12, 6), (13, 4), (13, 5), (13, 6), (12, 9), (12, 10), (13, 8), (13, 9), (13, 10)]
        case .b: [(12, 5), (12, 6), (13, 5), (13, 6), (13, 7), (12, 9), (12, 10), (13, 9), (13, 10)]
        case .kick: [(12, 5), (12, 6), (13, 4), (13, 5), (13, 6), (12, 11), (11, 12), (11, 13)]
        case .hidden: []
        }
    }

    private static let openBeak: [(Int, Int, Character)] = [(4, 11, "M"), (4, 12, "."), (4, 13, "."), (5, 11, "O"), (5, 12, "O")]
    private static let raisedWing = [(7, 5), (7, 6), (6, 4), (6, 3), (5, 2), (5, 3), (4, 2)]

    /// The 16 x 14 body with the pose's eyes, feet, beak and wing.
    static func grid(_ pose: Pose) -> [[Character]] {
        var g = body.map(Array.init) + Array(repeating: Array(repeating: ".", count: 16), count: 2)
        let e = eyes(pose.eyes)
        if e.clear { for (r, c) in eyeCells { g[r][c] = "Y" } }
        for (r, c, ch) in e.cells { g[r][c] = ch }
        for (r, c) in feet(pose.feet) { g[r][c] = "O" }
        if pose.beakOpen { for (r, c, ch) in openBeak { g[r][c] = ch } }
        if pose.wingUp {
            g = g.map { $0.map { $0 == "D" ? "Y" : $0 } }
            for (r, c) in raisedWing { g[r][c] = "D" }
        }
        return g
    }

    /// Every pixel of the duck, back to front, in the prototype's `compose` order.
    static func pixels(_ look: Look, _ pose: Pose, t: Double) -> [Pixel] {
        let paint = paint(look.palette)
        let clothes = look.outfit.map(outfit)
        let item = (pose.item ?? look.item).map(held)
        let hat = item?.hidesHat == true ? nil : look.hat.map(hat)
        var out: [Pixel] = []
        for art in [clothes?.back, item?.back] { out += art?.pixels(at: t) ?? [] }
        for (r, line) in grid(pose).enumerated() {
            for (c, ch) in line.enumerated() where ch != "." {
                let recolor = ch == "Y" || ch == "D" ? clothes?.recolor?(r, c, ch).map { Color(hex: $0) } : nil
                let color = recolor ?? paint.pattern?(r, c, ch, t) ?? paint.colors[ch]!
                out.append(Pixel(row: r, col: c, color: color))
            }
        }
        let fronts = [clothes?.front, (pose.glasses ?? look.glasses).map(glasses), hat, item?.front, pose.bottleFill.map(bottle)]
        for art in fronts { out += art?.pixels(at: t) ?? [] }
        return out
    }

    /// Fills the pixels around the current origin, which is the point under the feet.
    static func fill(_ pixels: [Pixel], in ctx: GraphicsContext, smooth: Bool) {
        // Turned pixels overlap a little, as in the prototype, so no seams show between them.
        let side = smooth ? cell + 0.4 : cell
        for p in pixels {
            let rect = CGRect(x: CGFloat(p.col - 8) * cell, y: CGFloat(p.row - 14) * cell, width: side, height: side)
            ctx.fill(Path(rect), with: .color(p.color), style: FillStyle(antialiased: smooth))
        }
    }

    /// The golden palette's two sparkles, in the same space as `Frame.particles`.
    static func sparkles(t: Double) -> [Particle] {
        (0..<2).map { i in
            let i = Double(i)
            let phase = t * 0.5 + i * 0.5
            let n = phase.rounded(.down)
            return Particle(emoji: "✨", x: (i == 1 ? 28 : -30) + 6 * sin(i * 9 + n * 7),
                            y: 30 + 50 * (i * 0.37 + n * 0.29).truncatingRemainder(dividingBy: 1),
                            size: 11, opacity: sin(.pi * (phase - n)))
        }
    }

    // MARK: - Palettes

    static func paint(_ palette: Palette) -> Paint {
        switch palette {
        case .classic: Paint(0xFFD43B, 0xFAB005, 0xFF922B)
        case .mint: Paint(0xB2F2BB, 0x69DB7C, 0xFF922B)
        case .bubblegum: Paint(0xFFC9DE, 0xF783AC, 0xFF922B, p: 0xF06595)
        case .sky: Paint(0xA5D8FF, 0x4DABF7, 0xFFA94D)
        case .lavender: Paint(0xD0BFFF, 0x9775FA, 0xFFA94D)
        case .peach: Paint(0xFFD8A8, 0xFFA94D, 0xE8590C)
        case .snow: Paint(0xF8F9FA, 0xDEE2E6, 0xFF922B)
        case .charcoal: Paint(0x495057, 0x343A40, 0xFFA94D, k: 0xF8F9FA, w: 0x212529, p: 0xE64980)
        case .lime: Paint(0xD8F5A2, 0xA9E34B, 0xFF922B)
        case .ocean: Paint(0x96F2D7, 0x38D9A9, 0xFF922B)
        case .mallard:
            Paint(0xCED4DA, 0x868E96, 0xFCC419) { r, c, ch, _ in
                if ch == "Y" && r <= 5 { return Color(hex: (r + c) % 5 == 0 ? 0x40C057 : 0x2B8A3E) }
                if ch == "Y" && r == 6 { return Color(hex: 0xFFFFFF) }
                if ch == "Y" && r <= 9 && c >= 9 { return Color(hex: 0xA0522D) }
                if ch == "D" && r == 9 && c >= 6 { return Color(hex: 0x4263EB) }
                return nil
            }
        case .strawberry:
            Paint(0xFF8787, 0xFA5252, 0xFFA94D, p: 0xFFE3E3) { r, c, ch, _ in
                ch == "Y" && (r * 7 + c * 3) % 8 == 0 ? Color(hex: 0xFFF3BF) : nil
            }
        case .sunset:
            Paint(0xFFD43B, 0xF76707, 0xE8590C) { r, _, ch, _ in
                ch == "Y" ? gradient([0xFFD43B, 0xFF8787, 0xDA77F2], Double(r) / 11) : nil
            }
        case .cow:
            Paint(0xF8F9FA, 0xDEE2E6, 0xFFA8A8) { r, c, ch, _ in
                let spot = (7...9 ~= r && 2...4 ~= c) || (9...10 ~= r && 9...10 ~= c) || (r <= 1 && 6...7 ~= c)
                return ch == "Y" && spot ? Color(hex: 0x343A40) : nil
            }
        case .chick: Paint(0xFFF3BF, 0xFFE066, 0xFF922B)
        case .golden:
            Paint(0xFFE066, 0xFAB005, 0xE67700, sparkles: true) { r, c, ch, t in
                ch == "Y" && ((c + r - Int(floor(t * 14))) % 16 + 16) % 16 < 2 ? Color(hex: 0xFFF9DB) : nil
            }
        case .rainbow:
            Paint(0xFFFFFF, 0xFFFFFF, 0xFF922B) { r, _, ch, t in
                guard ch == "Y" || ch == "D" else { return nil }
                let hue = (Double(r) * 28 - t * 120).truncatingRemainder(dividingBy: 360)
                return hsl(hue < 0 ? hue + 360 : hue, ch == "D" ? 0.8 : 0.9, ch == "D" ? 0.6 : 0.72)
            }
        case .galaxy:
            Paint(0x364FC7, 0x2B3A99, 0xFCC419, k: 0xF8F9FA, w: 0x212529, p: 0x9775FA) { r, c, ch, t in
                guard ch == "Y" else { return nil }
                let h = scatter(r, c)
                if h % 7 == 0 && sin(t * 3 + Double(h)) > -0.2 { return Color(hex: 0xFFFFFF) }
                return h % 11 == 1 ? Color(hex: 0x748FFC) : nil
            }
        case .ghost: Paint(0xF1F3F5, 0xCED4DA, 0xFFA94D, opacity: 0.72)
        case .robot:
            Paint(0xCED4DA, 0x868E96, 0xADB5BD, k: 0xFA5252, w: 0xFFC9C9) { r, c, ch, _ in
                let bolt = [(7, 10), (10, 4), (1, 6), (10, 10)].contains { $0 == (r, c) }
                return ch == "Y" && bolt ? Color(hex: 0x495057) : nil
            }
        }
    }

    // MARK: - Hats

    static func hat(_ hat: Hat) -> Art {
        switch hat {
        case .party: Art(-5, 6, ["..w..", "..r..", ".rbr.", ".brb.", "rrbrr"], ["r": 0xF03E3E, "b": 0x4DABF7, "w": 0xFFFFFF])
        case .beanie: Art(-3, 5, ["..ww..", ".rrrr.", "rrrrrr", "wvwvwv"], ["r": 0xFF6B6B, "w": 0xF1F3F5, "v": 0xCED4DA])
        case .topHat: Art(-4, 4, ["..kkkk..", "..kkkk..", "..rrrr..", "kkkkkkkk"], ["k": 0x212529, "r": 0xE03131])
        case .crown: Art(-3, 5, ["g.gg.g", "gggggg", "grgbgg"], ["g": 0xFCC419, "r": 0xE03131, "b": 0x339AF0])
        case .cowboy: Art(-4, 3, ["...nnnn...", "...nnnn...", "n..bbbb..n", ".nnnnnnnn."], ["n": 0xA0522D, "b": 0x5C3317])
        case .cap: Art(-2, 5, ["...w....", ".bbbbb..", "bbbbbbcc"], ["b": 0x1C7ED6, "c": 0x1864AB, "w": 0xFFFFFF])
        case .chef: Art(-5, 5, [".wwww.", "wwwwww", "wgwwgw", ".wwww.", ".gggg."], ["w": 0xFFFFFF, "g": 0xCED4DA])
        case .witch:
            Art(-6, 3, ["......p..", ".....pp..", "....ppp..", "...pppp..", "...gggg..", "ppppppppp"], ["p": 0x5F3DC4, "g": 0x94D82D])
        case .flower: Art(-3, 8, [".p.", "pyp", ".p.", ".g."], ["p": 0xF783AC, "y": 0xFFF3BF, "g": 0x40C057])
        case .bow: Art(-2, 6, ["r...r", "rrkrr", "r...r"], ["r": 0xFF8787, "k": 0xE03131])
        case .propeller:
            Art(-4, 4, fps: 12, ["rrrkbbb", ".rrkbb.", "...k...", ".bbkrr."].map { [$0, "...k...", "..ybr..", ".yybrr."] },
                ["r": 0xF03E3E, "b": 0x339AF0, "y": 0xFCC419, "k": 0x495057])
        case .santa: Art(-4, 4, ["w......", ".rrr...", "..rrrr.", ".rrrrrr", ".wwwwww"], ["r": 0xE03131, "w": 0xFFFFFF])
        case .headphones: Art(-1, 5, [".kkkk.", "k....k", "k.....", "rr....", "rr...."], ["k": 0x343A40, "r": 0xF03E3E])
        case .frog: Art(-3, 5, ["wk..wk", "gggggg", "gggggg", "gggggg"], ["g": 0x69DB7C, "w": 0xFFFFFF, "k": 0x212529])
        case .viking: Art(-3, 3, ["w........w", "ww.ssss.ww", ".wssssssw.", "..ssssss.."], ["w": 0xFFF3BF, "s": 0xADB5BD])
        case .halo:
            // The prototype's halo is still; here it bobs one cell so the look clock has something to move.
            Art(-4, 5, fps: 2, [[".yyyy.", "y....y", ".yyyy.", "......"], ["......", ".yyyy.", "y....y", ".yyyy."]], ["y": 0xFFE066])
        case .sprout: Art(-3, 6, ["ll.ll", ".lgl.", "..g.."], ["l": 0x69DB7C, "g": 0x2F9E44])
        case .gradCap: Art(-3, 4, ["kkkkkkkk.", "..kkkk..y", "..kkkk..y"], ["k": 0x343A40, "y": 0xFCC419])
        case .pirate: Art(-3, 3, ["...kkkk...", ".kkkwkkkk.", "kkkkkkkkkk"], ["k": 0x212529, "w": 0xFFFFFF])
        case .bunny: Art(-5, 5, ["ww..ww", "wp..pw", "wp..pw", "ww..ww", ".kkkk."], ["w": 0xFFFFFF, "p": 0xFFC9DE, "k": 0xF783AC])
        case .bucket: Art(-3, 4, ["..ssss..", ".ssssss.", "tttttttt"], ["s": 0x74C0FC, "t": 0x4DABF7])
        case .sailor: Art(-2, 5, [".wwww.", "bbbbbb"], ["w": 0xFFFFFF, "b": 0x1864AB])
        }
    }

    // MARK: - Glasses

    static func glasses(_ glasses: Glasses) -> Art {
        switch glasses {
        case .round: Art(1, 5, ["...kk.", "kkk..k", "..k..k", "...kk."], ["k": 0x1A1A1A])
        case .sunglasses: Art(2, 5, ["kkkkwk", "..kkkk"], ["k": 0x1A1A1A, "w": 0x868E96])
        case .heart: Art(1, 5, ["..pp.pp", "pppwppp", "..ppppp", "...ppp.", "....p.."], ["p": 0xF06595, "w": 0xFFDEEB])
        case .threeD: Art(1, 5, ["..wwww", "wwwrrb", "..wrrb", "..wwww"], ["w": 0xF8F9FA, "r": 0xFA5252, "b": 0x4DABF7])
        case .monocle: Art(1, 7, [".yy.", "y..y", "y..y", ".yy.", "y...", "y...", ".y.."], ["y": 0xE67700])
        case .nerd: Art(1, 5, ["..kkkk.", "kkk..kw", "..k..k.", "..kkkk."], ["k": 0x1A1A1A, "w": 0xFFFFFF])
        case .star: Art(1, 5, ["....o..", "kkooooo", "...ooo.", "...o.o."], ["o": 0xF76707, "k": 0x1A1A1A])
        case .swimGoggles:
            Art(1, 4, [["....bbb.", "bbbbcccb", "....cccb", "....bbb."]],
                ["b": Color(hex: 0x1971C2), "c": Color(hex: 0xA5D8FF).opacity(0.55)])
        case .skiGoggles: Art(2, 5, ["kkoooy", "kkoooo"], ["k": 0x343A40, "o": 0xFF922B, "y": 0xFFE066])
        case .pixelShades: Art(2, 4, ["kkkkkkkk", "...kwkk.", "....kk.."], ["k": 0x111111, "w": 0xFFFFFF])
        case .eyePatch: Art(0, 5, [".k....", "..k...", "...kkk", "...kkk", ".....k"], ["k": 0x1A1A1A])
        case .catEye: Art(0, 5, ["......p", "...pppp", "ppp..p.", "..p..p.", "...pp.."], ["p": 0xE64980])
        }
    }

    // MARK: - Outfits

    static func outfit(_ outfit: Outfit) -> Clothes {
        switch outfit {
        case .scarf:
            Clothes(front: Art(6, 3, fps: 4, [["rrrwrwrr", "........"], ["..rwrwrr", "rr......"]], ["r": 0xE03131, "w": 0xFFFFFF]))
        case .bowTie:
            Clothes(front: Art(5, 9, ["b.b", "bkb", "b.b"], ["b": 0xE03131, "k": 0xA61E4D]))
        case .tShirt:
            Clothes(recolor: { r, c, ch in 7...10 ~= r && c >= 4 ? (ch == "D" ? 0x1C7ED6 : 0x4DABF7) : nil },
                    front: Art(8, 9, ["r.r", "rrr", ".r."], ["r": 0xFF6B6B]))
        case .stripedSweater:
            Clothes(recolor: { r, c, ch in r >= 6 && c >= 4 ? (ch == "D" ? 0xC92A2A : r % 2 == 1 ? 0xFA5252 : 0xF8F9FA) : nil })
        case .hoodie:
            Clothes(recolor: { r, c, ch in r >= 6 && c >= 4 ? (ch == "D" ? 0x495057 : 0x868E96) : nil },
                    back: Art(0, 3, ["..hh", ".hhh", "hhhh", "hhhh", "hhhh", ".hhh", "..hh"], ["h": 0x868E96]),
                    front: Art(7, 10, ["w", "w"], ["w": 0xF8F9FA]))
        case .raincoat:
            Clothes(recolor: { r, c, ch in r >= 6 && c >= 4 ? (ch == "D" ? 0xC92A2A : 0xF03E3E) : nil },
                    front: Art(7, 11, ["k", ".", "k"], ["k": 0xFFFFFF]))
        case .sailorTop:
            Clothes(recolor: { r, c, ch in
                        guard c >= 4 else { return nil }
                        if r == 6 { return 0x1864AB }
                        return r >= 7 ? (ch == "D" ? 0xDEE2E6 : r == 9 ? 0x1C7ED6 : 0xF8F9FA) : nil
                    },
                    front: Art(7, 10, ["rr", ".r"], ["r": 0xE03131]))
        case .lifeJacket:
            Clothes(recolor: { r, c, ch in 6...10 ~= r && c >= 4 ? (r == 9 ? 0x343A40 : ch == "D" ? 0xE8590C : 0xFD7E14) : nil },
                    front: Art(7, 11, ["w"], ["w": 0xF8F9FA]))
        case .cape:
            Clothes(front: Art(6, -1, fps: 5, [
                ["....cc", "...ccc", "..cccc", ".ccccc", ".ccccc", "cccccc", "ccccc."],
                ["....cc", "...ccc", "..cccc", ".ccccc", "cccccc", "ccccc.", "cccc.."],
            ], ["c": 0xE03131]))
        case .tutu:
            Clothes(front: Art(10, 1, [".tttttttttttt", "tptptptptptpt"], ["t": 0xFFDEEB, "p": 0xF783AC]))
        case .swimRing:
            Clothes(front: Art(9, 0, ["rwwrrwwrrwwrrw", ".rrwwrrwwrrww."], ["r": 0xFA5252, "w": 0xF8F9FA]))
        case .overalls:
            Clothes(recolor: { r, c, ch in
                        let denim: UInt32 = 0x4C6EF5
                        if ch == "D" { return nil }
                        if r >= 10 && c >= 2 { return denim }
                        if r == 9 && c >= 9 { return denim }
                        return 7...8 ~= r && 9...11 ~= c ? denim : nil
                    },
                    front: Art(7, 10, ["y"], ["y": 0xFCC419]))
        case .hawaiianShirt:
            Clothes(recolor: { r, c, ch in
                guard 6...10 ~= r && c >= 4 else { return nil }
                if ch == "D" { return (r + c) % 3 == 0 ? 0xFFF3BF : 0x0CA678 }
                return (r * 3 + c) % 5 == 0 ? 0xFF8787 : (r + c) % 4 == 0 ? 0xFFF3BF : 0x20C997
            })
        case .tie:
            Clothes(front: Art(6, 9, ["wk", ".r", "..r", "..r", "..r"], ["w": 0xF8F9FA, "k": 0xA61E4D, "r": 0xE03131]))
        case .tuxedo:
            Clothes(recolor: { r, c, ch in r >= 6 ? (c >= 10 && r <= 10 && ch != "D" ? 0xF8F9FA : ch == "D" ? 0x343A40 : 0x212529) : nil },
                    front: Art(6, 10, ["kk"], ["k": 0x111111]))
        case .goldChain:
            Clothes(front: Art(6, 5, ["y.y.y.", ".....y", ".....g"], ["y": 0xE67700, "g": 0xFFE066]))
        case .bandana:
            Clothes(front: Art(6, 5, ["bwbbwb", "....bb", ".....b"], ["b": 0xE03131, "w": 0xFFFFFF]))
        case .backpack:
            Clothes(front: Art(6, 1, [".gggg", "ggggg", "gyggg", "ggggg", ".ggg."], ["g": 0x40C057, "y": 0x2F9E44]))
        }
    }

    // MARK: - Things to hold

    static func held(_ item: HeldItem) -> Held {
        switch item {
        case .waterBottle:
            Held(front: Art(5, 12, [".c.", "bbb", "bwb", "bwb", "bwb", "bbb"], ["c": 0x1C7ED6, "b": 0xD0EBFF, "w": 0x4DABF7]))
        case .glassOfWater:
            Held(front: Art(5, 13, ["..r", ".r.", "grg", "gwg", "gwg", "ggg"], ["r": 0xFF6B6B, "g": 0xCED4DA, "w": 0x74C0FC]))
        case .umbrella:
            Held(front: Art(-7, 2, ["....rrr....", "..rrrrrrr..", ".rrwrrrwrr.", "rrrrrrrrrrr", ".....k.....", ".....k....."],
                            ["r": 0x7950F2, "w": 0xB197FC, "k": 0x495057]),
                 hidesHat: true)
        case .balloon:
            Held(back: Art(-8, 12, [".rr.", "rwrr", "rrrr", ".rr.", "..k.", "..k.", ".k..", ".k..", "k...", "k..."],
                           ["r": 0xFF6B6B, "w": 0xFFC9C9, "k": 0x868E96]))
        case .flower:
            Held(front: Art(1, 13, [".p.", "pyp", "gp."], ["p": 0xF783AC, "y": 0xFFE066, "g": 0x40C057]))
        case .lollipop:
            Held(front: Art(0, 13, ["rwr", "wrw", "rwr", ".s."], ["r": 0xF06595, "w": 0xFFFFFF, "s": 0xDEE2E6]))
        case .fish:
            Held(front: Art(3, 13, ["bbkbb.b", ".bbbbbb"], ["b": 0x74C0FC, "k": 0x212529]))
        case .skateboard:
            Held(front: Art(13, 1, ["d............d", ".dddddddddddd.", "...w......w..."], ["d": 0xE8590C, "w": 0x495057]))
        case .duckling:
            Held(back: Art(8, -6, ["..yy..", ".yyyko", ".yyy..", "yyyyy.", "yyyyy.", ".o.o.."],
                           ["y": 0xFFE066, "k": 0x2B2B2B, "o": 0xFF922B]))
        }
    }

    /// The drink move's bottle, with `fill` (0...5) cells of water left.
    static func bottle(_ fill: Int) -> Art {
        Art(2, 13, [".bbbbb", "n" + String(repeating: "w", count: fill) + String(repeating: "e", count: 5 - fill), ".bbbbb"],
            ["b": 0xA5D8FF, "w": 0x339AF0, "e": 0xE7F5FF, "n": 0x1C7ED6])
    }

    // MARK: - Color helpers

    private static func gradient(_ stops: [UInt32], _ f: Double) -> Color {
        let f = max(0, min(1, f)) * Double(stops.count - 1)
        let i = min(Int(f), stops.count - 2)
        let a = rgb(stops[i]), b = rgb(stops[i + 1])
        let mixed = (0..<3).map { ((a[$0] + (b[$0] - a[$0]) * (f - Double(i))).rounded()) / 255 }
        return Color(.sRGB, red: mixed[0], green: mixed[1], blue: mixed[2])
    }

    private static func rgb(_ hex: UInt32) -> [Double] {
        [Double((hex >> 16) & 0xFF), Double((hex >> 8) & 0xFF), Double(hex & 0xFF)]
    }

    /// CSS `hsl()`: hue in degrees, saturation and lightness 0...1.
    private static func hsl(_ h: Double, _ s: Double, _ l: Double) -> Color {
        let a = s * min(l, 1 - l)
        func f(_ n: Double) -> Double {
            let k = (n + h / 30).truncatingRemainder(dividingBy: 12)
            return l - a * max(-1, min(k - 3, 9 - k, 1))
        }
        return Color(.sRGB, red: f(0), green: f(8), blue: f(4))
    }

    /// The prototype's cell hash for the galaxy stars, with JavaScript's 32-bit integer math.
    private static func scatter(_ r: Int, _ c: Int) -> UInt32 {
        UInt32(truncatingIfNeeded: (r + 20) * 73_856_093) ^ UInt32(truncatingIfNeeded: (c + 20) * 19_349_663)
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
