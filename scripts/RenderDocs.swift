import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// usage: render <docs dir> <iconset dir>
let docs = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = URL(fileURLWithPath: CommandLine.arguments[2])

struct Sim {
    var duck: Duck
    var sensors: Sensors
    var now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    init(timings: Timings, screen: Screen) {
        duck = Duck(timings: timings, seed: 3)
        sensors = Sensors(idleSeconds: 0, mouse: CGPoint(x: screen.frame.midX, y: screen.frame.midY), screens: [screen])
        duck.step(now: now, sensors: sensors)
    }

    mutating func tick(_ dt: Double = 1.0 / 30, idle: Bool = false) {
        now += dt
        sensors.idleSeconds = idle ? sensors.idleSeconds + dt : 0
        duck.step(now: now, sensors: sensors)
    }

    mutating func send(_ input: DuckInput) { duck.step(now: now, sensors: sensors, input: input) }

    mutating func until(_ ok: (Duck) -> Bool) {
        var t = 0.0
        while !ok(duck) && t < 120 { tick(); t += 1.0 / 30 }
    }

    var frame: Frame { duck.frame(at: now) }
}

/// A duck that stands still and faces right. The duck is hidden, so nothing moves it.
let standing = Pose(duck: Duck(timings: .fast, seed: 0), now: Date(timeIntervalSinceReferenceDate: 0))

@MainActor func image(_ view: some View, scale: CGFloat) -> CGImage {
    let r = ImageRenderer(content: view)
    r.scale = scale
    return r.cgImage!
}

func writePNG(_ img: CGImage, _ url: URL) {
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil)
    CGImageDestinationFinalize(d)
}

// MARK: - Stages sheet

@MainActor func renderStages() {
    let screen = Screen(frame: CGRect(x: 0, y: 0, width: 1440, height: 900), visible: CGRect(x: 0, y: 0, width: 1440, height: 875))
    var sim = Sim(timings: .fast, screen: screen)
    var shots: [(String, Frame)] = []
    // The sheet shows the classic duck. A look that changes the lift would not match it.
    func shot() -> Frame {
        var f = sim.frame
        precondition(f.look.palette != .ghost && f.look.item != .skateboard)
        f.look = .classic
        f.lookClock = 0
        return f
    }
    sim.send(.callNow)
    sim.until { $0.phase == .waiting(.chill, nil) && $0.bubble != nil }
    for _ in 0..<24 { sim.tick() }
    shots.append(("1 · chill", shot()))
    for (label, level) in [("2 · ask", Thirst.ask), ("3 · thirsty", .thirsty), ("4 · follow", .follow)] {
        sim.until { $0.phase == .waiting(level, nil) }
        for _ in 0..<24 { sim.tick() }
        shots.append((label, shot()))
    }
    for _ in 0..<336 { sim.tick(idle: true) }
    shots.append(("away · asleep", shot()))
    sim.until { $0.phase == .waiting(.follow, nil) }
    for _ in 0..<24 { sim.tick() }
    sim.send(.click)
    for _ in 0..<14 { sim.tick() }
    shots.append(("click · thank you", shot()))

    let sheet = HStack(spacing: 0) {
        ForEach(Array(shots.enumerated()), id: \.offset) { _, shot in
            VStack(spacing: 0) {
                DuckView(frame: shot.1).frame(height: 170, alignment: .bottom).clipped()
                Text(shot.0)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x5B6B7F))
                    .padding(.bottom, 14)
            }
            .frame(width: 210)
        }
    }
    .background(Color(hex: 0xEEF5FD))
    writePNG(image(sheet, scale: 2), docs.appendingPathComponent("stages.png"))
}

// MARK: - Looks sheet

