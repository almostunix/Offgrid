# Cerbo GX App Development Plan

This plan outlines the steps to build a native Swift app for iPhone and iPad Pro that connects to Victron's Cerbo GX hardware over local Wi-Fi network using MQTT protocol, addressing the gaps identified in existing Victron apps.

## Step 1: Project Setup and Core Infrastructure

**Goal:** Establish project structure and implement MQTT communication

**What gets built:**
- Swift Package Manager project with VictronKit framework
- Xcode project generated with XcodeGen
- MQTT 3.1.1 client using Network.framework (CONNECT, SUBSCRIBE, PUBLISH at QoS 0, PINGREQ)
- Topic parsing for `N/<portalId>/<service>/<instance>/<path>` format
- Connection management with automatic reconnect and backoff
- Data models for Cerbo devices and measurements

**How we know it's done:**
- MQTT client connects to Cerbo GX and receives topic updates
- Topic parsing correctly extracts device data
- Connection state machine handles reconnects properly
- Unit tests pass for MQTT client and data models

## Step 2: Connection Discovery and Management

**Goal:** Implement Cerbo GX discovery and connection configuration

**What gets built:**
- mDNS discovery for `venus.local`
- Manual IP entry with port and TLS configuration
- Portal ID auto-detection from MQTT messages
- Saved Cerbo configurations
- Connection status bar
- Keepalive message handling (every 30 seconds)

**How we know it's done:**
- App discovers Cerbo GX via mDNS
- Manual connection works with IP address
- Portal ID is automatically detected
- Saved configurations persist between app launches
- Connection status updates correctly

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
- Data updates in real-time with <100ms latency

## Step 4: Charting System

**Goal:** Implement time-series visualization for live and historical data

**What gets built:**
- Rolling 5-minute and 1-hour window charts using Swift Charts
- Multi-series charts with shared time axis
- Pinch-to-zoom, drag-to-pan, and scrub-with-crosshair
- Min/max/avg bands
- Energy bar charts (day, week, month)

**How we know it's done:**
- Charts display live data with proper time axis
- Zoom and pan gestures work correctly
- Multiple series can be compared on same chart
- Energy bar charts show correct totals

## Step 5: History Recording and Management

**Goal:** Store and retrieve historical data while app is open

**What gets built:**
- SwiftData storage for time-series measurements
- Data compaction to 1-minute averages
- Historical chart rendering
- CSV export for any chart range
- Data gap handling

**How we know it's done:**
- Historical data persists between app sessions
- Charts show historical data correctly
- CSV export contains expected data
- Data compaction reduces storage usage

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
- Demo mode with recorded MQTT session playback
- Data logging for debugging

**How we know it's done:**
- Topic explorer displays all received topics
- Search finds topics containing specific text
- Demo mode plays back recorded session
- Log files contain useful debugging information

## Step 9: Testing and Optimization

**Goal:** Ensure reliability and performance

**What gets built:**
- Unit tests for MQTT client, data models, and storage
- Integration tests for data flow and UI
- Mock MQTT server for testing without real device
- Performance optimization for chart rendering
- Memory usage optimization

**How we know it's done:**
- Test coverage >80% for critical components
- All tests pass consistently
- Chart rendering maintains 60 FPS
- Memory usage <100MB during typical use

## Step 10: App Store Preparation

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
- **No real device during development:** Build mock MQTT server and use recorded test data
- **iOS background limitations:** Design for foreground operation, plan for phase 2 logger
- **Local Network permissions:** Implement `NSLocalNetworkUsageDescription` and `NSBonjourServices`

## Success Criteria

1. App successfully connects to Cerbo GX over LAN using MQTT
2. Real-time data visualization works with native iOS gestures
3. Historical data recording and charting functional
4. iPad Pro layout with customizable dashboard implemented
5. Alarms and notifications displayed correctly
6. Demo mode works for App Store submission
7. Test coverage >80% for critical components
8. Performance meets iOS standards (60 FPS, <100MB memory)
