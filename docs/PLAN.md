# Cerbo GX App Development Plan

This plan outlines the steps to build a native Swift app for iPhone and iPad Pro that connects to Victron's Cerbo GX hardware over local Wi-Fi network using MQTT protocol. The app adds LAN-based history charts and multi-device comparison capabilities that VictronConnect lacks, while staying read-only and never contacting the real Cerbo without explicit user approval.

## Step 1: Simulator and Test Fixtures (No Device Contact)

**Goal:** Build a complete test environment without touching the real Cerbo

**What gets built:**
- Local mock MQTT broker or simulator supporting:
  - Plain TCP 1883 and TLS 8883 with username/password
  - Self-signed certificate handling
  - Full publish response with sample devices (solar charger, battery, VE.Bus inverter)
  - History summaries (solar charger daily yield, battery monitor totals)
- Fixture files from Victron's documented MQTT topics (not from the real device)
- Test harness that runs all subsequent tests against the simulator

**How we know it's done:**
- Simulator accepts connections on both 1883 and 8883
- Full publish returns expected topic structure
- History summaries match documented format
- All unit tests pass against simulator

## Step 2: Connection Management

**Goal:** Implement secure MQTT connection with manual host entry

**What gets built:**
- Manual host entry (IP address or hostname) with port and TLS configuration
- Portal ID auto-detection from MQTT messages
- Saved Cerbo configurations with credential storage in Keychain
- Connection status bar
- Keepalive message handling (one R/keepalive every ~30 seconds)
- Support for both plain 1883 and TLS 8883 with username/password

**How we know it's done:**
- Manual connection works with IP address against simulator
- Portal ID is automatically detected from topics
- Saved configurations persist with credentials secured in Keychain
- Connection status updates correctly
- Keepalive messages sent at proper intervals

## Step 3: Live Data Visualization

**Goal:** Display real-time Cerbo GX data with native iOS gestures

**What gets built:**
- Animated power-flow diagram (solar → battery ↔ inverter → AC/DC loads)
- Live overview with watts, SoC, time-to-go, charge state
- Device pages for battery, MPPT solar chargers, inverters/chargers
- Device list with status for all connected devices
- Dark mode and Dynamic Type support

**How we know it's done:**
- Power-flow diagram animates with live data
- All device pages display correct information
- UI adapts to dark mode and Dynamic Type

## Step 4: Charting System

**Goal:** Implement time-series visualization for live and historical data

**What gets built:**
- Rolling 5-minute and 1-hour window charts using Swift Charts
- Multi-series charts with shared time axis
- Pinch-to-zoom, drag-to-pan, and scrub-with-crosshair
- Min/max/avg bands
- Energy bar charts (day, week, month)
- Data sources: rolling live charts use values received while the app is open (kept in memory); day/week/month energy bars use the Cerbo's History/Daily summaries from Step 5

**How we know it's done:**
- Charts display live data with proper time axis
- Zoom and pan gestures work correctly
- Multiple series can be compared on same chart
- Energy bar charts show correct totals

## Step 5: Batched History Fetch on Open

**Goal:** Fetch and cache history summaries when app opens

**What gets built:**
- Batched history fetch from Cerbo's per-device summaries:
  - Solar charger daily yield (History/Daily/<n>/...)
  - Battery monitor totals (History/... cycles, deepest discharge, energy in/out)
  - Topic names to verify against Victron's dbus/MQTT documentation (not against the device)
  - The Cerbo has no minute-level history; detailed history depends on open question 1 (VRM)
- SwiftData cache for fetched history
- Pull-to-refresh for manual history update
- Historical chart rendering from cache
- CSV export for cached data ranges

**How we know it's done:**
- History fetch works against simulator with documented topic names
- Charts show history from cache correctly
- CSV export contains cached data
- Pull-to-refresh updates cache and charts

## Step 6: iPad Pro Layout and Dashboard

**Goal:** Create optimized iPad experience with customizable layout

**What gets built:**
- Multi-column dashboard with customizable tile grid
- Split view with device list and detail panels
- Landscape mode support
- Responsive layout for different iPad sizes

