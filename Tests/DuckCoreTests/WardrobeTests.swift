import CoreGraphics
import Foundation
import Testing
@testable import DuckCore

private func stageSim(_ thirst: Thirst = .chill, seed: UInt64 = 7, facingRight: Bool = false) -> Sim {
    var timings = Timings.test
    timings.workHours = nil
    timings.reminderInterval = 1
    timings.levelStep = 100_000
    timings.longBreak = 1_000_000
    var sim = Sim(timings: timings)
    sim.duck = Duck(timings: sim.duck.timings, seed: seed)
    if facingRight {
        // On a narrow stage, the home is left of center and the Ask target is to its right.
        let frame = CGRect(x: 0, y: 0, width: 200, height: 900)
        sim.sensors.screens = [Screen(frame: frame, visible: frame)]
    }
    sim.send(.tick)
    sim.send(.callNow)
    if thirst > .chill { sim.run(Double(thirst.rawValue - 1) * timings.levelStep, every: 100) }
    sim.run(until: .waiting(thirst, nil))
    return sim
}

private extension Sim {
    mutating func nextMove() -> Trick? {
        for _ in 0..<200 {
            if case .waiting(_, let trick?) = duck.phase { return trick }
            run(0.05, every: 0.05)
        }
        Issue.record("no move started")
        return nil
    }

    mutating func finishMove() {
        guard case .waiting(let thirst, let trick?) = duck.phase else { return }
        let remaining = trick.duration - time.now.timeIntervalSince(duck.phaseStart)
        run(max(0, remaining) + 0.01, every: 0.05)
        #expect(duck.phase == .waiting(thirst, nil))
    }

    mutating func findMove(_ wanted: Trick, facingRight: Bool? = nil) {
        for _ in 0..<1_000 {
            if nextMove() == wanted && (facingRight == nil || duck.facingRight == facingRight) { return }
            finishMove()
        }
        Issue.record("did not pick \(wanted)")
    }

    mutating func sampleMove(_ trick: Trick, progress: Double) {
        findMove(trick)
        let at = duck.phaseStart + trick.duration * progress
        run(max(0, at.timeIntervalSince(time.now)), every: 0.02)
    }
}

@Test func randomLooksDifferAndUmbrellasHaveNoHat() {
    var rng = SplitMix64(state: 42)
    var previous: Look? = .classic
    var rare = 0
    var umbrellas = 0
    for _ in 0..<30_000 {
        let look = Look.random(using: &rng, unlike: previous)
        #expect(look != previous)
        if look.item == .umbrella {
            umbrellas += 1
            #expect(look.hat == nil)
        }
        if look.palette.isRare { rare += 1 }
        previous = look
    }
    #expect(umbrellas > 300)
    #expect((0.045...0.075).contains(Double(rare) / 30_000))
}

@Test func eachAppearanceChangesLookAndStartsWithSpin() {
    var sim = stageSim()
    for _ in 0..<20 {
        let previous = sim.duck.look
        sim.send(.click)
        sim.run(until: .hidden)
        sim.send(.callNow)
        #expect(sim.duck.look != previous)
        sim.run(until: .waiting(.chill, .spin))
        #expect(sim.duck.frame(at: sim.time.now + 0.3).pose.eyes == .happy)
    }
}

@Test func newLookChangesTheVisibleDuckAndSpinsWhenWaiting() {
    var sim = Sim()
    #expect(!sim.duck.canChangeLook)
    let classic = sim.duck.look
    sim.send(.newLook)
    #expect(sim.duck.look == classic)
    sim.send(.callNow)
    #expect(sim.duck.canChangeLook)
    let entering = sim.duck.look
    sim.send(.newLook)
    #expect(sim.duck.look != entering)
    #expect(sim.duck.phase == .entering(.chill))
    sim.run(until: .waiting(.chill, nil))
    let waiting = sim.duck.look
    sim.send(.newLook)
    #expect(sim.duck.look != waiting)
    #expect(sim.duck.phase == .waiting(.chill, .spin))
    sim.run(Timings.normal.awayAfter + 1, idle: true)
    #expect(sim.duck.phase.isAsleep)
    #expect(sim.duck.canChangeLook)
    let asleep = sim.duck.look
    let phase = sim.duck.phase
    sim.send(.newLook)
    #expect(sim.duck.look != asleep)
    #expect(sim.duck.phase == phase)
    sim.run(0.1, every: 0.1)
    #expect(sim.duck.canChangeLook)
    let moving = sim.duck.look
    let movingPhase = sim.duck.phase
    sim.send(.newLook)
    #expect(sim.duck.look != moving)
    #expect(sim.duck.phase == movingPhase)
    sim.send(.click)
    let happy = sim.duck.look
    #expect(!sim.duck.canChangeLook)
    sim.send(.newLook)
    #expect(sim.duck.look == happy)
    #expect(sim.duck.phase == .happy)
    sim.run(1.4, every: 0.05)
    #expect(sim.duck.phase == .leaving)
    #expect(!sim.duck.canChangeLook)
    sim.send(.newLook)
    #expect(sim.duck.look == happy)
    #expect(sim.duck.phase == .leaving)
}

