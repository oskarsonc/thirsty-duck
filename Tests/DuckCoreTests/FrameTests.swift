import CoreGraphics
import Foundation
import Testing
@testable import DuckCore

extension Sim {
    var rate: Double { duck.tickRate(at: time.now) }

    /// Runs at 10 Hz until the duck is in `phase`, for at most a minute.
    mutating func run(until phase: DuckPhase) {
        for _ in 0..<600 where duck.phase != phase { run(0.1, every: 0.1) }
        #expect(duck.phase == phase)
    }
}

@Test func tickRateFollowsWhatTheDuckDoes() {
    var sim = Sim()
    #expect(sim.rate == 1, "hidden")
    sim.run(45 * minute)
    #expect(sim.rate == 30, "walking in")
    sim.run(until: .waiting(.chill, nil))
    sim.run(Motion.bubblePop, every: 0.1)
    #expect(sim.duck.phase == .waiting(.chill, nil))
    #expect(sim.rate == 10, "sitting")
    sim.run(Timings.normal.awayAfter, idle: true)
    #expect(sim.rate == 2, "asleep")
    sim.run(0.1, every: 0.1)
    #expect(sim.rate == 30, "waking walks back")
    sim.send(.click)
    #expect(sim.rate == 30, "happy")
}

@Test func followDuckTicksFastWhileItMovesAndSlowWhileItSweats() {
    var sim = Sim()
    sim.run(61 * minute)
    sim.sensors.mouse = CGPoint(x: 1000, y: 600)
    sim.run(0.5, every: 1.0 / 30)
    #expect(sim.duck.phase == .moving(.follow))
    #expect(sim.rate == 30)
    sim.run(until: .waiting(.follow, nil))
    #expect(sim.rate == 10)
}

@Test func newBubblePopsAtFullRate() {
    var sim = Sim()
    sim.run(50 * minute)
    sim.run(until: .waiting(.ask, nil))
    sim.run(Motion.bubblePop, every: 0.1)
    sim.send(.click)
    #expect(sim.duck.bubble?.text == "thank you! 💛")
    #expect(sim.duck.frame(at: sim.time.now).bubbleScale < 1)
    sim.time.now += Motion.bubblePop
    #expect(sim.duck.frame(at: sim.time.now).bubbleScale == 1)
}

@Test func frameStaysTheSameWhileTheDuckSitsStill() {
    var sim = Sim()
    sim.run(45 * minute)
    sim.run(until: .waiting(.chill, nil))
    sim.run(Motion.bubblePop, every: 0.1)
    #expect(sim.duck.phase == .waiting(.chill, nil))
    let still = sim.duck.frame(at: sim.time.now)
    #expect(sim.duck.frame(at: sim.time.now + 0.1) == still)
}

@Test func frameChangesWhileTheDuckWalks() {
    var sim = Sim()
    sim.run(45 * minute)
    let a = sim.duck.frame(at: sim.time.now)
    sim.run(0.1, every: 0.1)
    #expect(sim.duck.frame(at: sim.time.now) != a)
}
