import CoreGraphics
import Foundation
import Testing
@testable import DuckCore

private func stretchSim(hour: Int = 11) -> Sim {
    var timings = Timings.test
    timings.reminderInterval = 100 * 24 * 60 * minute
    timings.stretchAt = 12 * 60
    return Sim(timings: timings, hour: hour)
}

private extension Sim {
    mutating func nextStretchMove(_ level: StretchLevel) -> Trick? {
        for _ in 0..<400 {
            if case .waiting(.stretch(level), let trick?) = duck.phase { return trick }
            run(0.01, every: 0.01)
        }
        Issue.record("no stretch move started")
        return nil
    }

    mutating func finishStretchMove(_ level: StretchLevel) {
        guard case .waiting(let visit, let trick?) = duck.phase else { return }
        run(max(0, (duck.phaseStart + visit.duration(of: trick)).timeIntervalSince(time.now)) + 0.001, every: 0.01)
        #expect(duck.phase == .waiting(.stretch(level), nil))
    }
}

@Test func stretchComesAtTheWallClockTimeAndNotBefore() {
    var sim = stretchSim()
    sim.run(60 * minute - 1)
    #expect(sim.duck.phase == .hidden)
    sim.run(1)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
    #expect(sim.duck.stretchDoneDay == nil)
    #expect(sim.duck.frame(at: sim.time.now).sweatband)
    #expect(!sim.duck.frame(at: sim.time.now).mat)
    #expect(sim.duck.status(at: sim.time.now) == .here)
}

@Test func stretchWaitsForAVisibleWaterDuck() {
    var sim = stretchSim()
    sim.send(.callNow)
    sim.run(60 * minute)
    #expect(sim.thirst != nil)
    #expect(!sim.duck.frame(at: sim.time.now).sweatband)
    sim.send(.click)
    #expect(sim.duck.stretchDoneDay == nil)
    sim.run(until: .hidden)
    sim.run(0.1, every: 0.1)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
}

@Test func stretchComesFirstWhenBothRemindersAreDue() {
    var sim = stretchSim()
    sim.duck.timings.reminderInterval = 60 * minute
    sim.run(60 * minute)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
    sim.send(.click)
    sim.run(until: .hidden)
    sim.run(0.1, every: 0.1)
    #expect(sim.duck.phase == .entering(.water(.chill)))
}

@Test func awayAtStretchTimeWaitsUntilTheUserReturns() {
    var sim = stretchSim()
    sim.run(50 * minute)
    sim.run(11 * minute, idle: true)
    #expect(sim.duck.phase == .hidden)
    sim.run(1)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
}

@Test func aMissedStretchDayDoesNotCarryIntoTheNextMorning() {
    var sim = stretchSim()
    sim.run(50 * minute)
    sim.run(22 * 60 * minute + 10 * minute, idle: true)
    #expect(sim.duck.phase == .hidden)
    #expect(sim.duck.stretchDoneDay == nil)
    sim.run(1)
    sim.run(1)
    #expect(sim.duck.phase == .hidden)
    sim.run(2 * 60 * minute - 2)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
}

@Test func stretchNeverStartsOutsideWorkHours() {
    var sim = stretchSim(hour: 23)
    sim.run(9 * 60 * minute - 1)
    #expect(sim.duck.phase == .hidden)
    sim.run(1)
    #expect(sim.duck.phase == .hidden)
    sim.run(4 * 60 * minute)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
}

@Test func aStretchTimeAfterWorkEndsIsSkipped() {
    var sim = stretchSim(hour: 22)
    sim.duck.timings.stretchAt = 23 * 60 + 30
    sim.run(2 * 60 * minute)
    #expect(sim.duck.phase == .hidden)
    sim.run(23 * 60 * minute)
    #expect(sim.duck.phase == .hidden)
    #expect(sim.duck.stretchDoneDay == nil)
}

