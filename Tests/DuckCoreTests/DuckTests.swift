import CoreGraphics
import Foundation
import Testing
@testable import DuckCore

struct FakeTime: TimeSource {
    var now: Date
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
    init(timings: Timings = .normal, hour: Int = 10) {
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

@Test func chillDuckSitsNearTheRightEdgeOnTheDock() {
    var sim = Sim()
    sim.run(45 * minute)
    #expect(sim.duck.position.x > 1440)
    sim.run(3, every: 1.0 / 60)
    #expect(sim.duck.phase == .waiting(.chill, nil))
    #expect(sim.duck.position == CGPoint(x: 1440 - Motion.homeInset, y: 80))
    #expect(!sim.duck.facingRight)
}

@Test func askDuckWalksToTheMiddle() {
    var sim = Sim()
    sim.run(50 * minute)
    sim.run(4 * minute, every: 0.05)
    #expect(sim.duck.phase.isWaiting(.ask))
    #expect(sim.duck.position == CGPoint(x: 720, y: 80))
    #expect(sim.duck.bubble(at: sim.time.now)?.text == "drink! 💧")
}

@Test func followDuckStopsBesideTheCursorAndFacesIt() {
    var sim = Sim()
    sim.run(60 * minute)
    sim.sensors.mouse = CGPoint(x: 1000, y: 600)
    sim.run(10, every: 1.0 / 60)
    #expect(sim.duck.position == CGPoint(x: 1000 - Motion.followGap, y: 600 - Motion.followDrop))
    #expect(sim.duck.facingRight)
    sim.sensors.mouse = CGPoint(x: 200, y: 300)
    sim.run(10, every: 1.0 / 60)
    #expect(sim.duck.position == CGPoint(x: 200 + Motion.followGap, y: 300 - Motion.followDrop))
    #expect(!sim.duck.facingRight)
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
    #expect(sim.duck.bubble(at: sim.time.now) == nil)
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
    sim.run(10 * minute, every: 10 * minute)
    #expect(sim.duck.workTime == before)
    sim.run(40 * minute, every: 40 * minute)
    #expect(sim.duck.workTime == 0)
}

@Test func offHoursDoNotStartAReminder() {
    var sim = Sim(hour: 19)
    sim.run(3 * 60 * minute)
    #expect(sim.duck.phase == .hidden)
    #expect(sim.duck.workTime == 0)
}

@Test func weekendDoesNotStartAReminder() {
    var sim = Sim()
    sim.time.now += 3 * 24 * 60 * minute
    sim.run(2 * 60 * minute)
    #expect(sim.duck.phase == .hidden)
}

@Test func endOfWorkHoursSendsTheDuckAwayAndResets() {
    var sim = Sim(hour: 17)
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
    #expect(sim.duck.bubble(at: sim.time.now)?.text == "thank you! 💛")
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

@Test func fastTimingsDivideByAMinuteAndIgnoreWorkHours() {
    let fast = Timings.from(environment: ["DUCK_FAST": "1"])
    #expect(fast.reminderInterval == 45)
    #expect(fast.levelStep == 5)
    #expect(fast.awayAfter == 5)
    #expect(fast.longBreak == 30)
    #expect(fast.workHours == nil)
    var sim = Sim(timings: fast, hour: 23)
    sim.run(45)
    #expect(sim.duck.phase == .entering(.chill))
}

extension DuckPhase {
    func isWaiting(_ t: Thirst) -> Bool {
        if case .waiting(t, _) = self { return true }
        return false
    }
}
