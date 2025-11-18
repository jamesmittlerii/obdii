---
description: Build and launch the app in iOS Simulator
---

# iOS Simulator Workflow

This workflow builds the obdii app for the iOS Simulator and launches it.

## Prerequisites

- Xcode and iOS Simulator installed
- Simulator runtime for iOS 26.0 or later

## Workflow Steps

### 1. List available simulators (optional)

To see all available iPhone simulators:

```bash
xcrun simctl list devices available iPhone
```

### 2. Build for iOS Simulator

// turbo
```bash
xcodebuild -project obdii.xcodeproj -scheme obdii -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ./build clean build
```

### 3. Boot the simulator

If the simulator isn't already running, boot it:

```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
```

### 4. Open Simulator app

```bash
open -a Simulator
```

### 5. Install the app

```bash
xcrun simctl install booted ./build/Build/Products/Debug-iphonesimulator/obdii.app
```

### 6. Launch the app

```bash
xcrun simctl launch booted com.rheosoft.obdii
```

## Alternative: Quick Launch

If you've already built the app and just want to relaunch:

```bash
# Terminate if running
xcrun simctl terminate booted com.rheosoft.obdii 2>/dev/null || true

# Launch
xcrun simctl launch booted com.rheosoft.obdii
```

## Available Simulators

Based on your system, you have these simulators available:

**iOS 26.0:**
- iPhone 17 Pro (E3C8E39B-A20B-4036-A2E7-C50D720B45C6) - Currently Booted
- iPhone 17 Pro Max
- iPhone Air
- iPhone 17
- iPhone 16e - Currently Booted

**iOS 26.1:**
- iPhone 17 Pro
- iPhone 17 Pro Max
- iPhone Air
- iPhone 17
- iPhone 16e

**iOS 18.6:**
- iPhone 16 Pro
- iPhone 16 Pro Max
- iPhone 16e
- iPhone 16
- iPhone 16 Plus

## Changing Simulator Device

To use a different simulator, replace `"iPhone 17 Pro"` in the commands above with your preferred device name.

## Troubleshooting

### Simulator won't boot
```bash
# Kill all simulator processes
killall Simulator
xcrun simctl shutdown all

# Try booting again
xcrun simctl boot "iPhone 17 Pro"
```

### App won't install
```bash
# Uninstall first
xcrun simctl uninstall booted com.rheosoft.obdii

# Then reinstall
xcrun simctl install booted ./build/Build/Products/Debug-iphonesimulator/obdii.app
```

### Check app logs
```bash
xcrun simctl spawn booted log stream --predicate 'processImagePath contains "obdii"'
```
