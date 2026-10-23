import CoreGraphics
import Foundation
import Testing
@testable import DuckCore

struct FakeTime: TimeSource {
    var now: Date
}

extension Timings {
    /// The normal timings with a fixed 45 min interval, so the tests do not move when the user's interval does.
    static let test: Timings = {
        var t = Timings.normal
        t.reminderInterval = 45 * 60
        return t
    }()
}

struct Sim {
    var time: FakeTime
    var duck: Duck
    var sensors = Sensors(
        idleSeconds: 0,
        mouse: CGPoint(x: 300, y: 500),
        screens: [Screen(frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                         visible: CGRect(x: 0, y: 80, width: 1440, height: 795))]
    )

    /// Starts on a Wednesday at the given local hour in UTC.
    init(timings: Timings = .test, hour: Int = 10) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var t = timings
        if t.workHours != nil { t.workHours = WorkHours(calendar: calendar) }
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 21, hour: hour))!
        time = FakeTime(now: start)
        duck = Duck(timings: t, seed: 7)
        duck.step(now: time.now, sensors: sensors)
    }

    /// Ticks once per `every` seconds; the idle counter grows when `idle` is true.
    mutating func run(_ seconds: TimeInterval, every: TimeInterval = 1, idle: Bool = false) {
        var left = seconds
        while left > 0 {
            let dt = min(every, left)
            time.now += dt
            left -= dt
            sensors.idleSeconds = idle ? sensors.idleSeconds + dt : 0
            duck.step(now: time.now, sensors: sensors)
        }
    }

    /// Sleeps the Mac for `seconds` and wakes it. The idle counter either restarts at the wake
    /// or keeps counting through the sleep; the duck must not depend on which.
    mutating func sleep(_ seconds: TimeInterval, idleCounterRuns: Bool = false) {
        send(.sleep)
        time.now += seconds
        sensors.idleSeconds = idleCounterRuns ? sensors.idleSeconds + seconds : 0
        send(.wake)
    }

    mutating func send(_ input: DuckInput) {
        duck.step(now: time.now, sensors: sensors, input: input)
    }

    var thirst: Thirst? {
        switch duck.phase {
        case .entering(let t), .waiting(let t, _), .moving(let t), .asleep(let t): t
        case .hidden, .happy, .leaving: nil
        }
    }
}

let minute: TimeInterval = 60

@Test func duckComesAfterReminderInterval() {
    var sim = Sim()
    sim.run(44 * minute)
    #expect(sim.duck.phase == .hidden)
    sim.run(2 * minute)
    #expect(sim.duck.isVisible)
    #expect(sim.thirst == .chill)
}

@Test func thirstRisesEveryLevelStep() {
    var sim = Sim()
    sim.run(46 * minute)
    #expect(sim.thirst == .chill)
    sim.run(5 * minute, every: 0.05)
    #expect(sim.thirst == .ask)
    sim.run(5 * minute, every: 0.05)
    #expect(sim.thirst == .thirsty)
    sim.run(5 * minute, every: 0.05)
    #expect(sim.thirst == .follow)
    sim.run(30 * minute)
    #expect(sim.thirst == .follow)
}

@Test func chillDuckSitsNearTheRightEdgeOnTheScreenBottom() {
    var sim = Sim()
    sim.run(45 * minute)
    #expect(sim.duck.position.x > 1440)
    sim.run(3, every: 1.0 / 60)
    #expect(sim.duck.phase == .waiting(.chill, nil))
    #expect(sim.duck.position == CGPoint(x: 1440 - Motion.homeInset, y: 0))
    #expect(!sim.duck.facingRight)
}

@Test func askDuckWalksTowardTheMiddle() {
    var sim = Sim()
    sim.run(50 * minute)
    sim.run(4 * minute, every: 0.05)
    #expect(sim.duck.phase.isWaiting(.ask))
    #expect(sim.duck.position == CGPoint(x: 1440 - Motion.homeInset - Motion.askWalk, y: 0))
    #expect(sim.duck.bubble?.text == "drink! 💧")
}

@Test func duckComesOnTheFirstScreenWhereverTheCursorIs() {
    var sim = Sim()
    let other = CGRect(x: -1440, y: -400, width: 1440, height: 2560)
    sim.sensors.screens.append(Screen(frame: other, visible: other))
    sim.sensors.mouse = CGPoint(x: -700, y: 500)
    sim.run(45 * minute)
    sim.run(3, every: 1.0 / 60)
    #expect(sim.duck.phase == .waiting(.chill, nil))
    #expect(sim.duck.position == CGPoint(x: 1440 - Motion.homeInset, y: 0))
}

