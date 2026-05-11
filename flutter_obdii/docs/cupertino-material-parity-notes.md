# Cupertino / Material Parity Notes

The Material and Cupertino flavors should differ by UI style only. As of the
current review, shared bootstrap, providers, and localization are aligned, while
the areas below are worth revisiting when parity issues appear.

## Worth Investigating

- **App-root theming/defaults:** `main_material.dart` uses `AppTheme.lightTheme`,
  `AppTheme.darkTheme`, and `ThemeMode.system`. `main_cupertino.dart` only sets a
  `CupertinoThemeData(primaryColor: ...)`. Shared screens still use some
  Material widgets, so inherited `Theme` defaults may diverge beyond visual
  styling.

- **Tab/navigation behavior:** Material uses `IndexedStack`; Cupertino uses
  `CupertinoTabScaffold` and `CupertinoTabController`. This can affect nested
  navigation stacks, route lifetime, back behavior, and the timing of `isActive`
  updates for Gauges, Fuel, MIL, and DTC screens.

- **Selected-tab persistence timing:** Both shells now use `SharedPreferences`
  key `ui.selectedTab`. Material persists only on explicit tab selection.
  Cupertino persists on any controller index change, including programmatic
  restore. This is probably harmless, but it is not perfectly identical.

- **Flavor entry points vs `lib/main.dart`:** `lib/main.dart` wires
  `flutter_obd2` logging into the app logger and detects `"Setting up vehicle"`
  messages. `main_material.dart` and `main_cupertino.dart` both skip that bridge.
  This is not a Material-vs-Cupertino difference, but it is a flavor-vs-default
  behavior gap if the flavor entry points are the real launch targets.

- **Test coverage asymmetry:** Material has broader scaffold/navigation tests.
  Cupertino has selected-tab persistence tests, but fewer parity/navigation
  behavior tests. Useful future coverage would include paired tests for tab
  labels, active-tab visibility, and route behavior across both shells.

## Currently Aligned

- Both flavor entry points call `bootstrapObdApp()`.
- Both use the same `ObdAppProviders` provider list.
- Both use the same localization delegates and supported locale.
- Both persist the selected root tab with `ui.selectedTab`.