**How we know it's done:**
- Dashboard tiles can be added, removed, and resized
- Split view shows device list and details simultaneously
- Layout adapts correctly to orientation changes

## Step 7: Alarms and Notifications

**Goal:** Display Cerbo GX alarms and notifications

**What gets built:**
- Alarm log with timestamp, level, and message
- Visual indicators for active alarms
- Alarm filtering and search
- Notification preferences

**How we know it's done:**
- Alarms appear in log with correct information
- Visual indicators show active alarm state
- Alarms can be filtered and searched

## Step 8: Diagnostics and Demo Mode

**Goal:** Provide tools for debugging and App Store compliance

**What gets built:**
- Topic explorer showing raw MQTT topics and values
- Searchable topic list
- Demo mode that plays back a simulator session (a real recording replaces it after Step 10)
- Data logging for debugging

**How we know it's done:**
- Topic explorer displays all received topics
- Search finds topics containing specific text
- Demo mode plays back recorded session
- Log files contain useful debugging information

## Step 9: Security Hardening and Read-Only Guarantee

**Goal:** Ensure the app is safe for first contact with real Cerbo

**What gets built:**
- Read-only guarantee: every publish goes through one wrapper that allows only `R/<portalId>/...` topics (keepalive and read requests, which Venus OS needs before it streams data) and rejects `W/` and anything else, with a test proving it. This wrapper is the single seam that phase 2 will extend.
- Connection timeouts and caps on reconnect backoff
- Malformed-payload fuzz tests for topic parser
- Keepalive storm prevention (one R/keepalive every ~30 seconds)
- Certificate pinning for TLS connections
- Credential sanitization in logs

**How we know it's done:**
- Read-only test passes (no W/ messages can be sent)
- Timeouts prevent hanging connections
- Parser handles malformed payloads without crashing
- Keepalive rate is stable under network conditions
- TLS connections use pinned certificates

## Step 10: First Contact with Real Cerbo (Requires User Approval)

**Goal:** Verify app works with real Cerbo GX (read-only, with approval)

**What gets built:**
- Read-only connection to real Cerbo GX
- Recording of ~30 minutes of MQTT traffic
- Comparison with simulator fixtures
- Documentation of any topic differences

**How we know it's done:**
- App connects successfully to real Cerbo
- Recorded traffic matches fixture structure
- Any differences documented for future reference
- No writes sent to device

## Step 11: App Store Preparation

**Goal:** Prepare app for submission

**What gets built:**
- App Store metadata (name, description, keywords)
- Screenshots for all device sizes
- App icon and launch screen
- Privacy policy
- TestFlight distribution setup

**How we know it's done:**
- App Store Connect entry is complete
- Screenshots meet App Store guidelines
- TestFlight builds install successfully
- No App Store violations detected

## Technical Constraints Addressed

- **No Xcode on VM:** Use Swift Package Manager for core logic, generate Xcode project with XcodeGen
- **No real device during development:** Build mock MQTT broker and use documented topic fixtures
- **iOS background limitations:** Design for foreground operation only, no background logging
- **Local Network permissions:** Implement `NSLocalNetworkUsageDescription` (no mDNS services)
- **Read-only guarantee:** all publishes go through one wrapper that allows only `R/` topics; `W/` and anything else are rejected, enforced by tests

## Success Criteria

1. App successfully connects to Cerbo GX over LAN using MQTT
2. Real-time data visualization works with native iOS gestures
3. Historical data fetch and charting functional
4. iPad Pro layout with customizable dashboard implemented
5. Alarms and notifications displayed correctly
6. Demo mode works for App Store submission
7. Read-only guarantee verified by tests
8. Connection handling robust (timeouts, backoff caps)

## Open Questions for the User