@Test func followDuckStopsBesideTheCursorAndFacesIt() {
    var sim = Sim()
    sim.run(60 * minute)
    sim.sensors.mouse = CGPoint(x: 1200, y: 600)
    sim.run(10, every: 1.0 / 60)
    #expect(sim.duck.position == CGPoint(x: 1200 - Motion.followGap, y: 600 - Motion.followDrop))
    #expect(sim.duck.facingRight)
    sim.sensors.mouse = CGPoint(x: 200, y: 300)
    sim.run(10, every: 1.0 / 60)
    #expect(sim.duck.position == CGPoint(x: 200 + Motion.followGap, y: 300 - Motion.followDrop))
    #expect(!sim.duck.facingRight)
}

@Test(arguments: [
    // Corners of the main screen.
    CGPoint(x: 2, y: 2), CGPoint(x: 1438, y: 2), CGPoint(x: 2, y: 898), CGPoint(x: 1438, y: 898),
    // Corners of a second screen above and left of it.
    CGPoint(x: -1918, y: 902), CGPoint(x: -2, y: 902), CGPoint(x: -1918, y: 1978), CGPoint(x: -2, y: 1978),
])
func followDuckAndBubbleStayOnTheCursorScreen(mouse: CGPoint) {
    var sim = Sim()
    let upperLeft = CGRect(x: -1920, y: 900, width: 1920, height: 1080)
    sim.sensors.screens.append(Screen(frame: upperLeft, visible: upperLeft))
    sim.run(60 * minute)
    sim.sensors.mouse = mouse
    sim.run(30, every: 1.0 / 60)
    #expect(sim.duck.phase.isWaiting(.follow))
    // Fall asleep and wake, so the bubble pops in again, and check the whole pop.
    sim.run(Timings.normal.awayAfter + 1, idle: true)
    sim.run(1.0 / 30)
    let screen = sim.sensors.screens.first { $0.frame.contains(mouse) }!.frame
    let p = sim.duck.position
    for k in 0...70 {
        let frame = sim.duck.frame(at: sim.time.now + Double(k) / 100)
        #expect(frame.bubble != nil)
        let bubble = Layout.hitRegions(frame, bubble: Layout.followBubble).last!
            .offsetBy(dx: p.x - Layout.panel.width / 2, dy: p.y - Layout.ground)
        #expect(screen.contains(bubble), "\(bubble) is not inside \(screen) at scale \(frame.bubbleScale)")
    }
}

@Test func followDuckWaitsWhenTheCursorComesToClickIt() {
    var sim = Sim()
    sim.run(60 * minute)
    sim.sensors.mouse = CGPoint(x: 1200, y: 600)
    sim.run(10, every: 1.0 / 60)
    let spot = sim.duck.position
    for k in 1...20 {
        sim.sensors.mouse = CGPoint(x: 1200 - CGFloat(k) * 3, y: 600 - CGFloat(k) * 1.5)
        sim.run(0.1, every: 1.0 / 60)
        #expect(sim.duck.position == spot)
    }
    sim.sensors.mouse = CGPoint(x: 300, y: 600)
    sim.run(10, every: 1.0 / 60)
    #expect(sim.duck.position == CGPoint(x: 300 + Motion.followGap, y: 600 - Motion.followDrop))
}

@Test func followDuckAndBubbleStayUnderTheMenuBar() {
    var sim = Sim()
    let menuBarTop = sim.sensors.screens[0].visible.maxY
    sim.run(60 * minute)
    sim.sensors.mouse = CGPoint(x: 700, y: 895)
    sim.run(30, every: 1.0 / 60)
    #expect(sim.duck.phase.isWaiting(.follow))
    let p = sim.duck.position
    for k in 0...70 {
        let frame = sim.duck.frame(at: sim.time.now + Double(k) / 100)
        for region in Layout.hitRegions(frame, bubble: Layout.followBubble) {
            let r = region.offsetBy(dx: p.x - Layout.panel.width / 2, dy: p.y - Layout.ground)
            #expect(r.maxY <= menuBarTop, "\(r) covers the menu bar at scale \(frame.bubbleScale)")
        }
    }
}

@Test func followDuckKeepsItsFeetOnAScreenSmallerThanItsBox() {
    var sim = Sim()
    let tiny = CGRect(x: -300, y: 400, width: 60, height: 80)
    sim.sensors.screens.append(Screen(frame: tiny, visible: tiny))
    sim.run(60 * minute)
    sim.sensors.mouse = CGPoint(x: -270, y: 440)
    sim.run(30, every: 1.0 / 60)
    #expect(sim.duck.phase.isWaiting(.follow))
    #expect(tiny.contains(sim.duck.position), "\(sim.duck.position) is not inside \(tiny)")
}

@Test func awayTimeDoesNotCount() {
    var sim = Sim()
    sim.run(30 * minute)
    let before = sim.duck.workTime
    sim.run(20 * minute, idle: true)
    #expect(sim.duck.workTime - before <= Timings.normal.awayAfter + 1)
    #expect(sim.duck.phase == .hidden)
}

