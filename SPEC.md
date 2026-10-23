# Thirsty Duck

A tiny native macOS app. A pixel duckling walks onto the screen to remind the user to drink water. The longer the user ignores it, the more thirsty and pushy it gets. One click on the duck means "I drank": it is happy and walks away. Nothing else.

Owner wants: native, light, cute, no extra features.

## Character

The pixel duckling from `../duck-preview.html` (the `pixel` entry in `DUCKS`). Keep these exact pixels and colors.

Colors: `Y #FFD43B` body, `D #FAB005` wing, `O #FF922B` beak and feet, `K #2B2B2B` eye, `W #FFFFFF` eye shine, `P #FF8FA3` blush.

Body map, 16 columns x 12 rows, facing right, `.` is transparent:

```
......YYYY......
.....YYYYYY.....
.....YYYWKY.....
.....YYYKKYOOO..
.....YYPYYYOOO..
......YYYYY.....
.Y...YYYYYY.....
.YY.YYYYYYYY....
.YYYYYDDDYYYY...
.YYYYDDDDYYYY...
..YYYYYYYYYYY...
...YYYYYYYYY....
```

Eyes are cells (row 2-3, col 8-9).
- Closed eyes (blink, sleep): paint those four cells `Y`, and paint (row 3, col 8) and (row 3, col 9) `K`.
- Happy eyes `^`: paint the four eye cells `Y`, then `K` at (3,7), (2,8), (2,9), (3,10).

Feet are two rows under the body (rows 12-13), color `O`. Walk = alternate the two frames at about 6 Hz.
- Frame 1: (12,5) (12,6) (13,4) (13,5) (13,6) (12,9) (12,10) (13,8) (13,9) (13,10)
- Frame 2: (12,5) (12,6) (13,5) (13,6) (13,7) (12,9) (12,10) (13,9) (13,10)

A soft shadow sits under the feet (black, 13% opacity, a flat rounded rect).

Render crisp pixels (no smoothing). Pixel size about 5 pt, so the duck is about 80 x 70 pt. Mirror horizontally to face left.

Motion on top of the pixels (transforms of the whole sprite): walk bob (up 2 pt, small rock), hop (up about 14 pt and back), wiggle (rotate +-8 deg), shake (fast small x jitter).

Speech bubble: white rounded rect above the head with a small tail, rounded bold system font about 13 pt, dark text. Thirst level 3 uses a light red bubble with red text. It pops in with a small spring scale.

Small extras drawn in SwiftUI (emoji text is fine): sweat drops `💦` that fall from the head, `💤` while sleeping, `💧 💛 ✨` that float up on the happy click.

## Thirst levels

The duck comes once every `reminderInterval` of active work time. Then thirst goes up one level every `levelStep` while the user does not click it.

| Level | Where the duck is | What it does | Bubble |
|---|---|---|---|
| 1 Chill | Walks in from the nearest side edge along the bottom of the screen (on top of the Dock, `visibleFrame.minY`) and sits about 140 pt from that edge. | Chills. Every few seconds it does one small trick, picked at random so it changes: blink, look the other way (flip), hop, wiggle, peck (lean forward), short stroll left or right. | Shows `💧?` now and then, for 3 s. |
| 2 Ask | Walks along the bottom toward the middle of the screen. | Tricks are more about asking: hop, wiggle, hop-hop. | `drink! 💧`, always shown. |
| 3 Thirsty | Stays at the bottom. | Sweat drops, shakes now and then, droopy (no hops). | `so thirsty… 💧💧`, red style. |
| 4 Follow | Leaves the bottom and follows the mouse cursor anywhere on any screen. It stops about 60 pt beside the cursor so it never covers what the user points at, and faces the cursor. | Walks (feet and bob) while moving, shakes when it stops. Sweat drops. | `DRINK WATER! 🥵` |

Click on the duck in any level means "I drank":
- Happy eyes, hop twice, `💧 💛 ✨` float up, bubble `thank you! 💛`.
- Then it walks to the nearest side edge and leaves the screen.
- The reminder timer starts again from zero.

Only the duck and its bubble take mouse clicks. Everything else on the screen must stay fully usable. The duck never takes keyboard focus and never activates the app.

## Away and off-hours

