# Cerbo GX app

## Hard rule: no contact with the real Cerbo
The user's Cerbo GX (at 192.0.2.10) runs a live inverter and battery system. Until the user explicitly approves hardware testing in writing, nobody (Claude, dev or any automated board card) may connect to it, probe it, ping it, scan it or send it anything: no MQTT, Modbus, HTTP, SSH, mDNS or port scans to that address or to `venus.local`.

- All work uses simulated or recorded-fixture MQTT data: a local mock broker or simulator, plus fixture files built from Victron's documented topics.
- Recording real traffic from the device is a later step that needs the user's explicit approval.
- The app must stay read-only (no `W/...` writes) until the user approves controls separately.
- If a task seems to need the real device, stop and ask the user. Don't work around this rule.

## Where things are
- `docs/FEATURES.md`: survey of the existing apps and the feature notes.
- `docs/PLAN.md`: the build plan (Backlog Board card #1).