@Test func aStretchClickMarksOnlyTodayAndTheNextDayComesAgain() {
    var sim = stretchSim()
    sim.run(60 * minute)
    let calendar = sim.duck.timings.workHours!.calendar
    sim.send(.click)
    let today = calendar.startOfDay(for: sim.time.now)
    #expect(sim.duck.stretchDoneDay == today)
    #expect(sim.duck.phase.isHappy)
    let frame = sim.duck.frame(at: sim.time.now + 0.2)
    #expect(frame.sweatband)
    #expect(!frame.mat)
    #expect(frame.bubble?.text == "nice! 💪")
    #expect(frame.pose.eyes == .happy)
    #expect(frame.pose.lift > 0)
    sim.run(until: .hidden)
    sim.run(60 * minute)
    #expect(sim.duck.phase == .hidden)
    sim.run(23 * 60 * minute)
    #expect(sim.duck.phase.visit == .stretch(.remind))
    #expect(sim.duck.stretchDoneDay == today)
}

@Test func aRestoredDoneDayPreventsAnotherDailyVisit() {
    var sim = stretchSim()
    let today = sim.duck.timings.workHours!.calendar.startOfDay(for: sim.time.now)
    sim.duck.stretchDoneDay = today
    sim.run(2 * 60 * minute)
    #expect(sim.duck.phase == .hidden)
    sim.duck.stretchDoneDay = today - 24 * 60 * minute
    sim.run(1)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
}

@Test func aLongBreakHidesStretchWithoutMarkingItDone() {
    var sim = stretchSim()
    sim.run(60 * minute)
    sim.run(31 * minute, idle: true)
    #expect(sim.duck.phase == .hidden)
    #expect(sim.duck.stretchDoneDay == nil)
    sim.run(1)
    sim.run(1)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
}

@Test func workEndSendsStretchAwayWithoutMarkingItDone() {
    var sim = stretchSim()
    sim.run(60 * minute)
    sim.run(until: .waiting(.stretch(.remind), nil))
    sim.duck.timings.workHours?.endHour = 12
    sim.run(0.1, every: 0.1)
    #expect(sim.duck.phase.isLeaving)
    #expect(sim.duck.frame(at: sim.time.now).sweatband)
    #expect(sim.duck.stretchDoneDay == nil)
    sim.run(until: .hidden)
    sim.run(60)
    #expect(sim.duck.phase == .hidden)
    sim.duck.timings.workHours?.endHour = 23
    sim.run(1)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
}

@Test func screenChangeDuringDepartureKeepsStretchCompletion() {
    var sim = stretchSim()
    sim.run(60 * minute)
    sim.send(.click)
    let done = sim.duck.stretchDoneDay
    let smaller = CGRect(x: 0, y: 0, width: 1280, height: 800)
    sim.sensors.screens = [Screen(frame: smaller, visible: smaller)]
    sim.run(0.1, every: 0.1)
    #expect(sim.duck.phase == .hidden)
    #expect(sim.duck.stretchDoneDay == done)
    sim.run(1)
    #expect(sim.duck.phase == .hidden)
}

@Test func stretchNowWorksWhenOffAndAfterTodaysCompletion() {
    var sim = Sim(timings: .fast, hour: 23)
    sim.send(.stretchNow)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
    let workTime = sim.duck.workTime
    sim.send(.stretchNow)
    #expect(sim.duck.workTime == workTime)
    sim.send(.click)
    #expect(sim.duck.stretchDoneDay != nil)
    sim.run(until: .hidden)
    sim.send(.stretchNow)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
}

@Test func manualCallsSelectTheirVisitEvenWhenTheOtherReminderIsDue() {
    var sim = stretchSim()
    sim.duck.timings.reminderInterval = 1
    sim.time.now += 1
    sim.send(.stretchNow)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
    var water = stretchSim()
    water.duck.timings.stretchAt = 11 * 60
    water.send(.callNow)
    #expect(water.duck.phase == .entering(.water(.chill)))
}

@Test func aStretchClickDoesNotResetTheRunningWaterClock() {
    var sim = stretchSim()
    sim.duck.timings.reminderInterval = 65 * minute
    sim.run(60 * minute)
    sim.run(6 * minute, every: 0.1)
    let before = sim.duck.workTime
    sim.time.now += 0.5
    sim.send(.click)
    #expect(sim.duck.workTime == before + 0.5)
    sim.run(until: .hidden)
    sim.run(0.1, every: 0.1)
    #expect(sim.duck.phase == .entering(.water(.chill)))
    #expect(sim.duck.status(at: sim.time.now) == .here)
}