@MainActor func renderLooks() {
    let looks: [Look] = [
        Look(palette: .classic, hat: .cap, glasses: .sunglasses, outfit: .hoodie),
        Look(palette: .mint, hat: .party, outfit: .bowTie),
        Look(palette: .bubblegum, hat: .bow, glasses: .heart, outfit: .tutu),
        Look(palette: .sky, hat: .sailor, outfit: .sailorTop, item: .fish),
        Look(palette: .charcoal, hat: .topHat, glasses: .monocle, outfit: .tuxedo),
        Look(palette: .golden, hat: .crown, outfit: .goldChain),
        Look(palette: .ocean, hat: .bucket, glasses: .swimGoggles, outfit: .swimRing),
        Look(palette: .strawberry, hat: .beanie, outfit: .stripedSweater, item: .balloon),
        Look(palette: .cow, hat: .cowboy, outfit: .bandana),
        Look(palette: .galaxy, hat: .witch, outfit: .cape),
        Look(palette: .lavender, outfit: .raincoat, item: .umbrella),
        Look(palette: .lime, hat: .propeller, glasses: .nerd, outfit: .backpack, item: .skateboard),
    ]
    let frames = looks.map { look in
        var pose = standing
        // DuckCore lifts the duck onto its skateboard.
        if look.item == .skateboard { pose.lift += 10 }
        return Frame(pose: pose, facingRight: true, effect: .none, bubble: nil, bubbleScale: 1, look: look,
                     particles: [], lookClock: look.isAnimated ? 7 : 0, waterPhase: 0)
    }
    let sheet = VStack(spacing: 0) {
        ForEach(0..<2) { row in
            HStack(spacing: 0) {
                ForEach(0..<6) { col in
                    let f = frames[row * 6 + col]
                    VStack(spacing: 0) {
                        DuckView(frame: f).frame(width: 150, height: 132, alignment: .bottom).clipped()
                        Text(f.look.palette.rawValue.capitalized + (f.look.palette.isRare ? " · rare" : ""))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(hex: 0x5B6B7F))
                            .padding(.bottom, 14)
                    }
                }
            }
        }
    }
    .padding(.horizontal, 15)
    .background(Color(hex: 0xEEF5FD))
    writePNG(image(sheet, scale: 2), docs.appendingPathComponent("looks.png"))
}

// MARK: - Demo animation

private let sceneSize = CGSize(width: 720, height: 300)
private let menuBar: CGFloat = 22

struct Cursor: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addLines([CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 17), CGPoint(x: 4.5, y: 13), CGPoint(x: 7.5, y: 20),
                    CGPoint(x: 10, y: 19), CGPoint(x: 7, y: 12), CGPoint(x: 12.5, y: 12)])
        p.closeSubpath()
        return p
    }
}

struct DemoScene: View {
    let frame: Frame?
    let duckAt: CGPoint
    let cursor: CGPoint
    let ring: Double?
    let caption: String

    private func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: sceneSize.height - p.y) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Color(hex: 0xD9E8F7)
                // A window the user works in.
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 6) {
                        ForEach([0xFF5F57, 0xFEBC2E, 0x28C840] as [UInt32], id: \.self) { Circle().fill(Color(hex: $0)).frame(width: 9, height: 9) }
                    }
                    .padding(.bottom, 6)
                    ForEach([0.9, 0.75, 0.95, 0.6, 0.85, 0.7], id: \.self) { w in
                        RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0xE3E8EF)).frame(width: 220 * w, height: 9)
                    }
                }
                .padding(14)
                .frame(width: 255, height: 170, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 10).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: 0xC5D3E3), lineWidth: 1))
                .offset(x: 40, y: menuBar + 34)
                // Menu bar with the app's drop icon.
                HStack(spacing: 14) {
                    Image(systemName: "applelogo").font(.system(size: 12, weight: .semibold))
                    Text("Work").font(.system(size: 12, weight: .bold))
                    Spacer()
                    Image(systemName: "drop.fill").font(.system(size: 12)).foregroundStyle(Color(hex: 0x1F2937))
                    Text("10:30").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color(hex: 0x1F2937))
                .padding(.horizontal, 12)
                .frame(width: sceneSize.width, height: menuBar)
                .background(Color(hex: 0xF4F7FB))

                if let frame {
                    let c = flip(CGPoint(x: duckAt.x, y: duckAt.y - Layout.ground + Layout.panel.height / 2))
                    DuckView(frame: frame).position(c)
                }
                if let ring {
                    Circle().stroke(Color(hex: 0x339AF0), lineWidth: 2.5)
                        .frame(width: 10 + 40 * ring, height: 10 + 40 * ring)
                        .opacity(1 - ring)
                        .position(flip(cursor))
                }
                Cursor().fill(.black).overlay(Cursor().stroke(.white, lineWidth: 1.2))
                    .frame(width: 13, height: 20)
                    .position(flip(cursor))
                    .offset(x: 6.5, y: 10)
            }
            .frame(width: sceneSize.width, height: sceneSize.height)
            .clipped()

            Text(caption)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: 0x1F2937))
                .frame(width: sceneSize.width, height: 46)
                .background(.white)
        }
    }
}

