import CoreGraphics
import Foundation
import Testing
@testable import DuckCore

/// Every bubble the duck can show: each stage, each move's speech over its whole run, even where the stage
/// bubble hides it, and the thank you.
func allBubbleTexts() -> Set<String> {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    var duck = Duck(timings: .normal, seed: 1)
    duck.phaseStart = start
    var texts = Set<String>()
    func sample(_ phase: DuckPhase, for seconds: TimeInterval) {
        duck.phase = phase
        for t in stride(from: 0, through: seconds, by: 0.01) {
            if let b = duck.bubble(at: start + t) { texts.insert(b.text) }
            if let speech = Pose(duck: duck, now: start + t).speech { texts.insert(speech) }
        }
    }
    for thirst in [Thirst.chill, .ask, .thirsty, .follow] {
        sample(.waiting(thirst, nil), for: Motion.chillBubbleCycle)
        for trick in thirst.oldTricks + thirst.newTricks { sample(.waiting(thirst, trick), for: trick.duration) }
    }
    sample(.happy, for: 0)
    return texts
}

@Test func everyBubbleCharacterHasAGlyph() {
    let texts = allBubbleTexts()
    #expect(texts.isSuperset(of: ["💧?", "drink! 💧", "so thirsty… 💧💧", "DRINK WATER! 🥵", "thank you! 💛",
                                  "hi!", "yaawn", "achoo!", "quack!", "glug glug", "ahh 💙", "💪", "brrr", "boo!", "oops!"]))
    for text in texts {
        for c in text {
            #expect(PixelFont.glyph(c) != nil, "no glyph for \(c) in \(text)")
        }
    }
}

@Test func glyphsAreSevenRowsOfOneWidth() {
    for (c, rows) in PixelFont.glyphs {
        #expect(rows.count == PixelFont.height, "\(c)")
        #expect(Set(rows.map(\.count)).count == 1, "\(c)")
        for ch in rows.joined() where ch != "." && ch != "#" {
            #expect(PixelFont.colors[ch] != nil, "\(c) uses \(ch)")
        }
    }
}

@Test func lowercaseDrawsAsUppercase() {
    #expect(PixelFont.glyph("q") == PixelFont.glyph("Q"))
    #expect(PixelFont.width("quack!") == PixelFont.width("QUACK!"))
}
