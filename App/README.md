# Cerbo App - Connect Screen

This directory contains the SwiftUI application for the Cerbo GX connection management.

## Project Structure

- **CerboApp.swift**: Main app entry point
- **AppDelegate.swift**: UIApplication delegate
- **SceneDelegate.swift**: UIWindowScene delegate
- **Screens/ConnectScreen.swift**: Main connection screen with:
  - Connection status bar
  - Saved connections list
  - Manual connection form (host, port, TLS toggle, username/password)
  - Add/Edit profile functionality
- **Previews/ConnectScreenPreview.swift**: SwiftUI previews for the UI components

## Features Implemented

1. **Manual Connection**: Enter host IP/hostname, port, TLS toggle, username, and password
2. **Saved Connections**: Persist connection profiles with secure credential storage
3. **Connection Status**: Visual status bar showing connection state and portal ID
4. **Profile Management**: Add, edit, and delete saved connections
5. **Local Network Usage**: Proper Info.plist configuration for local network access

## Dependencies

- **VictronKit**: Core library for Cerbo GX communication
- **CocoaMQTT**: MQTT client library

## Usage

The ConnectScreen provides a complete UI for managing Cerbo GX connections:

1. **Saved Connections**: Tap a saved connection to connect
2. **Manual Connection**: Enter connection details and tap "Connect"
3. **Status**: Monitor connection state and portal ID detection
4. **Management**: Swipe to delete or edit saved connections

## Testing

The ConnectViewModel is tested via integration tests in the VictronKit test suite, which verify:
- Profile storage and retrieval
- Secure credential management
- Connection state management
- Portal ID detection and persistence
