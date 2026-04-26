# flutter_obdii

Flutter handset app for the OBDII project.

## Architecture: Swift CarPlay + Flutter Handset

This app keeps CarPlay native in Swift and uses Flutter for the handset UI.

- Swift remains the source of truth for CarPlay templates (`CPTemplate` stack).
- Flutter updates shared settings and gauge preferences.
- A lightweight platform channel sends Flutter-originated changes to iOS.

### Flutter to iOS bridge

- Channel name: `com.jamesmittlerii.obdii/carplay_bridge`
- Methods emitted by Flutter:
  - `settingsChanged`
  - `gaugePreferencesChanged`

### Native notifications posted by `AppDelegate`

When channel messages arrive, `ios/Runner/AppDelegate.swift` posts:

- `CarPlayBridge.settingsChanged` with `userInfo` payload:
  - `units`
  - `connectionType`
  - `autoConnectToOBD`
  - `wifiHost`
  - `wifiPort`
- `CarPlayBridge.gaugePreferencesChanged`

The native Swift target observes the same notifications in
`obdii/carplay/CarPlaySceneDelegate.swift` (while CarPlay is connected): it applies
settings via `obdii/carplay/CarPlayHandsetBridge.swift`, calls
`OBDConnectionManager.shared.updateConnectionDetails()`, reloads `PIDStore` when
gauge prefs change, and refreshes each tab’s templates.