The timer counts only time when the user is at the Mac and inside work hours.

- Away: no mouse or keyboard input for `awayAfter` (5 min). Use `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)`, which needs no permission. Locked screen and display sleep also show as no input.
- Mac sleep: a tick that sees a wall-clock gap larger than 60 s counts that gap as away time.
- While away: the timer pauses. If the duck is on screen, it falls asleep where it is (closed eyes, `💤`, no bubble), and thirst does not go up. When the user comes back, it wakes and goes on at the same level.
- Long break: after away time of `longBreak` (30 min) or more, count the break as a fresh start. Hide the duck if it is up, and start the timer from zero.
- Work hours: Monday to Friday, 08:00 to 18:00 local time (constants). Outside work hours the duck does not come. If it is up when work hours end, it walks away. The timer starts from zero at the next work start.
- Fullscreen apps: the duck shows over them too (all Spaces, fullscreen auxiliary).

## Times (constants in one place)

```
reminderInterval = 45 min
levelStep        = 5 min    (so Follow starts 15 min after the duck arrives)
awayAfter        = 5 min
longBreak        = 30 min
workDays         = Mon-Fri
workHours        = 08:00-18:00
```

`DUCK_FAST=1` environment variable: divide every time by 60 (45 s interval, 5 s levels, 5 s away, 30 s long break) and ignore work hours. This is for testing only.

## Menu bar

A small menu bar icon (SF Symbol `drop.fill` or a tiny duck). Menu items:
- `Call the duck now` (starts a reminder at level 1 at once; useful for testing and for the user)
- `Open at login` toggle (`SMAppService.mainApp`)
- `Quit`

No Dock icon (`LSUIElement`).

## Technical

- Swift 6, SwiftUI for drawing, AppKit for the window. Swift Package Manager executable, built with Command Line Tools (no Xcode project). The machine has Swift 6.4 and macOS 27 SDK, Apple Silicon.
- A `build.sh` that builds release and makes `build/Thirsty Duck.app` with an `Info.plist` (`LSUIElement=true`, bundle id `dev.oskar.thirstyduck`, minimum macOS 14), and ad-hoc signs it (`codesign -s -`).
- Window: one small borderless, non-activating, transparent `NSPanel` that holds the duck and its bubble and moves with the duck (about 240 x 200 pt). Level `.statusBar` or above normal windows, `collectionBehavior` `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, no shadow, `hidesOnDeactivate = false`. Clicks on transparent parts must pass through to the app below. Hide the window when the duck is away.
- One 60 Hz tick (a `Timer` on the main run loop in common modes, or `CADisplayLink` from the screen) drives everything. The CPU use must be close to zero while the duck is hidden: stop the 60 Hz tick when hidden and use a 1 s timer for the reminder clock.
- Model the duck as a state machine, not as booleans. Suggested shape:

```swift
enum Thirst: Int { case chill = 1, ask, thirsty, follow }

enum DuckPhase {
    case hidden                       // reminder clock runs
    case entering(Thirst)             // walking in from the edge
    case waiting(Thirst, Trick?)      // at its spot, maybe doing a trick
    case moving(Thirst)               // walking to a new spot (level 2 to the middle, level 4 to the cursor)
    case asleep(Thirst)               // user away
    case happy                        // clicked, short celebration
    case leaving                      // walking off to the edge
}
```

  Keep the pure logic (reminder clock, away detection, work hours, level timing, phase changes) separate from AppKit and SwiftUI, so it can be tested with a fake clock. Add a few unit tests for that logic (`swift test`), for example: thirst rises every level step; away time does not count; a long break resets the clock; off-hours do not start a reminder; a click resets the clock.

- Coordinates: AppKit global screen coordinates (origin bottom-left of the main screen). Use the screen that holds the mouse when the reminder starts. In Follow, the duck can cross screens.
- Keep the code small and plain. No third-party packages. No sound. No settings window.

## Files

```
ThirstyDuck/
  Package.swift
  build.sh
  README.md                 short: what it does, build, run, DUCK_FAST, where the constants are
  Sources/ThirstyDuck/      app (AppKit + SwiftUI)
  Sources/DuckCore/         pure logic (clock, phases, levels)
  Tests/DuckCoreTests/
```