1. Should the app integrate with VRM API for detailed history (requires internet)?
2. ~~MQTT library~~ Decided (T-5, 2026-10-14): CocoaMQTT, pinned to an exact version. The connection state machine wraps it.
3. ~~Controls/writes~~ Decided (T-6, 2026-10-14): phase 1 (this whole plan) is read-only. Phase 2 will add interactive features later and is planned separately, after phase 1 ships.
4. ~~Minimum iOS~~ Decided (T-7, 2026-10-14): iOS 17+.

## Victron MQTT facts (checked 2026-10-14)

Sources: [dbus-flashmq README](https://github.com/victronenergy/dbus-flashmq) (the MQTT bridge on Venus OS), [Venus D-Bus paths wiki](https://github.com/victronenergy/venus/wiki/dbus), and [gui-v2](https://github.com/victronenergy/gui-v2) source for paths the wiki doesn't list. All taken from the web; nothing was read from the real Cerbo.

- **Topics.** Notifications: `N/<portalId>/<service>/<instance>/<D-Bus path>`, e.g. `N/<id>/battery/279/Dc/0/Voltage`. Read request: the same topic with `R` first. Write: the same with `W` first (phase 2 only; the app never sends W/ in phase 1). Requests take no wildcards, and an R/ request's payload is ignored, so send it empty.
- **Payload.** JSON `{"value": <number | string | array | null>}`. `{"value": null}` means the value is invalid. **An empty payload (zero bytes, not JSON) means the device disappeared.** The model layer (T-17) must handle that as "device gone", not as a parse error.
- **Not retained.** Nothing is retained on the broker. A new client sees nothing until it sends a keepalive.
- **Keepalive.** `R/<portalId>/keepalive` makes the Cerbo republish every topic it has, ending with `N/<portalId>/full_publish_completed` = `{"value": <unix time>}`. The keepalive times out after 60 s. Use the first keepalive with an empty payload (or `{"keepalive-options": [{"full-publish-completed-echo": "<id>"}]}` on Venus 3.50+ to tag the completion), then every ~30 s send `{"keepalive-options": ["suppress-republish"]}`. That keeps the stream alive without forcing a full republish each time. Full republishes are rate-limited to at most 3 per second. (T-16 must follow this.)
- **Portal ID.** Shown under Settings → VRM online portal → VRM Portal ID on the Cerbo. The app can also learn it from the first `N/<id>/...` message after subscribing to `N/+/#` on the local broker. Subscribe per installation (`N/<portalId>/#`) once it's known.
- **Local broker.** FlashMQ on the Cerbo, plain TCP 1883 and/or TLS 8883 depending on the Cerbo's security settings. The Cerbo's TLS certificate isn't signed by a public CA. Victron ships `venus-ca.crt` (repo) / `/etc/ssl/certs/ccgx-ca.pem` (on the device) for its servers; whether the local broker's certificate chains to it is unverified, so T-35's trust-on-first-use pinning stays the plan.
- **Paths used in phase 1** (relative to the service):
  - system (singleton, instance 0): `Dc/Battery/Soc`, `Dc/Battery/Power`, `Dc/Battery/TimeToGo` (s), `Dc/Pv/Power`, `Ac/ConsumptionOnOutput/L1/Power`, `Ac/ConsumptionOnInput/L1/Power` (`Ac/Consumption/...` is deprecated). `Serial` also exists; it was the legacy keepalive topic.
  - battery: `Dc/0/Voltage` (V), `Dc/0/Current` (A, + = charging), `Dc/0/Power` (W), `Soc` (%), `TimeToGo` (s, capped at 864000 when not discharging), `ConsumedAmphours` (Ah). History: `History/ChargeCycles`, `DeepestDischarge`, `LastDischarge`, `AverageDischarge`, `FullDischarges`, `TotalAhDrawn`, `MinimumVoltage`, `MaximumVoltage`, `TimeSinceLastFullCharge`, `DischargedEnergy`, `ChargedEnergy` (kWh).
  - solarcharger: `Pv/V` (single tracker; `Pv/<n>/V` for multi-tracker), `Yield/Power` (W), `Yield/User` (kWh), `Dc/0/Voltage`, `Dc/0/Current`, `State` (0 Off, 2 Fault, 3 Bulk, 4 Absorption, 5 Float, 6 Storage, 7 Equalize, 252 External control). Daily history `History/Daily/<n>/` (n = 0 is today, about 30 days): `Yield` (kWh), `MaxPower` (W), `MaxPvVoltage` (V), `TimeInBulk`/`TimeInAbsorption`/`TimeInFloat` (minutes, inferred), `MinBatteryVoltage`, `MaxBatteryVoltage`, `MaxBatteryCurrent`. Per tracker: `History/Daily/<n>/Pv/<i>/Yield`.
  - vebus: `Ac/ActiveIn/L1/P`, `Ac/Out/L1/P` (W), `Mode` (1 Charger only, 2 Inverter only, 3 On, 4 Off), `State` (0 Off, 1 Low power, 2 Fault, 3 Bulk, 4 Absorption, 5 Float, 6 Storage, 7 Equalize, 8 Passthru, 9 Inverting, 10 Power assist, 11 Power supply, 244 Sustain, 252 External control).
- **Battery history over the LAN** is device totals, not a time series. Daily solar history is the only per-day series. Detailed history is VRM's (decision card T-3).

## Tools we use instead of hand-building (2026-10-14)

Standing rule from the user: don't reinvent the wheel. Use an established open-source tool or an Apple framework where one fits (see CLAUDE.md).
- Test broker: Mosquitto (EPL/EDL, Homebrew) on 127.0.0.1, started by tests, with a CocoaMQTT fixture replayer (T-11), and TLS/password via Mosquitto config and openssl (T-12).
- MQTT client: CocoaMQTT 2.4.1 (MIT), including its auto-reconnect with capped backoff and MQTT keep-alive (T-16).
- Rolling buffers: swift-collections Deque (Apple, Apache-2.0) (T-23).
- Charts, zoom, pan, scrub: Swift Charts (T-24, T-25), which requires iOS 17. History cache: SwiftData (T-27). Share/CSV: ShareLink + Transferable (T-28). iPad layout: NavigationSplitView, LazyVGrid + draggable/dropDestination (T-29, T-30). Search: .searchable (T-32).
- Fuzzing: Swift Testing parameterized tests with a seeded generator (T-34). Logging redaction: os.Logger privacy. Pinning: SecTrust + CryptoKit via CocoaMQTT's trust callback (T-35).
- Project generation: XcodeGen (T-19). App Store screenshots, metadata and TestFlight: fastlane (MIT) (T-38).

## Decision: minimum iOS 17 (T-7, 2026-10-14)
The user chose iOS 17+. Swift Charts' built-in zoom, pan and scrub (`chartScrollableAxes`, `chartXSelection`) and SwiftData need it. Package.swift declares `.iOS(.v17)` and `.macOS(.v14)` (macOS 14 so `swift test` runs on the Mac with the same APIs). T-19's project.yml must use `deploymentTarget: iOS: "17.0"`.

## Victron alarms (checked 2026-10-15, Venus D-Bus wiki)
battery and vebus publish alarms as `<service>/<instance>/Alarms/<Name>` with 0 = OK, 1 = warning, 2 = alarm. Battery: LowVoltage, HighVoltage, HighCellVoltage, LowCellVoltage, LowStarterVoltage, HighStarterVoltage, LowSoc, HighChargeCurrent, HighDischargeCurrent, HighCurrent, CellImbalance, InternalFailure, HighChargeTemperature, LowChargeTemperature, LowTemperature, HighTemperature, HighInternalTemperature, MidVoltage, Contactor, BmsCable, FuseBlown (`Alarms/Alarm` is deprecated and ignored by the GUI and VRM, so ignore it too). VE.Bus: HighDcCurrent, HighDcVoltage, LowBattery, PhaseRotation, Ripple, TemperatureSensor, plus per phase `Alarms/L1|L2|L3/HighTemperature|LowBattery|Overload|Ripple`. Solar chargers have no /Alarms paths (only /ErrorCode). Fixture: Tests/VictronKitTests/Fixtures/alarms.json (made up from these paths).
