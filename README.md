# Thirsty Duck

A tiny native macOS app that reminds you to drink water. A pixel duckling walks onto your screen. If you ignore it, it gets more thirsty: first it asks, then it sweats, then it follows your cursor. Click the duck when you drank. It is happy, walks off to the right, and the reminder starts again.

![The duck at each stage: chill, ask, thirsty, follow, asleep, and thank you](docs/stages.png)

## How it works

- The duck comes after 30 minutes of computer use, every day from 08:00 to 23:00. It walks in from the right and sits on the bottom edge of the screen.
- Every 5 minutes that you do not click it, it gets one level more thirsty. At level 4 it follows your cursor. It stops beside the cursor and waits when you move toward it, so you can click it.
- The clock counts only time when you use the Mac. After 5 minutes with no mouse or keyboard input, the clock stops and the duck falls asleep. A break of 30 minutes or more (idle time and Mac sleep together) starts the clock again from zero.
- No network, no permissions, no Dock icon. It uses almost no CPU while it waits.

## Menu

The app has a water drop icon in the menu bar:

- `Call the duck now`
- `Remind every`: 20, 30, 45 or 60 minutes
- `Show on`: the screen the duck comes in on, if you have more than one (screens are matched by name)
- `Open at login`
- `Quit`

To change the hours or the level times, edit `Sources/DuckCore/Timings.swift` and build again.

## Build and install

There is no download. The app is not signed with an Apple Developer ID, so macOS would block a downloaded copy. Build it yourself; it takes a few seconds.

Needs the Swift 6 Command Line Tools (`xcode-select --install`, no Xcode). The app is set to macOS 14 or later, but it is tested only on macOS 27 on Apple Silicon.

```sh
git clone https://github.com/oskarsonc/thirsty-duck.git
cd thirsty-duck
./build.sh                                   # makes "build/Thirsty Duck.app", ad-hoc signed
cp -R "build/Thirsty Duck.app" ~/Applications/
open ~/Applications/"Thirsty Duck.app"
```

Then select `Open at login` in the menu, if you want it.

## Tests

```sh
swift test                 # DuckCore tests (swift-testing; XCTest is not in the Command Line Tools)
```

If `swift test` fails with "plugin for module 'TestingMacros' not found", load the plugin by path:

```sh
swift test -Xswiftc -load-plugin-library \
  -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib
```

## Fast mode for testing

```sh
DUCK_FAST=1 "build/Thirsty Duck.app/Contents/MacOS/ThirstyDuck"
```

Times are short for a demo and work hours are ignored. The duck comes after 10 s and gets more thirsty every 15 s. It sleeps after 10 s with no input, and a 30 s break starts the clock again. Add `DUCK_DEBUG=1` to print each phase and tick rate change to stderr.

## Redraw rate

The app ticks only as often as the duck needs (`Duck.tickRate`): 30 Hz while it walks, hops, shakes, pops a bubble or is happy, 10 Hz while it sits, blinks or sweats, 2 Hz asleep, and 1 Hz hidden. It redraws only when the picture (`Duck.frame`) changes.

## Where things are

- `Sources/DuckCore/Timings.swift` has all times (`Timings.normal`, `Timings.fast`), the work hours, and the speeds and distances (`Motion`).
- `Sources/DuckCore/Duck.swift` is the state machine. Every phase change goes through `Duck.step`.
- `Sources/DuckCore/Frame.swift` turns the duck into the picture to draw and the tick rate. `Layout.swift` has the panel geometry and the click regions.
- `Sources/ThirstyDuck` is the app. It reads the system, sends ticks and clicks to the duck, and draws it. `Settings.swift` keeps the two menu choices.

## License

MIT. See `LICENSE`.
