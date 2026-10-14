# Cerbo GX app — feature survey and plan notes (2026-10-14)

Goal: a native Swift app for iPhone and iPad Pro that connects to the user's Victron Cerbo GX over the local Wi-Fi network (no Bluetooth) and is much stronger than Victron's apps at visualizing data. Claude plans and reviews; dev writes the code.

## 1. What Victron's apps already do

### VictronConnect (local app, Bluetooth-first)
- **Live data** per product: MPPT solar chargers, battery monitors (SmartShunt/BMV), inverters/chargers, Smart chargers, etc.
- **On-device history:**
  - MPPT chargers: 30 days of daily records.
  - Battery monitors: "trends" graphs over up to 45 days, two parameters at a time (Smart Battery Sense: 6 months).
  - This only covers what each product stores itself, and you can only read it while connected to that product.
- **Settings and firmware updates.** VE.Bus inverter/chargers can't be configured from an iPhone or iPad, because that needs an MK3-USB adapter.
- **GX device screen:**
  - network and Wi-Fi access-point settings;
  - a link to VRM;
  - Remote Console, which is a remote view of the Cerbo's own screen.
- **Over the LAN:** the app finds the GX and opens its Remote Console. Newer versions (VictronConnect 6.12 with Venus OS 3.52) can also open the products attached to the Cerbo over the LAN.
- **Through VRM:** "VictronConnect-Remote" opens attached products, but it needs internet at the site, and VE.Bus products are read-only.
- **Demo mode.**

### VRM app (cloud)
- **Requires internet** at the site and a VRM account. It doesn't work over the LAN alone.
- **Installation list**, with status and details for each site.
- **Alarm push notifications.**
- **Home-screen widgets**, fixed sizes on iOS:
  - SoC, alarm status, DC/AC loads and solar;
  - temperature and humidity;
  - tank levels;
  - EV charger (mode, current, on/off);
  - ESS (mode, minimum SoC);
  - generator start.
- **Widget refresh is slow on iOS**, because the system decides when widgets update.
- **The deeper charts are in the VRM web portal**, not the app.

### Remote Console / gui-v2 (on the Cerbo itself, at `http://venus.local/gui-v2/`)
- Overview and "brief" pages, device list, all settings, notifications.
- This is the most complete LAN-only option, but it's a copy of the device's small screen: there are no historical charts and no layout for iPad.

### Gaps our app can fill
1. **No history over the LAN.** History is either the small amount stored on each device (read one device at a time) or VRM (which needs internet).
2. **No charts over time that compare devices**, for example solar output vs load vs SoC on one time axis.
3. **No dashboard designed for the iPad**, and no way to arrange a custom one.
4. **The LAN experience is just the device screen** (Remote Console). It has no native gestures, dark mode handling or Dynamic Type.
5. **Widgets and alerts depend on the cloud.**

## 2. How the app will talk to the Cerbo (LAN only)
- **Use MQTT.** The Cerbo runs a broker (FlashMQ) on the LAN:
  - TCP 1883 (plain) and/or 8883 (TLS), depending on the Cerbo's security profile.
  - Turn it on under **Settings → Services → MQTT** (Venus OS 3.20+).
  - The Cerbo's own web UI also uses MQTT over WebSocket at `ws://<cerbo>:9001`.
- **Topics.** Each value is published as `N/<portalId>/<service>/<instance>/<path>`, with a JSON payload `{"value": …}`.
  - `null` means the value is invalid. An empty payload means the device has gone.
  - The portal ID is shown under Settings → VRM online portal. It can also be learned from the first `N/+/…` message.
- **No retained messages.** After subscribing, the app sends `R/<portalId>/keepalive`:
  - the first request triggers a full publish, ending with `N/<portalId>/full_publish_completed`;
  - the app then resends it every ~30 s with `{"keepalive-options":["suppress-republish"]}`, because the timeout is 60 s;
  - every topic is sent, so the app filters on its own side.
- **Writes** (controls) go to `W/<portalId>/…` with `{"value": …}` and the retain flag off.
- **Finding the Cerbo.** It answers to `venus.local` (mDNS). Some networks don't resolve that name, so manual IP entry is required too, and a DHCP reservation is recommended.
- **iOS requirements:**
  - a Local Network permission prompt (`NSLocalNetworkUsageDescription`, plus `NSBonjourServices` if we browse);
  - ATS (App Transport Security) is not involved for raw TCP MQTT.
- **Alternative: Modbus TCP** (port 502). It has fixed register maps and is less complete than MQTT, so it's not recommended.
- **Client:** a small MQTT 3.1.1 client on Network.framework (CONNECT, SUBSCRIBE, PUBLISH at QoS 0, PINGREQ) is about 400 lines and fully testable. The other option is a package such as CocoaMQTT; that's a decision for the user, see §5.

