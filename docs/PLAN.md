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
- Read-only guarantee test (client can never publish W/ topics)
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
- **Read-only guarantee:** Architectural constraint enforced by tests, no W/ message publishing

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
2. MQTT library choice: own client on Network.framework vs CocoaMQTT?
3. Should controls/writes (W/ topics) ever be implemented, or stay read-only?
4. What minimum iOS version (iOS 17+ or older)?
