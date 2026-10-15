# Offgrid

A native iPhone and iPad app that shows live data and history from a **Victron Energy Cerbo GX** over your local network, using the Cerbo's built-in MQTT broker. No cloud account is needed.

> Offgrid is an independent project. It is not made by, affiliated with or endorsed by Victron Energy.

## What it does (phase 1, read-only)

- **Connect** to a Cerbo on your LAN (plain MQTT 1883 or TLS 8883), with saved connections and passwords in the Keychain (this device only).
- **Trust on first use** for TLS: shows the Cerbo's certificate fingerprint, pins it, and refuses to connect if it ever changes.
- **Live overview, power flow, devices, alarms and a raw topic explorer.**
- **Live charts** (5 min / 1 h) and **energy history** (daily solar yield, 7 or 30 days) cached on the device.
- **CSV export** through the share sheet.
- **Demo mode** with bundled sample data, so you can try it without a Cerbo.

Phase 1 never writes to the Cerbo: every message the app sends goes through one guard that only allows `R/` (read) topics, and an end-to-end test checks that no `W/` topic ever reaches the broker. Controls are planned for a later phase.

## Requirements

- iOS / iPadOS 17 or later
- A recent Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- On the Cerbo: MQTT enabled in its settings (under Services or Integrations, depending on the Venus OS version). TLS (8883) is recommended; with plain MQTT and a password, the app warns you that the password is sent unencrypted.
- For the tests: [Mosquitto](https://mosquitto.org) (`brew install mosquitto`) and `openssl`; the test broker runs on 127.0.0.1 with throwaway certificates it generates itself.

## Build and test

```bash
swift test                                  # the VictronKit library and its tests (macOS)
xcodegen generate                           # creates Offgrid.xcodeproj
open Offgrid.xcodeproj                      # run the Offgrid scheme on a simulator or device
```

## Layout

- `Sources/VictronKit` – MQTT connection (CocoaMQTT), topic parsing, live data and history stores, read-only publisher, pinning, CSV, demo player.
- `App/` – the SwiftUI app (screens only).
- `Tests/VictronKitTests` – unit, fuzz and broker tests with fixtures based on Victron's documented MQTT topics.
- `docs/PLAN.md`, `docs/FEATURES.md` – the plan and feature notes.

## License

BSD 3-Clause, see [LICENSE](LICENSE).