## 3. The history problem (the key design decision)
The Cerbo doesn't serve history over the LAN, and iOS suspends apps in the background, so the app can only record while it's open. Options:
- **A. Record on the phone/iPad while the app is open** (SwiftData or SQLite, compacted to 1-minute averages). Simple, but it leaves gaps.
- **B. A small always-on logger on the LAN** that subscribes to MQTT 24/7, stores the data, and serves it to the app. It could run on a Mac, a Raspberry Pi, or the Cerbo itself (Venus OS Large has Node-RED). This gives full history and enables background alerts.
- **C. Read past data from the VRM API** when internet is available, to fill gaps. This is optional and needs a VRM token.

Recommendation: build A in phase 1, with a storage layer that B and C can plug into later.

## 4. Proposed features
**Phase 1: monitor and visualize (read-only)**
- **Connect screen:** `venus.local` or manual IP, port/TLS, portal-ID auto-detect, reconnect with backoff, a connection status bar, and saved Cerbos.
- **Live overview:** an animated power-flow diagram (solar → battery ↔ inverter → AC loads / DC loads, grid/shore, generator) with watts, SoC, time-to-go, and charge state.
- **Device pages,** built automatically from what's on the bus:
  - battery (V, A, W, SoC, consumed Ah, temperature, alarms);
  - each MPPT (PV V/W, per-tracker yield, charge state, today's/yesterday's yield);
  - inverter/charger (mode, AC in/out, limits);
  - tanks, temperature sensors, and the Cerbo's relays.
- **Live charts** using Swift Charts: a rolling 5 min / 1 h window for any value, with several series on a shared time axis.
- **History charts** from the app's own recording:
  - pinch to zoom, drag to pan, scrub with a crosshair;
  - min/max/avg bands;
  - day, week and month energy bars (solar yield, consumption, grid in, battery cycles).
- **iPad Pro layout:** a multi-column dashboard with a customizable tile grid (add, remove, resize), landscape, and a split view of device list and detail.
- **iPhone layout:** compact tabs for Overview, Charts, Devices and Settings.
- **Alarms and notifications** from the Cerbo, shown in the app with a log.
- **Units, dark mode, Dynamic Type, VoiceOver labels on charts.**
- **Topic explorer** (diagnostics): every raw topic and value, searchable.
- **Demo mode** that plays back a recorded session. It's needed for the App Store, for tests, and for working without the Cerbo.
- **CSV export** of any chart range.

**Phase 2: control and extras**
- **Controls,** each behind a confirmation:
  - inverter/charger mode (on / off / charger only / inverter only);
  - AC input current limit;
  - ESS mode and minimum SoC;
  - relay toggles;
  - generator start/stop.
- **The always-on logger (B),** with background alerts, plus Home-screen widgets and a Live Activity fed by it.
- **VRM history backfill (C).**
- **Custom alert rules**, e.g. "SoC < 30%" or "solar yield today < X".
- **Mac (Catalyst / native) and Apple Watch complications.**

## 5. Build and test constraints found
- **No Xcode on this VM.** Only the Command Line Tools are installed, and their `swift package` / `swift test` crash (a broken SwiftPM install). Building an iOS app needs full Xcode, which needs the user's Apple ID to download. The VM has 255 GB free.
- **Planned layout:**
  - all the logic (MQTT client, topic parsing, data model, recorder, aggregation) in a Swift package `VictronKit` that dev can unit-test with `swift test` / `xcodebuild test`;
  - a thin SwiftUI app target on top, generated with XcodeGen so dev never edits `.pbxproj` files;
  - UI checked in the iOS Simulator.
- **The VM is behind NAT** (a private NAT address), so `venus.local` won't resolve here. A Cerbo IP address should still work from the VM and the Simulator; to be checked.
- **Installing on a real iPhone/iPad:** a free Apple ID lets the app run for 7 days per install; the paid developer program ($99/yr) lasts a year and allows TestFlight.
- **Test data:** record ~30 min of real MQTT traffic from the Cerbo once. It serves as unit-test fixtures and as the demo-mode recording, so dev's tests never need the real device.

## 6. Questions for the user
1. Which existing app did you mean: VictronConnect or VRM? Which missing features bother you most?
2. What's connected to the Cerbo (MPPTs, SmartShunt/BMS, MultiPlus/Quattro, tanks, sensors, generator, grid/shore)? What's its IP address and Venus OS version?
3. Is MQTT on LAN enabled, and which security profile is set (plain 1883 or TLS/password 8883)?
4. Read-only first, or should controls be in phase 1?
5. Is there an always-on computer on that network that could run the logger (option B)?
6. Are you OK installing Xcode in this VM? Do you have a paid Apple developer account?
7. Should the minimum iOS version be iOS 26 only, or older too?