@Test func stretchLevelsUseTheirOwnBubblesAndDrawingFlags() {
    var sim = stretchSim()
    sim.run(60 * minute)
    sim.run(2.1, every: 0.02)
    #expect(sim.duck.frame(at: sim.time.now).bubble?.text == "stretch time! 🙆")
    sim.run(until: .waiting(.stretch(.remind), nil))
    let home = sim.duck.position
    #expect(sim.duck.frame(at: sim.time.now).mat)
    sim.run(5 * minute - sim.time.now.timeIntervalSince(sim.duck.shownAt), every: 0.1)
    #expect(sim.duck.phase.visit == .stretch(.insist))
    var frame = sim.duck.frame(at: sim.time.now)
    #expect(frame.bubble?.text == "come on, stretch!")
    #expect(frame.sweatband && frame.mat)
    #expect(frame.effect == .none)
    #expect(sim.duck.position == home)
    sim.run(5 * minute, every: 0.1)
    #expect(sim.duck.phase == .moving(.stretch(.follow)))
    frame = sim.duck.frame(at: sim.time.now)
    #expect(frame.bubble?.text == "STRETCH NOW!")
    #expect(frame.sweatband && !frame.mat)
    #expect(frame.effect == .none)
    sim.run(until: .waiting(.stretch(.follow), .reachUp))
    #expect(sim.duck.position == CGPoint(x: 300 + Motion.followGap, y: 500 - Motion.followDrop))
    #expect(!sim.duck.facingRight)
    frame = sim.duck.frame(at: sim.duck.phaseStart + 1.2)
    #expect(frame.pose.wingUp)
    #expect(frame.pose.scaleY > 1)
    #expect(frame.effect == .none)
    #expect(!frame.mat)
    let spot = sim.duck.position
    sim.sensors.mouse = spot
    sim.run(0.5, every: 0.1)
    #expect(sim.duck.position == spot)
    sim.sensors.mouse = CGPoint(x: 1200, y: 600)
    sim.run(0.1, every: 0.1)
    #expect(sim.duck.phase == .moving(.stretch(.follow)))
}

@Test func stretchSleepsAndItsLevelClockStopsWhileAway() {
    var sim = stretchSim()
    sim.run(60 * minute)
    sim.run(2 * minute, every: 0.1)
    sim.duck.timings.awayAfter = 1
    sim.run(20, idle: true)
    #expect(sim.duck.phase == .asleep(.stretch(.remind)))
    let work = sim.duck.workTime
    let asleep = sim.duck.frame(at: sim.time.now)
    #expect(asleep.pose.eyes == .closed)
    #expect(asleep.bubble == nil)
    if case .snooze = asleep.effect {} else { Issue.record("stretch should sleep") }
    #expect(asleep.sweatband)
    sim.run(10 * minute, idle: true)
    #expect(sim.duck.workTime == work)
    sim.run(0.1, every: 0.1)
    #expect(sim.duck.phase == .moving(.stretch(.remind)))
    sim.sleep(10 * minute)
    #expect(sim.duck.phase.visit == .stretch(.remind))
    #expect(sim.duck.workTime <= work + 0.1)
    sim.sleep(31 * minute)
    #expect(sim.duck.phase == .hidden)
    #expect(sim.duck.stretchDoneDay == nil)
    sim.run(0.1, every: 0.1)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
}

@Test func stretchLooksHaveNoHatOrItemAndNewLookStillSpins() {
    var sim = stretchSim()
    sim.send(.stretchNow)
    for _ in 0..<100 {
        let previous = sim.duck.look
        sim.send(.newLook)
        #expect(sim.duck.look != previous)
        #expect(sim.duck.look.hat == nil)
        #expect(sim.duck.look.item == nil)
    }
    sim.run(until: .waiting(.stretch(.remind), nil))
    let previous = sim.duck.look
    sim.send(.newLook)
    #expect(sim.duck.look != previous)
    #expect(sim.duck.phase == .waiting(.stretch(.remind), .spin))
    sim.send(.click)
    #expect(sim.duck.frame(at: sim.time.now).sweatband)
    #expect(sim.duck.look.hat == nil && sim.duck.look.item == nil)
}

