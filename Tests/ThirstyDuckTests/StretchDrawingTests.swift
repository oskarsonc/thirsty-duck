import CoreGraphics
import Foundation
import Testing
@testable import DuckCore
@testable import ThirstyDuck

@Test(arguments: [Trick.reachUp, .sideBend, .toeTouch], [false, true])
func stretchingArtTouchesTheMat(trick: Trick, facingRight: Bool) throws {
    let now = Date(timeIntervalSinceReferenceDate: 0)
    var duck = Duck(timings: .fast, seed: 7)
    let screen = CGRect(x: 0, y: 0, width: facingRight ? 200 : 1440, height: 900)
    duck.step(now: now, sensors: Sensors(idleSeconds: 0, mouse: .zero, screens: [Screen(frame: screen, visible: screen)]), input: .stretchNow)
    // Fix the look and phase to sample the art throughout each move, without random selection.
    duck.phase = .waiting(.stretch(.remind), trick)
    duck.phaseStart = now
    for sample in 0...100 {
        var frame = duck.frame(at: now + trick.duration * Double(sample) / 100)
        frame.look = .classic
        frame.pose.mirrored = !facingRight
        let transform = Layout.spriteTransform(frame.pose)
        let overlap: CGFloat = frame.pose.tilt != 0 ? 0.4 : 0
        let bottom = try #require(Sprite.pixels(frame.look, frame.pose, sweatband: true, t: 0).map { pixel in
            CGRect(x: CGFloat(pixel.col - 8) * Sprite.cell, y: CGFloat(pixel.row - 14) * Sprite.cell,
                   width: Sprite.cell + overlap, height: Sprite.cell + overlap).applying(transform).maxY
        }.max())
        let groundY = Layout.panel.height - Layout.ground
        #expect(bottom >= groundY - Layout.matHeight - 0.0001, "art must touch the mat")
        let clip = try #require(Layout.spriteClip(frame))
        #expect(bottom <= groundY + 0.0001, "no sprite art is cut at the ground line")
        #expect(clip.maxY == groundY)
        let hit = try #require(Layout.hitRegions(frame, bubble: nil).first)
        #expect(hit.minY >= Layout.ground - 0.0001)
    }
}

@Test func defaultCalendarsFollowATimeZoneChange() {
    let defaults = UserDefaults.standard
    let arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
    let original = NSTimeZone.default
    defer {
        NSTimeZone.default = original
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
    }
    var choices = arguments
    choices["startHour"] = 8
    choices["endHour"] = 23
    choices["weekends"] = true
    defaults.setVolatileDomain(choices, forName: UserDefaults.argumentDomain)
    NSTimeZone.default = TimeZone(identifier: "Europe/Ljubljana")!
    let hours = WorkHours()
    let settingsHours = Settings.workHours
    let normalHours = Timings.normal.workHours!
    var timings = Timings.fast
    timings.reminderInterval = 100_000
    timings.stretchAt = 12 * 60
    let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let sensors = Sensors(idleSeconds: 0, mouse: .zero, screens: [Screen(frame: screen, visible: screen)])
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let morning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 7))!
    for retained in [nil, hours, settingsHours, normalHours] {
        NSTimeZone.default = TimeZone(identifier: "Europe/Ljubljana")!
        var t = timings
        t.workHours = retained
        var duck = Duck(timings: t, seed: 7)
        duck.step(now: morning - 3600, sensors: sensors)
        NSTimeZone.default = calendar.timeZone
        if let retained {
            #expect(!retained.contains(morning), "07:00 is before work in the new time zone")
            #expect(retained.nextStart(after: morning) == morning + 3600)
        }
        duck.step(now: morning + 3 * 3600, sensors: sensors)
        duck.step(now: morning + 3 * 3600 + 1, sensors: sensors)
        #expect(duck.phase == .hidden, "10:00 is before the stretch in the new time zone")
        NSTimeZone.default = TimeZone(identifier: "Europe/Ljubljana")!
        duck.step(now: morning + 3 * 3600 + 2, sensors: sensors)
        #expect(duck.phase == .entering(.stretch(.remind)), "the same instant is after noon in Ljubljana")
    }
}
