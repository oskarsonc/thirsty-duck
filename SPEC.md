# Thirsty Duck

A tiny native macOS app. A pixel duckling walks onto the screen to remind the user to drink water. The longer the user ignores it, the more thirsty and pushy it gets. One click on the duck means "I drank": it is happy and walks away. Nothing else.

Owner wants: native, light, cute, no extra features.

## Character

The pixel duckling from `design-preview.html` (the `pixel` entry in `DUCKS`) is the classic look. Keep its exact pixels and colors.

Each appearance has a new random look. A look combines one of 20 palettes with optional hats (22), glasses (12), outfits (18), and held items (9), in prototype order. Five palettes are rare: golden, rainbow, galaxy, ghost, and robot. A draw selects a rare palette 6% of the time; otherwise it selects a common palette. Each group is uniform. Held items appear 18% of the time, hats 70%, glasses 35%, and outfits 60%. An umbrella prevents a hat. Draw again if the full look matches the previous one.

Golden, rainbow, galaxy, and ghost palettes are animated, as are the propeller cap, halo, scarf, and cape. A skateboard lifts the duck 10 pt. The ghost adds a float of `3 + 3 sin(2.2 w)` pt, where `w` is seconds since the Foundation reference date. The bubble rises by the look's headroom (5 pt per row).

The app draws the look from the design prototype's art (`Sprite.swift`): tables of colored rows for the palettes (with their patterns and eye colors), hats, glasses, outfits (recolored body cells and art behind and in front), held items, and the drink bottle. Layers, back to front: outfit back, item back, body, outfit front, glasses, hat, item front, bottle. An umbrella hides the hat. Art may sit outside the 16 x 14 body: rows -8 to 15, columns -6 to 19. `Frame.lookClock` (12 per second) moves the propeller, halo (bobs one cell), scarf, cape, golden shine and sparkles, rainbow, and galaxy stars. The ghost is drawn at 72% opacity.

`DuckView` draws only from `Frame`, with no timers or SwiftUI animations. Tilt, spin (around the point 35 pt above the feet), and scale are in the duck's own space, inside the mirror. `dx`, jitter, and lift move the sprite; `sink` moves it down. Move particles are emoji placed from the point under the feet. A puddle is a blue ellipse on the ground. The swim water is a wavy pond in front of the duck, with two ripples. Peekaboo clips the sprite at the ground line. The shadow follows `dx`, gets smaller as the duck rises, and is hidden in the water and deep in peekaboo.

Rolls, backflips, and trips add only the lift needed to keep the turned art above the ground line. The bounds include the body, the look's headroom, the effective held item, and the small cell overlap used while turning. Other move curves stay the same.

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

Speech bubble: all pixels, 2 pt each, as option A of the bubble design: a white box with a one-pixel `#2B2B2B` outline and its corners cut by one pixel, a two-row stepped tail under the middle, a black 15% shadow one pixel down and to the right, and the text 4 pixels in from the sides and 3 from the top and bottom. The text uses the pixel font in `PixelFont` (7 rows, variable width, a 1 pixel gap, lowercase drawn as uppercase), color `#2B2B2B`. Emoji and `…` are pixel icons in the same font, in fixed colors. Every character that a bubble can show has a glyph; a test checks this. DuckCore gets the bubble size from the font, so the hit test needs no text measuring. Thirst level 3 uses fill `#FFE3E3` with text `#C92A2A`. It pops in with a small spring scale around its bottom center. Each pixel snaps to whole points, also during the pop, so the bubble stays crisp at 1x and 2x.

Small extras drawn in SwiftUI (emoji text is fine): sweat drops `💦` that fall from the head, `💤` while sleeping, `💧 💛 ✨` that float up on the happy click.

## Thirst levels

The duck comes once every `reminderInterval` of active work time. Then thirst goes up one level every `levelStep` while the user does not click it.

| Level | Where the duck is | What it does | Bubble |
|---|---|---|---|
| 1 Chill | Walks in from the right edge along the real bottom edge of the screen (`frame.minY`, not on top of the Dock, because the Dock may not reach that far) and sits about 140 pt from that edge. | Starts with a spin when the entering walk ends, to show the new look. Then picks a move from the stage table below. | Shows `💧?` now and then, for 3 s, except during move speech. |
| 2 Ask | Walks 300 pt along the bottom toward the middle of the screen (not past the middle), so it stays clear of a bottom Dock. | Picks asking moves from the stage table below. | `drink! 💧`, except during move speech. |
| 3 Thirsty | Stays at the bottom. | Sweat drops and moves from the stage table below. | `so thirsty… 💧💧`, red style. |
| 4 Follow | Leaves the bottom and follows the mouse cursor anywhere on any screen. It stops about 60 pt beside the cursor so it never covers what the user points at, and faces the cursor. Once it stops, it walks again only when the cursor is more than 120 pt from its feet, so a cursor that comes toward it to click it does not push it away. The duck and its bubble, at the top of the pop, stay on the cursor's screen and under its menu bar. On a screen smaller than that, the duck's feet stay on it. | Walks (feet and bob) while moving, shakes when it stops. Sweat drops. | `DRINK WATER! 🥵` |

Stage move selection:

| Stage | Existing moves | New moves | Existing / new weight |
|---|---|---|---|
| Chill | blink, lookBack, hop, wiggle, peck, stroll | moonwalk, spin, backflip, roll, wave, hover, dance, tapDance, jelly, yawn, quack, loaf, lookAround, puddleJump, swim, bow, peekaboo, love, kick, sleepyNod, jumpSpin, skate, juggle, sunbathe | 50% / 50% |
| Ask | hop, wiggle, hopHop | wave, quack, drink, pushUps, zoomies, sneeze, headbang, puddleJump | 50% / 50% |
| Thirsty | shake, blink | dizzy, shiver, trip, sneeze, zoomies | 60% / 40% |
| Follow | shake | none | 100% / 0% |