@Test func awayDuckSleepsAndWakesAtTheSameLevel() {
    var sim = Sim()
    sim.run(46 * minute)
    sim.run(Timings.normal.awayAfter + 1, idle: true)
    guard case .asleep(let level) = sim.duck.phase else {
        Issue.record("expected asleep, got \(sim.duck.phase)")
        return
    }
    #expect(sim.duck.bubble == nil)
    sim.run(20 * minute, idle: true)
    #expect(sim.duck.phase == .asleep(level))
    sim.run(1)
    #expect(sim.thirst == level)
    #expect(sim.duck.phase != .asleep(level))
}

@Test func longBreakResetsTheClock() {
    var sim = Sim()
    sim.run(50 * minute)
    #expect(sim.duck.isVisible)
    sim.run(31 * minute, idle: true)
    #expect(sim.duck.phase == .hidden)
    #expect(sim.duck.workTime == 0)
    sim.run(44 * minute)
    #expect(sim.duck.phase == .hidden)
}

@Test func macSleepCountsAsAway() {
    var sim = Sim()
    sim.run(20 * minute)
    let before = sim.duck.workTime
    sim.sleep(10 * minute)
    #expect(sim.duck.workTime == before)
    sim.sleep(40 * minute)
    #expect(sim.duck.workTime == 0)
}

@Test(arguments: [false, true])
func idleThenMacSleepIsOneLongBreak(idleCounterRuns: Bool) {
    var sim = Sim()
    sim.run(20 * minute)
    sim.run(4 * minute, idle: true)
    sim.sleep(27 * minute, idleCounterRuns: idleCounterRuns)
    #expect(sim.duck.workTime == 0)
    #expect(sim.duck.phase == .hidden)
    sim.run(44 * minute)
    #expect(sim.duck.phase == .hidden)
}

@Test func shortMacSleepDoesNotReset() {
    var sim = Sim()
    sim.run(20 * minute)
    sim.sleep(10 * minute)
    sim.run(1 * minute)
    #expect(sim.duck.workTime > 20 * minute)
    #expect(sim.duck.workTime <= 21 * minute)
    sim.run(25 * minute)
    #expect(sim.duck.isVisible)
}

@Test(arguments: [false, true])
func inputRightAfterAWakeCounts(idleCounterRuns: Bool) {
    var sim = Sim()
    sim.run(46 * minute)
    sim.sleep(10 * minute, idleCounterRuns: idleCounterRuns)
    let before = sim.duck.workTime
    sim.run(1)
    sim.run(5, idle: true)
    #expect(!sim.duck.phase.isAsleep, "the owner is reading, not away")
    #expect(sim.duck.workTime == before + 6)
}

@Test(arguments: [false, true])
func sleepJustUnderALongBreakThenWorkDoesNotReset(idleCounterRuns: Bool) {
    var sim = Sim()
    sim.run(20 * minute)
    sim.sleep(29 * minute + 58, idleCounterRuns: idleCounterRuns)
    sim.run(3)
    #expect(sim.duck.workTime == 20 * minute + 3)
}

@Test func wakeWithoutSleepIsAPlainTick() {
    var sim = Sim()
    sim.run(20 * minute)
    let before = sim.duck.workTime
    sim.time.now += 50
    sim.sensors.idleSeconds = 2
    sim.send(.wake)
    #expect(sim.duck.workTime == before + 50)
    sim.time.now += 1
    sim.sensors.idleSeconds = 0
    sim.send(.wake)
    #expect(sim.duck.workTime == before + 51, "a repeated wake")
}

@Test func repeatedSleepChangesNothing() {
    var sim = Sim()
    sim.run(20 * minute)
    let before = sim.duck.workTime
    sim.send(.sleep)
    sim.time.now += 5 * minute
    sim.send(.sleep)
    sim.time.now += 5 * minute
    sim.sensors.idleSeconds = 0
    sim.send(.wake)
    #expect(sim.duck.workTime == before)
}

@Test func lateTickWithRecentInputCountsAsWork() {
    var sim = Sim()
    sim.run(20 * minute)
    let before = sim.duck.workTime
    sim.time.now += 50
    sim.sensors.idleSeconds = 2
    sim.send(.tick)
    #expect(sim.duck.workTime == before + 50)
}

@Test func offHoursDoNotStartAReminder() {
    var sim = Sim(hour: 23)
    sim.run(8 * 60 * minute)
    #expect(sim.duck.phase == .hidden)
    #expect(sim.duck.workTime == 0)
}

@Test func weekendAlsoStartsAReminder() {
    var sim = Sim()
    sim.time.now += 3 * 24 * 60 * minute
    sim.run(46 * minute)
    #expect(sim.duck.isVisible)
}