@Test(arguments: [StretchLevel.remind, .insist])
func stretchPicksOnlyItsThreeMovesWithoutRepeats(level: StretchLevel) {
    var sim = stretchSim()
    sim.duck.timings.levelStep = 10_000
    sim.send(.stretchNow)
    sim.run(Double(level.rawValue - 1) * sim.duck.timings.levelStep)
    sim.run(until: .waiting(.stretch(level), nil))
    var seen = [Trick]()
    for _ in 0..<100 {
        let start = sim.time.now
        guard let trick = sim.nextStretchMove(level) else { return }
        #expect([Trick.reachUp, .sideBend, .toeTouch].contains(trick))
        #expect(trick != seen.last)
        seen.append(trick)
        let gap = sim.duck.phaseStart.timeIntervalSince(start)
        let range = level == .remind ? 1.49...3.01 : 0.49...1.01
        #expect(range.contains(gap))
        let duration = trick.duration / (level == .insist ? 1.5 : 1)
        let remaining = (sim.duck.phaseStart + duration - 0.01).timeIntervalSince(sim.time.now)
        sim.run(remaining, every: 0.01)
        #expect(sim.duck.phase == .waiting(.stretch(level), trick))
        sim.run(0.02, every: 0.01)
        #expect(sim.duck.phase == .waiting(.stretch(level), nil))
        #expect(sim.duck.frame(at: sim.time.now).effect == .none)
    }
    #expect(Set(seen.map { String(describing: $0) }).count == 3)
}

@Test(arguments: [Trick.reachUp, .sideBend, .toeTouch], [false, true])
func stretchPosesMatchThePrototypeAndStayAboveGround(trick: Trick, facingRight: Bool) {
    var sim = stretchSim()
    if facingRight {
        let narrow = CGRect(x: 0, y: 0, width: 200, height: 900)
        sim.sensors.screens = [Screen(frame: narrow, visible: narrow)]
    }
    sim.send(.stretchNow)
    sim.run(until: .waiting(.stretch(.remind), nil))
    for _ in 0..<100 {
        if sim.nextStretchMove(.remind) == trick { break }
        sim.finishStretchMove(.remind)
    }
    #expect(sim.duck.phase == .waiting(.stretch(.remind), trick))
    #expect(sim.duck.facingRight == facingRight)
    for sample in 0...100 {
        let frame = sim.duck.frame(at: sim.duck.phaseStart + trick.duration * Double(sample) / 100)
        var art = CGRect(x: -40, y: -70, width: 80, height: 70)
        if frame.pose.tilt != 0 {
            art.size.width += 0.4
            art.size.height += 0.4
        }
        let drawn = art.applying(Layout.spriteTransform(frame.pose))
        #expect(drawn.maxY <= Layout.panel.height - Layout.ground + 0.0001)
        #expect(frame.sweatband && frame.mat)
        #expect(frame.effect == .none)
    }
    let progress = trick == .sideBend ? 0.25 : 0.5
    let pose = sim.duck.frame(at: sim.duck.phaseStart + trick.duration * progress).pose
    switch trick {
    case .reachUp:
        #expect(abs(pose.scaleY - 1.16) < 0.0001)
        #expect(abs(pose.scaleX - 0.93) < 0.0001)
        #expect(pose.wingUp && pose.eyes == .closed)
    case .sideBend:
        #expect(abs(pose.tilt + 16) < 0.0001)
        #expect(pose.wingUp)
    case .toeTouch:
        #expect(abs(pose.tilt - 30) < 0.0001)
        #expect(abs(pose.scaleY - 0.92) < 0.0001)
        #expect(pose.eyes == .closed)
    default: Issue.record("unexpected stretch move")
    }
}