Each move owns its duration. The gap before the next move starts when the current move ends. Zoomies stays within 45 pt of the resting position on each side. Move speech (`hi!`, `yaawn`, `achoo!`, `quack!`, `glug glug`, `ahh 💙`, `💪`, `brrr`, `boo!`, `oops!`) replaces the stage bubble at Chill and Ask. Thirsty keeps its stage bubble and sweat.

The `newLook` input changes the look while entering, waiting, moving, or asleep. It starts a spin at once when waiting. Hidden, happy, and leaving ducks ignore it. `Duck.canChangeLook` reports the same rule. The look uses the duck's seeded random generator.

Click on the duck in any level means "I drank":
- Happy eyes, hop twice, `💧 💛 ✨` float up, bubble `thank you! 💛`.
- Then it walks off by the right edge of its screen.
- The reminder timer starts again from zero.

Only the duck and its bubble take mouse clicks, where they are drawn: the bubble at its current pop scale, and the box of the body, look headroom, and effective held item. Drawing and hit testing use the same mirror, tilt, spin, scale, and position transform. The panel takes mouse events only while the cursor is on them. It checks on each tick and on each mouse move or drag, so clicks route right between slow ticks. Everything else on the screen must stay fully usable. The duck never takes keyboard focus and never activates the app.

## Away and off-hours

The timer counts only time when the user is at the Mac and inside work hours.

- Away: no mouse or keyboard input for `awayAfter` (5 min). Use `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)`, which needs no permission. Locked screen and display sleep also show as no input.
- Mac sleep: the app gets the `NSWorkspace` sleep and wake notifications. Sleep time is never work. The lid, a key or the mouse wakes the Mac, so a wake after a sleep counts as input. A wake with no sleep before it is a plain tick, and a second sleep changes nothing.
- While away: the timer pauses. If the duck is on screen, it falls asleep where it is (closed eyes, `💤`, no bubble), and thirst does not go up. When the user comes back, it wakes and goes on at the same level.
- Long break: a break runs from the last input to the next one. Input is what the idle counter shows, a click on the duck, `Call the duck now`, or a wake. A break of `longBreak` (30 min) or more, idle time and Mac sleep together, is a fresh start. Hide the duck if it is up, and start the timer from zero.
- Work hours: every day, 08:00 to 23:00 local time by default; the `Active hours` menu changes them. Outside work hours the duck does not come. If it is up when work hours end, it walks away. The timer starts from zero at the next work start.
- Fullscreen apps: the duck shows over them too (all Spaces, fullscreen auxiliary).

## Times (constants in one place)

```
reminderInterval = 30 min  (the menu can change it)
levelStep        = 5 min    (so Follow starts 15 min after the duck arrives)
awayAfter        = 5 min
longBreak        = 30 min
workDays         = every day
workHours        = 08:00-23:00
```

`DUCK_FAST=1` environment variable: demo times (10 s interval, 20 s levels, 10 s away, 30 s long break) and ignore work hours. This is for testing only.

## Menu bar

A small menu bar icon (SF Symbol `drop.fill` or a tiny duck). Menu items:
- `Call the duck now` (starts a reminder at level 1 at once; useful for testing and for the user). It first ends any break, then counts as input.
- `New look now`, right under it, also in fast mode: sends `newLook`. Enabled only when `Duck.canChangeLook`.
- A disabled first line with the status (`Duck.status`): `Next duck in N min` (rounded up), `The duck is here 🦆`, or `Off until HH:MM` (with the weekday if it is not today or tomorrow).
- `Active hours` submenu: `Starts at` 06:00-12:00, `Ends at` 16:00-24:00, and a `Weekends` toggle. Saved; sets `workHours`. Hidden in fast mode.
- `Remind every` submenu: 20, 30, 45 or 60 min. The choice is saved and sets `reminderInterval`. Hidden in fast mode.
- `Show on` submenu, only with more than one screen: the screen the duck comes in on. The main screen by default. Saved by display ID; if that screen is not connected, the main screen is used. Screens with the same name get a number.
- `Open at login` toggle (`SMAppService.mainApp`)
- `Quit`

No Dock icon (`LSUIElement`).

## Technical

- Swift 6, SwiftUI for drawing, AppKit for the window. Swift Package Manager executable, built with Command Line Tools (no Xcode project). The machine has Swift 6.4 and macOS 27 SDK, Apple Silicon.
- A `build.sh` that builds release and makes `build/Thirsty Duck.app` with an `Info.plist` (`LSUIElement=true`, bundle id `dev.oskar.thirstyduck`, minimum macOS 14), and ad-hoc signs it (`codesign -s -`).
- Window: one small borderless, non-activating, transparent `NSPanel` that holds the duck and its bubble and moves with the duck (240 x 240 pt). Level `.statusBar` or above normal windows, `collectionBehavior` `[.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]`, no shadow, `hidesOnDeactivate = false`. Clicks on transparent parts must pass through to the app below. Hide the window when the duck is away.
- One `Timer` on the main run loop in common modes drives everything. The duck says how often it needs a tick (`Duck.tickRate`): 30 Hz while it walks, does a new move, hops, shakes, pops a bubble or is happy, 10 Hz while it sits, blinks, sweats, or shows an animated look, 2 Hz asleep, and 1 Hz hidden. The app redraws only when the picture (`Duck.frame`) changes. The CPU use must be close to zero while the duck is hidden.
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

- Coordinates: AppKit global screen coordinates (origin bottom-left of the main screen). The duck comes in on the screen picked in `Show on`, else on the main screen (the one with the menu bar). In Follow, the duck can cross screens.
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