@Test func endOfWorkHoursSendsTheDuckAwayAndResets() {
    var sim = Sim(hour: 22)
    sim.run(50 * minute)
    #expect(sim.duck.isVisible)
    sim.run(11 * minute)
    #expect(sim.duck.phase == .leaving || sim.duck.phase == .hidden)
    #expect(sim.duck.workTime == 0)
}

@Test func clickMakesItHappyThenLeaveAndRestartsTheClock() {
    var sim = Sim()
    sim.run(50 * minute)
    sim.send(.click)
    #expect(sim.duck.phase == .happy)
    #expect(sim.duck.workTime == 0)
    #expect(sim.duck.bubble?.text == "thank you! 💛")
    sim.run(2, every: 1.0 / 60)
    #expect(sim.duck.phase == .leaving)
    sim.run(30, every: 1.0 / 60)
    #expect(sim.duck.position.x > 1440)
    #expect(sim.duck.phase == .hidden)
    sim.run(44 * minute)
    #expect(sim.duck.phase == .hidden)
    sim.run(2 * minute)
    #expect(sim.duck.isVisible)
    #expect(sim.thirst == .chill)
}

@Test func callNowStartsAtLevelOne() {
    var sim = Sim()
    sim.run(5 * minute)
    sim.send(.callNow)
    #expect(sim.duck.phase == .entering(.chill))
    sim.run(5 * minute + 10, every: 0.05)
    #expect(sim.thirst == .ask)
}

@Test func callNowAfterALongBreakStays() {
    var sim = Sim()
    sim.run(20 * minute)
    sim.run(30 * minute, idle: true)
    sim.sensors.idleSeconds = 0
    sim.send(.callNow)
    #expect(sim.duck.phase == .entering(.chill))
    sim.run(1.0 / 30)
    #expect(sim.duck.phase == .entering(.chill))
}

@Test func aShorterReminderIntervalTakesEffectAtOnce() {
    var sim = Sim()
    sim.run(25 * minute)
    #expect(sim.duck.phase == .hidden)
    sim.duck.timings.reminderInterval = 20 * minute
    sim.run(1)
    #expect(sim.duck.isVisible)
}

@Test func fastTimingsAreShortAndIgnoreWorkHours() {
    let fast = Timings.from(environment: ["DUCK_FAST": "1"])
    #expect(fast.reminderInterval == 10)
    #expect(fast.levelStep == 15)
    #expect(fast.awayAfter == 10)
    #expect(fast.longBreak == 30)
    #expect(fast.workHours == nil)
    var sim = Sim(timings: fast, hour: 23)
    sim.run(10)
    #expect(sim.duck.phase == .entering(.chill))
}

@Test func fastLongBreakAcrossMacSleepResets() {
    var sim = Sim(timings: .fast)
    sim.run(20)
    sim.sleep(40)
    #expect(sim.duck.workTime == 0)
    sim.run(5)
    #expect(sim.duck.phase == .hidden)
}

@Test func fastLateTickAfterALongBreakResets() {
    var sim = Sim(timings: .fast)
    sim.run(20)
    sim.run(40, every: 40)
    #expect(sim.duck.workTime == 0)
    sim.run(5)
    #expect(sim.duck.phase == .hidden)
}

extension DuckPhase {
    func isWaiting(_ t: Thirst) -> Bool {
        if case .waiting(t, _) = self { return true }
        return false
    }

    var isAsleep: Bool {
        if case .asleep = self { return true }
        return false
    }
}

@Test func statusCountsDownToTheNextDuck() {
    var sim = Sim()
    sim.run(10 * minute)
    #expect(sim.duck.status(at: sim.time.now) == .nextIn(35 * minute))
    sim.run(36 * minute)
    #expect(sim.duck.status(at: sim.time.now) == .here)
}

@Test func statusOffHoursNamesTheNextStart() {
    let sim = Sim(hour: 23)
    let thursday8 = sim.time.now + 9 * 60 * minute
    #expect(sim.duck.status(at: sim.time.now) == .offUntil(thursday8))
}

@Test func nextStartSkipsDaysOff() {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    var hours = WorkHours(calendar: utc)
    hours.weekdays = Set(2...6)
    hours.startHour = 9
    hours.endHour = 24
    let friday2330 = utc.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 23, minute: 30))!
    #expect(hours.contains(friday2330))
    #expect(hours.nextStart(after: friday2330) == utc.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 9)))
    let friday7 = utc.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 7))!
    #expect(hours.nextStart(after: friday7) == utc.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9)))
}

@Test func shorterHoursSendAVisibleDuckAway() {
    var sim = Sim(hour: 15)
    sim.run(46 * minute)
    #expect(sim.duck.isVisible)
    sim.duck.timings.workHours?.endHour = 15
    sim.run(1)
    #expect(sim.duck.phase == .leaving)
    #expect(sim.duck.workTime == 0)
}