@Test(arguments: [CGPoint(x: 2, y: 898), CGPoint(x: 1438, y: 898), CGPoint(x: 2, y: 2), CGPoint(x: 1438, y: 2)])
func stretchFollowFitsItsBubbleAndReturnsFromARemovedScreen(mouse: CGPoint) {
    var sim = stretchSim()
    sim.send(.stretchNow)
    sim.run(10 * minute)
    sim.sensors.mouse = mouse
    sim.run(until: .waiting(.stretch(.follow), .reachUp))
    let screen = sim.sensors.screens[0]
    for text in ["DRINK WATER! 🥵", "STRETCH NOW!"] {
        for sample in 0...70 {
            let frame = sim.duck.frame(at: sim.time.now + Double(sample) / 100)
            let bubble = Layout.hitRegions(frame, bubble: Layout.bubbleSize(text)).last!
                .offsetBy(dx: sim.duck.position.x - Layout.panel.width / 2, dy: sim.duck.position.y - Layout.ground)
            #expect(screen.frame.contains(bubble))
            #expect(bubble.maxY <= screen.visible.maxY)
        }
    }
    let external = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    sim.sensors.screens.append(Screen(frame: external, visible: external))
    sim.sensors.mouse = CGPoint(x: 1700, y: 500)
    sim.run(20, every: 0.02)
    #expect(external.contains(sim.duck.position))
    sim.sensors.screens.removeLast()
    sim.sensors.mouse = mouse
    sim.run(20, every: 0.02)
    #expect(screen.frame.contains(sim.duck.position))
    #expect(sim.duck.phase.visit == .stretch(.follow))
}

@Test func stretchUsesTheWorkHoursCalendarForTimeAndDoneDay() {
    var sim = stretchSim()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Pacific/Auckland")!
    sim.duck.timings.workHours = WorkHours(calendar: calendar)
    sim.time.now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 13, hour: 11, minute: 59))!
    sim.send(.tick)
    sim.run(59)
    #expect(sim.duck.phase == .hidden)
    sim.run(1)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
    sim.send(.click)
    #expect(sim.duck.stretchDoneDay == calendar.date(from: DateComponents(year: 2026, month: 11, day: 13)))
}

@Test func normalStretchDefaultsToNoonAndFastTurnsItOff() {
    #expect(Timings.normal.stretchAt == 12 * 60)
    #expect(Timings.fast.stretchAt == nil)
    var sim = stretchSim()
    sim.duck.timings.stretchAt = nil
    sim.run(2 * 60 * minute)
    #expect(sim.duck.phase == .hidden)
    #expect(sim.duck.status(at: sim.time.now) == .nextIn(sim.duck.timings.reminderInterval - sim.duck.workTime))
}

@Test func stretchFollowKeepsPickingReachUpWithoutSweatOrAMat() {
    var sim = stretchSim()
    sim.send(.stretchNow)
    sim.run(10 * minute)
    sim.run(until: .waiting(.stretch(.follow), .reachUp))
    for _ in 0..<10 {
        #expect(sim.nextStretchMove(.follow) == .reachUp)
        let frame = sim.duck.frame(at: sim.time.now)
        #expect(frame.effect == .none)
        #expect(frame.sweatband && !frame.mat)
        sim.finishStretchMove(.follow)
    }
}

@Test(arguments: [(3, 29), (10, 25)])
func stretchKeepsNoonOnDaylightSavingDays(month: Int, day: Int) {
    var sim = stretchSim()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Ljubljana")!
    sim.duck.timings.workHours = WorkHours(calendar: calendar)
    sim.time.now = calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 11, minute: 59))!
    // Rebuild with the fixed calendar, so no previous time sample crosses the date change.
    sim.duck = Duck(timings: sim.duck.timings, seed: 7)
    sim.send(.tick)
    sim.run(59)
    #expect(sim.duck.phase == .hidden)
    sim.run(1)
    #expect(sim.duck.phase == .entering(.stretch(.remind)))
    sim.send(.click)
    #expect(sim.duck.stretchDoneDay == calendar.startOfDay(for: sim.time.now))
}
