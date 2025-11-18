---
description: Build the obdii Xcode project
---

# Build Workflow

This workflow builds the obdii iOS application using xcodebuild.

## Prerequisites

- Xcode command line tools installed
- All Swift package dependencies will be resolved automatically

## Build Steps

### 1. List available schemes (optional)

To see all available build schemes:

```bash
xcodebuild -project obdii.xcodeproj -list
```

### 2. Build for Debug configuration

// turbo
```bash
xcodebuild -project obdii.xcodeproj -scheme obdii -configuration Debug clean build
```

### 3. Build for Release configuration

```bash
xcodebuild -project obdii.xcodeproj -scheme obdii -configuration Release clean build
```

### 4. Build for a specific destination (e.g., iPhone simulator)

```bash
xcodebuild -project obdii.xcodeproj -scheme obdii -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' clean build
```

## Build Output

The build artifacts will be located in:
- `~/Library/Developer/Xcode/DerivedData/obdii-*/Build/Products/`

## Common Options

- **Clean build**: Add `clean` before `build` to remove previous build artifacts
- **Show build settings**: Add `-showBuildSettings` to see all build configuration
- **Verbose output**: Add `-verbose` for detailed build logs

## Troubleshooting

If you encounter signing issues, you may need to:
1. Specify a development team: `-DEVELOPMENT_TEAM=<TeamID>`
2. Use automatic signing: `-allowProvisioningUpdates`
3. Build without code signing (for testing): `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO`