@MainActor func renderDemo() {
    let screen = Screen(frame: CGRect(origin: .zero, size: sceneSize),
                        visible: CGRect(x: 0, y: 0, width: sceneSize.width, height: sceneSize.height - menuBar))
    let quick = Timings(reminderInterval: 1.5, levelStep: 3.6, awayAfter: 100, longBreak: 100_000, workHours: nil)
    var sim = Sim(timings: quick, screen: screen)
    var frames: [CGImage] = []
    var tick = 0
    var ring: Double?

    func caption(_ d: Duck) -> String {
        switch d.phase {
        case .hidden: "You work at your Mac…"
        case .entering(.chill), .moving(.chill), .waiting(.chill, _): "1 · Chill: it walks in and does little tricks"
        case .entering(.ask), .moving(.ask), .waiting(.ask, _): "2 · Ask: “drink! 💧”"
        case .entering(.thirsty), .moving(.thirsty), .waiting(.thirsty, _): "3 · Thirsty: it sweats and shakes"
        case .asleep: "Away from the Mac? It naps, and the clock stops 💤"
        case .entering(.follow), .moving(.follow), .waiting(.follow, _): "4 · Follow: it walks to your cursor"
        case .happy: "Click it when you drank 💛"
        case .leaving: "…and it comes back in 30 minutes"
        }
    }

    func step(idle: Bool = false) {
        sim.tick(idle: idle)
        tick += 1
        if let r = ring { ring = r + 1.0 / 30 / 0.45; if ring! >= 1 { ring = nil } }
        guard tick % 2 == 0 else { return }
        let d = sim.duck
        let scene = DemoScene(frame: d.isVisible ? sim.frame : nil, duckAt: d.position, cursor: sim.sensors.mouse,
                              ring: ring, caption: caption(d))
        frames.append(image(scene, scale: 1.5))
    }

    // The cursor drifts over the window, as if the user works.
    func work(_ seconds: Double) {
        let n = Int(seconds * 30)
        for _ in 0..<n {
            let t = sim.now.timeIntervalSinceReferenceDate
            sim.sensors.mouse = CGPoint(x: 165 + 55 * sin(t * 0.9), y: 165 + 25 * sin(t * 1.7))
            step()
        }
    }

    func glide(to p: CGPoint, in seconds: Double) {
        let start = sim.sensors.mouse
        let n = Int(seconds * 30)
        for i in 1...n {
            let k = Double(i) / Double(n)
            let e = k * k * (3 - 2 * k)
            sim.sensors.mouse = CGPoint(x: start.x + (p.x - start.x) * e, y: start.y + (p.y - start.y) * e)
            step()
        }
    }

    work(2.0)
    while sim.duck.level < .thirsty || sim.duck.phase != .waiting(.thirsty, nil) { work(1.0 / 30) }
    work(2.0)
    // Away: no input until it naps, then back.
    sim.duck.timings.awayAfter = 0.8
    for _ in 0..<Int(2.6 * 30) { step(idle: true) }
    sim.duck.timings.awayAfter = 100
    while !sim.duck.phase.isFollowing { work(1.0 / 30) }
    glide(to: CGPoint(x: 560, y: 150), in: 1.2)
    glide(to: CGPoint(x: 430, y: 90), in: 1.0)
    for _ in 0..<15 { step() }
    glide(to: CGPoint(x: 250, y: 140), in: 1.2)
    while sim.duck.phase != .waiting(.follow, nil) { step() }
    for _ in 0..<12 { step() }
    // Move to the duck and click it.
    let p = sim.duck.position
    glide(to: CGPoint(x: p.x + 4, y: p.y + 30), in: 0.8)
    for _ in 0..<6 { step() }
    sim.send(.click)
    ring = 0
    while sim.duck.phase == .happy { step() }
    while sim.duck.isVisible { step() }
    for _ in 0..<12 { step() }

    let url = docs.appendingPathComponent("demo.gif")
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil)!
    CGImageDestinationSetProperties(d, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
    let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / 15]] as CFDictionary
    for f in frames { CGImageDestinationAddImage(d, f, frameProps) }
    CGImageDestinationFinalize(d)
    print("demo.gif: \(frames.count) frames")
}

extension DuckPhase {
    var isFollowing: Bool {
        switch self {
        case .entering(.follow), .moving(.follow), .waiting(.follow, _): true
        default: false
        }
    }
}

// MARK: - App icon

struct AppIcon: View {
    let size: CGFloat

    var body: some View {
        let inset = size * 0.1
        let side = size - 2 * inset
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.225, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x8FD0FF), Color(hex: 0x3D8FE0)], startPoint: .top, endPoint: .bottom))
                .frame(width: side, height: side)
            Canvas { ctx, _ in
                ctx.translateBy(x: Sprite.size.width / 2, y: Sprite.size.height)
                Sprite.fill(Sprite.pixels(.classic, standing, t: 0), in: ctx, smooth: false)
            }
            .frame(width: Sprite.size.width, height: Sprite.size.height)
            .scaleEffect(side * 0.62 / Sprite.size.width)
                .offset(x: -side * 0.02, y: side * 0.04)
        }
        .frame(width: size, height: size)
    }
}

@MainActor func renderIcon() {
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
            writePNG(image(AppIcon(size: CGFloat(points)), scale: CGFloat(scale)), iconset.appendingPathComponent(name))
        }
    }
    writePNG(image(AppIcon(size: 256), scale: 2), docs.appendingPathComponent("icon.png"))
}

MainActor.assumeIsolated {
    renderIcon()
    renderStages()
    renderLooks()
    renderDemo()
}
