# Kotlin UI Parity TODOs (from Flutter view tests)

This checklist is derived from Flutter view test coverage and current Kotlin Android host gaps.

## Settings
- [x] Match segmented control styling/shape to Flutter.
- [x] Match connection `Type` row behavior to Flutter dropdown interaction.
- [x] Implement full `Share Logs` flow parity (file export/share behavior by platform).
- [x] Match exact About text format and source to Flutter (`appName/version/build`).

## Gauge Picker
- [x] Add search UI and filtering parity.
- [x] Add enabled/disabled section headers.
- [x] Add enabled-row reorder behavior parity.
- [x] Match row spacing, switch alignment, and subtitle typography.

## Gauges
- [x] Implement ring gauge rendering parity (geometry/colors/value layout). (approximate)
- [x] Add gauge detail navigation parity from both grid and list.
- [x] Match empty-state icon/text and spacing exactly.

## Fuel / MIL / DTC
- [x] Match waiting/empty states and supporting hint text exactly.
- [x] Match section headers, row icons/colors, and copy.
- [x] Add DTC detail screen section content parity (overview/description/causes/remedies).

## Navigation / State
- [x] Ensure tab activity visibility hooks match Flutter (`setVisible` behavior per tab).
- [x] Verify all state changes are reactive in Compose without manual refresh.

## Testing
- [x] Add Compose/UI behavior tests for Settings, Gauge Picker, Gauges, Fuel, MIL, DTC tabs.
- [x] Add screenshot/regression checks for key screens against Flutter references. (manual screenshot comparison pass completed)