@Test(arguments: [Thirst.chill, .ask, .thirsty, .follow])
func movesStayInTheirStage(thirst: Thirst) {
    let old: [Trick]
    let new: [Trick]
    switch thirst {
    case .chill:
        old = [.blink, .lookBack, .hop, .wiggle, .peck, .stroll(right: false), .stroll(right: true)]
        new = [.moonwalk, .spin, .backflip, .roll, .wave, .hover, .dance, .tapDance, .jelly, .yawn,
               .quack, .loaf, .lookAround, .puddleJump, .swim, .bow, .peekaboo, .love, .kick,
               .sleepyNod, .jumpSpin, .skate, .juggle, .sunbathe]
    case .ask:
        old = [.hop, .wiggle, .hopHop]
        new = [.wave, .quack, .drink, .pushUps, .zoomies, .sneeze, .headbang, .puddleJump]
    case .thirsty:
        old = [.shake, .blink]
        new = [.dizzy, .shiver, .trip, .sneeze, .zoomies]
    case .follow:
        old = [.shake]
        new = []
    }
    var sim = stageSim(thirst)
    var oldCount = 0
    var seen: [Trick] = []
    for _ in 0..<600 {
        guard let trick = sim.nextMove() else { return }
        #expect((old + new).contains(trick), "\(thirst) picked \(trick)")
        if old.contains(trick) { oldCount += 1 }
        if !seen.contains(trick) { seen.append(trick) }
        if !new.isEmpty { #expect(sim.rate == 30 || trick == .blink || trick == .lookBack) }
        sim.finishMove()
        #expect(sim.duck.phase == .waiting(thirst, nil))
        sim.run(0.5, every: 0.05)
        #expect(sim.duck.phase == .waiting(thirst, nil), "the gap starts at the end of the move")
    }
    for trick in old + new { #expect(seen.contains(trick), "never picked \(trick)") }
    let fraction = Double(oldCount) / 600
    switch thirst {
    case .chill, .ask: #expect((0.42...0.58).contains(fraction))
    case .thirsty: #expect((0.52...0.68).contains(fraction))
    case .follow: #expect(fraction == 1)
    }
}

@Test(arguments: [Thirst.chill, .ask, .thirsty])
func moveSpeechReplacesOnlyTheFirstTwoStageBubbles(thirst: Thirst) {
    var sim = stageSim(thirst)
    let trick: Trick = thirst == .thirsty ? .sneeze : .quack
    sim.sampleMove(trick, progress: thirst == .thirsty ? 0.6 : 0.4)
    #expect(sim.duck.bubble?.text == (thirst == .thirsty ? "so thirsty… 💧💧" : "quack!"))
    if thirst == .thirsty { #expect(sim.duck.bubble?.alarm == true) }
    sim.finishMove()
    if thirst == .ask { #expect(sim.duck.bubble?.text == "drink! 💧") }
}

@Test func lookClockRunsOnlyForAnimatedLooksAndSleepStaysSlow() {
    var sim = stageSim()
    for animated in [false, true] {
        for _ in 0..<1_000 where sim.duck.look.isAnimated != animated { sim.send(.newLook) }
        #expect(sim.duck.look.isAnimated == animated)
        sim.finishMove()
        let a = sim.duck.frame(at: sim.time.now)
        let b = sim.duck.frame(at: sim.time.now + 0.2)
        #expect(a.look == sim.duck.look)
        if animated {
            #expect(a.lookClock != b.lookClock)
            #expect(sim.rate >= 10)
        } else {
            #expect(a.lookClock == 0)
            #expect(b.lookClock == 0)
        }
    }
    sim.run(Timings.normal.awayAfter + 1, idle: true)
    #expect(sim.rate == 2)
}

@Test func hitRegionsFollowTheMoveAndHeadroom() {
    var frame = Duck(timings: .normal, seed: 7).frame(at: .now)
    let base = Layout.hitRegions(frame, bubble: shortBubble)
    frame.pose.dx = 30
    frame.pose.sink = 8
    let moved = Layout.hitRegions(frame, bubble: shortBubble)
    #expect(moved[0] == base[0].offsetBy(dx: 30, dy: -8))
    frame.look = Look(palette: .classic, hat: .witch)
    let hat = Layout.hitRegions(frame, bubble: shortBubble)
    #expect(hat[1].minY == base[1].minY + 30)
    frame.look = .classic
    frame.pose.dx = 0
    frame.pose.sink = 0
    frame.pose.scaleX = -0.5
    frame.pose.scaleY = 0.8
    let scaled = Layout.hitRegions(frame, bubble: nil)[0]
    #expect(abs(scaled.width - 40) < 0.0001)
    #expect(abs(scaled.height - 56) < 0.0001)
    frame.pose.scaleX = 1
    frame.pose.scaleY = 1
    frame.pose.spin = 90
    let spun = Layout.hitRegions(frame, bubble: nil)[0]
    #expect(abs(spun.width - 70) < 0.0001)
    #expect(abs(spun.height - 80) < 0.0001)
    frame.pose.spin = 0
    frame.pose.sink = 78
    frame.pose.clipsAtGround = true
    #expect(Layout.hitRegions(frame, bubble: nil)[0].isNull)
}

@Test func skateboardLookAndMoveAddTenPointsOfLift() {
    var sim = stageSim()
    for _ in 0..<1_000 where sim.duck.look.item != .skateboard || sim.duck.look.palette == .ghost { sim.send(.newLook) }
    #expect(sim.duck.look.item == .skateboard)
    #expect(sim.duck.frame(at: sim.duck.phaseStart).pose.lift == 10)
    for _ in 0..<1_000 where sim.duck.look.item == .skateboard || sim.duck.look.palette == .ghost { sim.send(.newLook) }
    sim.finishMove()
    sim.sampleMove(.skate, progress: 0.25)
    let pose = sim.duck.frame(at: sim.time.now).pose
    #expect(pose.item == .skateboard)
    #expect(pose.lift == 10)
    #expect(abs(pose.dx - (sim.duck.facingRight ? 30 : -30)) < 0.0001)
}

@Test(arguments: [false, true])
func moonwalkMovesBackwardForEitherFacing(facingRight: Bool) {
    var sim = stageSim(facingRight: facingRight)
    sim.findMove(.moonwalk, facingRight: facingRight)
    let earlier = sim.duck.frame(at: sim.duck.phaseStart + Trick.moonwalk.duration * 0.25).pose
    let later = sim.duck.frame(at: sim.duck.phaseStart + Trick.moonwalk.duration * 0.5).pose
    if facingRight {
        #expect(later.dx < 0)
        #expect(later.dx < earlier.dx)
    } else {
        #expect(later.dx > 0)
        #expect(later.dx > earlier.dx)
    }
}

@Test(arguments: [false, true])
func zoomiesRunsForwardThenBackWithDustBehind(facingRight: Bool) {
    var sim = stageSim(.ask, facingRight: facingRight)
    sim.findMove(.zoomies, facingRight: facingRight)
    let direction: CGFloat = facingRight ? 1 : -1
    let first = sim.duck.frame(at: sim.duck.phaseStart + Trick.zoomies.duration * 0.1)
    let next = sim.duck.frame(at: sim.duck.phaseStart + Trick.zoomies.duration * 0.2)
    #expect(abs(first.pose.dx - direction * 15) < 0.0001)
    #expect(abs(next.pose.dx - direction * 30) < 0.0001)
    #expect(first.pose.mirrored == !facingRight)
    #expect(first.particles.count == 1)
    #expect(first.particles.allSatisfy { $0.x * direction < 0 })
    for progress in [0.4, 0.6] {
        let back = sim.duck.frame(at: sim.duck.phaseStart + Trick.zoomies.duration * progress)
        let expected: CGFloat = progress < 0.5 ? 22.5 : -22.5
        #expect(abs(back.pose.dx - direction * expected) < 0.0001)
        #expect(back.pose.mirrored == facingRight)
        #expect(back.particles.count == 1)
        #expect(back.particles.allSatisfy { $0.x * direction > 0 })
    }
}

@Test(arguments: [false, true])
func sneezeSpraysInFrontOfEitherFacing(facingRight: Bool) {
    var sim = stageSim(.ask, facingRight: facingRight)
    sim.findMove(.sneeze, facingRight: facingRight)
    let frame = sim.duck.frame(at: sim.duck.phaseStart + Trick.sneeze.duration * 0.6)
    #expect(frame.particles.count == 3)
    for particle in frame.particles {
        #expect(particle.emoji == "💦")
        #expect(facingRight ? particle.x > 44 : particle.x < -44)
    }
}

@Test(arguments: [false, true])
func rollMovesForwardAndHitRegionFollows(facingRight: Bool) {
    var sim = stageSim(facingRight: facingRight)
    sim.findMove(.roll, facingRight: facingRight)
    var frame = sim.duck.frame(at: sim.duck.phaseStart + Trick.roll.duration * 0.25)
    #expect(abs(frame.pose.dx - (facingRight ? 12 : -12)) < 0.0001)
    #expect(abs(frame.pose.spin - 180) < 0.0001)
    frame.look = .classic
    let region = Layout.hitRegions(frame, bubble: nil)[0]
    #expect(abs(region.midX - (Layout.panel.width / 2 + frame.pose.dx)) < 0.0001)
    #expect(abs(region.width - Layout.sprite.width) < 0.0001)
    #expect(abs(region.height - Layout.sprite.height) < 0.0001)
}

@Test(arguments: [false, true])
func skateOffsetsUseRealFacingDuringTheTurn(facingRight: Bool) {
    var sim = stageSim(facingRight: facingRight)
    sim.findMove(.skate, facingRight: facingRight)
    let direction: CGFloat = facingRight ? 1 : -1
    for progress in [0.125, 0.375, 0.625, 0.875] {
        var frame = sim.duck.frame(at: sim.duck.phaseStart + Trick.skate.duration * progress)
        #expect(progress < 0.5 ? frame.pose.dx * direction > 0 : frame.pose.dx * direction < 0)
        let turned = progress > 0.25 && progress < 0.75
        #expect(frame.pose.mirrored == (turned ? facingRight : !facingRight))
        #expect(abs(frame.pose.tilt + 3 / sqrt(2)) < 0.0001)
        frame.look = .classic
        frame.pose.dx = 0
        let centered = Layout.hitRegions(frame, bubble: nil)[0]
        frame.pose = sim.duck.frame(at: sim.duck.phaseStart + Trick.skate.duration * progress).pose
        let moved = Layout.hitRegions(frame, bubble: nil)[0]
        #expect(abs(moved.minX - centered.minX - frame.pose.dx) < 0.0001)
        #expect(abs(moved.maxX - centered.maxX - frame.pose.dx) < 0.0001)
    }
}

@Test(arguments: [false, true])
func tripStarsStayWhereTheHeadLands(facingRight: Bool) {
    var sim = stageSim(.thirsty, facingRight: facingRight)
    sim.findMove(.trip, facingRight: facingRight)
    let frame = sim.duck.frame(at: sim.duck.phaseStart + Trick.trip.duration * 0.4)
    #expect(frame.particles.count == 3)
    #expect(frame.particles.allSatisfy { facingRight ? $0.x >= 44 : $0.x <= -44 })
    #expect(frame.pose.tilt == 80)
}

@Test(arguments: [Trick.dance, .tapDance, .love, .juggle, .dizzy])
func surroundingParticlesMirrorWithFacing(trick: Trick) {
    let thirst: Thirst = trick == .dizzy ? .thirsty : .chill
    var left = stageSim(thirst)
    var right = stageSim(thirst, facingRight: true)
    left.findMove(trick, facingRight: false)
    right.findMove(trick, facingRight: true)
    let now = max(left.time.now, right.time.now)
    let leftParticles = left.duck.frame(at: now).particles
    let rightParticles = right.duck.frame(at: now).particles
    #expect(!leftParticles.isEmpty)
    #expect(leftParticles.count == rightParticles.count)
    for (a, b) in zip(leftParticles, rightParticles) {
        #expect(a.x == -b.x)
        #expect(a.emoji == b.emoji)
        #expect(a.y == b.y)
        #expect(a.size == b.size)
        #expect(a.opacity == b.opacity)
    }
}

@Test func seedMakesLooksAndMovesRepeat() {
    var a = stageSim(.ask, seed: 123)
    var b = stageSim(.ask, seed: 123)
    for _ in 0..<100 {
        #expect(a.nextMove() == b.nextMove())
        #expect(a.duck.frame(at: a.time.now) == b.duck.frame(at: b.time.now))
        a.finishMove()
        b.finishMove()
        a.send(.newLook)
        b.send(.newLook)
        #expect(a.duck.look == b.duck.look)
        a.finishMove()
        b.finishMove()
    }
}

@Test func flipsAndSpinsReachTheirPrototypeMidpoints() {
    var sim = stageSim()
    for _ in 0..<1_000 where sim.duck.look.item == .skateboard || sim.duck.look.palette == .ghost { sim.send(.newLook) }
    sim.finishMove()
    sim.findMove(.backflip)
    var pose = sim.duck.frame(at: sim.duck.phaseStart + Trick.backflip.duration / 2).pose
    #expect(abs(pose.lift - 34) < 0.0001)
    #expect(abs(pose.spin + 180) < 0.0001)
    #expect(pose.eyes == .closed)
    sim.finishMove()
    sim.findMove(.spin)
    pose = sim.duck.frame(at: sim.duck.phaseStart + Trick.spin.duration / 4).pose
    #expect(abs(pose.scaleX + 1) < 0.0001)
    sim.finishMove()
    sim.findMove(.jumpSpin)
    pose = sim.duck.frame(at: sim.duck.phaseStart + Trick.jumpSpin.duration * 0.475).pose
    #expect(abs(pose.lift - 26) < 0.0001)
    #expect(abs(pose.scaleX + 1) < 0.0001)
}

@Test func drinkEmptiesTheBottleAndChangesItsSpeech() {
    var sim = stageSim(.ask)
    sim.findMove(.drink)
    #expect(sim.duck.frame(at: sim.duck.phaseStart).pose.bottleFill == 5)
    let start = sim.duck.phaseStart
    sim.run(max(0, (start + Trick.drink.duration * 0.4).timeIntervalSince(sim.time.now)), every: 0.02)
    #expect(sim.duck.bubble?.text == "glug glug")
    let half = sim.duck.frame(at: sim.time.now).pose
    #expect(half.bottleFill == 3)
    #expect(half.eyes == .closed)
    sim.run((start + Trick.drink.duration * 0.9).timeIntervalSince(sim.time.now), every: 0.02)
    let end = sim.duck.frame(at: sim.time.now).pose
    #expect(end.bottleFill == 0)
    #expect(end.eyes == .happy)
    #expect(sim.duck.bubble?.text == "ahh 💙")
}

@Test func swimPeekabooAndSunbatheSetTheirDrawingProps() {
    var sim = stageSim()
    sim.findMove(.swim)
    var frame = sim.duck.frame(at: sim.duck.phaseStart + 1)
    #expect(frame.pose.water)
    #expect(frame.pose.feet == .hidden)
    #expect(frame.waterPhase != 0)
    #expect(frame.waterPhase != sim.duck.frame(at: sim.duck.phaseStart + 1.1).waterPhase)
    sim.finishMove()
    sim.findMove(.peekaboo)
    frame = sim.duck.frame(at: sim.duck.phaseStart + Trick.peekaboo.duration / 2)
    #expect(frame.pose.sink == 78)
    #expect(frame.pose.clipsAtGround)
    sim.finishMove()
    sim.findMove(.sunbathe)
    frame = sim.duck.frame(at: sim.duck.phaseStart + Trick.sunbathe.duration / 2)
    #expect(frame.pose.glasses == .sunglasses)
    #expect(frame.pose.feet == .hidden)
    #expect(frame.particles.first?.emoji == "☀️")
    #expect(frame.particles.first?.y == 98)
}

@Test func zoomiesStaysWithinFortyFivePointsAndKeepsSweat() {
    var sim = stageSim(.thirsty)
    sim.findMove(.zoomies)
    for i in 0...100 {
        let frame = sim.duck.frame(at: sim.duck.phaseStart + Trick.zoomies.duration * Double(i) / 100)
        #expect(abs(frame.pose.dx) <= 45.0001)
        guard case .sweat = frame.effect else {
            Issue.record("thirsty move lost its sweat")
            return
        }
    }
}

@Test func ghostFloatAndLookHeadroomMatchTheirArt() {
    var sim = stageSim()
    for _ in 0..<2_000 where sim.duck.look.palette != .ghost { sim.send(.newLook) }
    #expect(sim.duck.look.palette == .ghost)
    sim.finishMove()
    let now = sim.time.now
    let expected = 3 + 3 * sin(2.2 * now.timeIntervalSinceReferenceDate)
    #expect(abs(sim.duck.frame(at: now).pose.lift - expected) < 0.0001)
    #expect(Look(palette: .classic, item: .umbrella).headroom == 7)
    #expect(Look(palette: .classic, hat: .party).headroom == 5)
    #expect(Look(palette: .robot).isAnimated == false)
    #expect(Look(palette: .classic, hat: .halo).isAnimated)
    #expect(Look(palette: .classic, outfit: .cape).isAnimated)
}
