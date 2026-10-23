# Thirsty Duck

A pixel duckling walks onto your screen to remind you to drink water. It walks in from the right edge and sits on top of the Dock. If you ignore it, it gets more thirsty: first it asks, then it sweats, then it follows your cursor. Click the duck when you drank. It is happy and walks off to the right, and the reminder starts again.

The reminder counts only work time: Monday to Friday, 08:00 to 18:00, while you use the Mac. After 5 minutes with no input the duck falls asleep and the clock stops. Mac sleep counts as part of the break. A break of 30 minutes or more, counted from your last input, starts the clock again from zero.

The app has a menu bar icon with `Call the duck now`, `Open at login` and `Quit`. It has no Dock icon and no settings.

## Build

Needs macOS 14 or later and the Swift 6 Command Line Tools (no Xcode).

```sh
./build.sh                 # makes "build/Thirsty Duck.app", ad-hoc signed
open "build/Thirsty Duck.app"
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

All times are divided by 60 and work hours are ignored. The duck comes after 45 s and gets more thirsty every 5 s. It sleeps after 5 s with no input. Add `DUCK_DEBUG=1` to print each phase and tick rate change to stderr.

## Redraw rate

The app ticks only as often as the duck needs (`Duck.tickRate`): 30 Hz while it walks, hops, shakes, pops a bubble or is happy, 10 Hz while it sits, blinks or sweats, 2 Hz asleep, and 1 Hz hidden. It redraws only when the picture (`Duck.frame`) changes.

## Where things are

- `Sources/DuckCore/Timings.swift` has all times (`Timings.normal`, `Timings.fast`), the work hours, and the speeds and distances (`Motion`).
- `Sources/DuckCore/Duck.swift` is the state machine. Every phase change goes through `Duck.step`.
- `Sources/DuckCore/Frame.swift` turns the duck into the picture to draw and the tick rate. `Layout.swift` has the panel geometry and the click regions.
- `Sources/ThirstyDuck` is the app. It reads the system, sends ticks and clicks to the duck, and draws it.
