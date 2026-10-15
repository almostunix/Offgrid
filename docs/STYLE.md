# Offgrid style guide: "Night" (direction B, chosen 2026-10-15)

Dark, high-contrast and calm: a near-black ground, rounded tiles, big tabular numbers and exactly two accents. The reference mockup is direction B on the style canvas (live overview, iPhone 390×844). Dontonio said B "is definitely headed in the right direction", so details may still change; change this file first, then the code.

## Colors (`App/Theme/OffgridTheme.swift`)

| Token | Hex | Use |
|---|---|---|
| `background` | `#0B0D10` | the screen ground |
| `surface` | `#15181D` | tiles, cards, tab bar |
| `surfaceRaised` | `#262A31` | selected tab, ring track, pressed states |
| `textPrimary` | `#F4F5F7` | numbers, titles |
| `textSecondary` | `#9AA0A8` | labels, units, captions (7:1 on `surface`) |
| `solar` | `#F5B544` | everything solar: icon, chart line |
| `battery` | `#3DD6B5` | battery ring, "Charging", battery chart |
| `warning` | `#FF9F43` | warnings (alarm level 1), plain-MQTT badge |
| `alarm` | `#FF5C5C` | alarms (level 2), certificate changed |

- Two accents only (solar, battery). Grid, loads and everything else are white or grey. Warnings and alarms differ in lightness as well as hue, and always come with an icon and a word.
- Dark only for now: set `.preferredColorScheme(.dark)` at the root.

## Type

- Numbers: the system font, medium weight, `.monospacedDigit()`. Hero number 30 pt in the ring; tile values 30 pt with the unit at 16 pt in `textSecondary`. (The mockup uses Space Grotesk; bundling it means downloading the font file, so that waits for Dontonio's OK. Keep the font in one place in `OffgridTheme` so swapping it later is one line.)
- Text: the system font (SF Pro). Screen title 28 pt semibold; labels 13 pt `textSecondary`; body 15 to 17 pt.
- Support Dynamic Type: scale with `@ScaledMetric`, and let tiles grow rather than truncate.

## Shapes and spacing

- Corner radius: 24 (hero card), 20 (tiles, chart card), 16 (tab pills), 14 (icon buttons).
- Screen padding 20; gap 12 between tiles, 16 between sections. Touch targets at least 44×44.
- No borders, shadows or gradients: depth comes from `surface` on `background` only.

## Components (`App/Theme/`)

- `MetricTile(icon, value, unit, label, tint?)`: the 2×2 tiles (Solar, Home loads, Grid, Solar today).
- `BatteryRing(soc, power, state)`: the 120 pt ring with the percentage inside, power and "Charging"/"Discharging" beside it.
- `ChartCard(title, legend)`: a Swift Charts chart in a `surface` card, solar line in `solar`, loads dashed in `textSecondary`.
- `SegmentedTabBar`: the bottom pill bar (Overview, Flow, Devices, History), selected pill `surfaceRaised`.
- `StatusBadge(kind)`: Demo, Not encrypted, Reconnecting, Certificate changed.
- Icons: SF Symbols with 1.6–1.8 pt weight equivalents (`sun.max`, `house`, `bolt`, `chart.bar`, `slider.horizontal.3`), never emoji.

## Rules for dev

- Screens use the theme tokens and components; no hex colors or font names inside screen files.
- Every value shown comes from the store; a missing value shows "–", never 0.
- Keep the existing screens' behaviour; restyle only.
