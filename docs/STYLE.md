# Offgrid style guide: "Night" v1 (direction B, chosen 2026-10-15)

Dark, high-contrast and calm: a near-black ground, rounded tiles or hairline-divided rows, big tabular numbers and one accent per energy source. Reference mockups: direction B on the first style canvas, and the refined Night screens (first screen/scan, overview, power flow, bottom row) on https://claude.ai/artifact/8a2sXs1HWViatjkVaDq6mi (Dontonio's private canvas). This is the current design (v1); a v2 may follow later. Change this file first, then the code.

## Colors (`App/Theme/OffgridTheme.swift`)

| Token | Hex | Use |
|---|---|---|
| `background` | `#0B0C0E` | the screen ground |
| `surface` | `#141518` | tiles, cards, tab bar |
| `surfaceRaised` | `#222328` | selected tab, ring track, pressed states |
| `hairline` | `#222328` | 1 pt dividers between rows |
| `textPrimary` | `#F4F4F5` | numbers, titles |
| `textSecondary` | `#A1A1AA` | labels, units, captions |
| `solar` | `#F5B945` | everything solar: icon, chart line, flow |
| `battery` | `#34D399` | battery ring, "Charging", battery flow |
| `grid` | `#93C5FD` | grid / generator input |
| `warning` | `#FF9F43` | warnings (alarm level 1), plain-MQTT badge |
| `alarm` | `#FF5C5C` | alarms (level 2), certificate changed |

- One accent per energy source (solar, battery, grid); loads and everything else are white or grey. Warnings and alarms differ in lightness as well as hue, and always come with an icon and a word.
- Dark only for now: set `.preferredColorScheme(.dark)` at the root.

## Type

- Numbers: Apple's rounded system font (SF Pro Rounded, `.fontDesign(.rounded)`), medium weight, `.monospacedDigit()`. Hero number 30 pt in the ring; tile values 30 pt with the unit at 16 pt in `textSecondary`. No font download. Keep it in one place in `OffgridTheme`.
- Text: the system font (SF Pro). Screen title 28 pt semibold; labels 13 pt `textSecondary`; body 15 to 17 pt.
- Support Dynamic Type: scale with `@ScaledMetric`, and let tiles grow rather than truncate.

## Shapes and spacing

- Corner radius: 24 (hero card), 20 (tiles, chart card), 16 (tab pills), 14 (icon buttons).
- Screen padding 20; gap 12 between tiles, 16 between sections. Touch targets at least 44×44.
- No borders, shadows or gradients: depth comes from `surface` on `background`. Lists use rows divided by a 1 pt `hairline`; summaries use tiles. Both are fine on one screen.

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
