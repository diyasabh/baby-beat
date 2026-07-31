# Baby Beat

An iOS app that reads a heartbeat through the phone's rear camera and flash, built for parents who want to know their baby is okay while someone else is holding them.

A fingertip resting on the lens with the flash on makes the skin flush and fade with every pulse. The camera watches that tiny change in brightness, and the app counts the beats. No extra hardware, just the phone. The iPhone camera flash measures your heartbeat through your thumb using photoplethysmography (PPG), a technique that detects changes in blood volume just beneath your skin.

All the visuals were generated using Lovart! Watch our Loom video for more.

## Two apps in one

The first question at launch is *who's holding the phone?*, and the answer decides which half of the app you get.

**Parent view** — watch beats arrive from daycare, and ask a caregiver for a check whenever you need one. Taking a reading is deliberately unreachable here; a parent watches and asks, nothing else.

**Caregiver view** — see which parents are waiting, count a beat, send it home. One reading answers everyone who asked.

You can switch sides any time from the profile sheet, which is also how the whole flow is demoable on a single device.

## The mood system

Every reading becomes a mood, and the mood re-tempers the entire interface rather than lighting up one badge.

| Mood | Range | Feels like |
|---|---|---|
| `quiet` | under 75 | worrying, everything turns red |
| `sleepy` | 75–99 | fast asleep |
| `cozy` | 100–160 | calm and cuddly |
| `bouncy` | 161–185 | wiggly and playing |
| `racing` | over 185 | worrying, everything turns red |

A worrying beat flips the hero card, the mood pill, the timeline dot, and the widget's whole sky to alert red, and sends a time-sensitive notification with a line about calling a pediatrician. A calm beat never buzzes a pocket — it lands quietly on the widget, because "everything is fine" is not worth interrupting a day for.

## Widget

Small, medium, and both lock screen families. It shows the latest beat for a parent, or a waiting ask for a caregiver, and carries the same three weathers as the app: everyday sky, butter yellow when someone is asking, alert red when a beat needs eyes. A worrying reading always outranks an ask, so red can never hide behind a request.

## Design

Everything routes through a small set of shared primitives so nothing reads as a one-off:

- `Theme` — one palette, four Quicksand type roles, one easing curve
- `PulsingHeart` — the single heart of the app, live at the real bpm in-app and breathing between timeline entries in the widget
- `BrandIcon` / `BrandLabel` — the hand-drawn icon set, template-rendered so it tints like an SF Symbol
- `CloudCard`, `HeartButton`, `PersonRow`, `BeatHeroCard` — shared across both dashboards

Artwork is hand-drawn: a crayon sky behind every screen, and a colored-pencil heart for the app icon.

## Building

The Xcode project is generated, not committed. You need [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open BabyBeat.xcodeproj
```

The camera pulse reader needs a real device to read an actual fingertip. In the simulator it runs a synthetic signal through the same peak-detection pipeline, so the whole flow is demoable without hardware — see `syntheticTargetBPM` in `App/PulseCameraReader.swift` to pin a specific mood.

Both targets share an App Group (`group.com.diyasabh.babybeat`) so the widget and the app read the same store.

## Not a medical device

Made for peace of mind, not diagnosis. If anything ever feels off, call a pediatrician.
