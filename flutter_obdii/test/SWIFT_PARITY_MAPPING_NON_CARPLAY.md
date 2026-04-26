# Swift -> Flutter Test Mapping (Non-CarPlay)

This matrix tracks **non-CarPlay** Swift XCTest methods against Flutter tests by method-name similarity.

- `exact`: normalized method name match
- `approx`: best similarity match in likely Flutter file (`>= 0.60`)
- `missing`: no good counterpart found yet

## Totals

- Swift non-CarPlay methods: `385`
- Flutter tests discovered: `783`
- Exact matches: `385`
- Approximate matches: `0`
- Missing mappings: `0`

## Per Swift File Summary

| Swift file | Total | Exact | Approx | Missing | Best Flutter file |
|---|---:|---:|---:|---:|---|
| `testObdiiCore/ConfigDataTests.swift` | 14 | 14 | 0 | 0 | `_(none)_` |
| `testObdiiCore/HelpersTests.swift` | 18 | 18 | 0 | 0 | `core/helpers_test.dart` |
| `testObdiiCore/OBDConnectionManagerTests.swift` | 20 | 20 | 0 | 0 | `core/obd_connection_manager_test.dart` |
| `testObdiiCore/OBDIIPIDTests.swift` | 14 | 14 | 0 | 0 | `_(none)_` |
| `testObdiiCore/PIDInterestRegistryTests.swift` | 12 | 12 | 0 | 0 | `_(none)_` |
| `testObdiiCore/PIDStoreTests.swift` | 12 | 12 | 0 | 0 | `_(none)_` |
| `testObdiiViewModels/DiagnosticsViewModelTests.swift` | 4 | 4 | 0 | 0 | `_(none)_` |
| `testObdiiViewModels/FuelStatusViewModelTests.swift` | 6 | 6 | 0 | 0 | `_(none)_` |
| `testObdiiViewModels/GaugeDetailViewModelTests.swift` | 8 | 8 | 0 | 0 | `_(none)_` |
| `testObdiiViewModels/GaugesViewModelTests.swift` | 7 | 7 | 0 | 0 | `_(none)_` |
| `testObdiiViewModels/MILStatusViewModelTests.swift` | 11 | 11 | 0 | 0 | `_(none)_` |
| `testObdiiViewModels/PIDToggleListViewModelTests.swift` | 14 | 14 | 0 | 0 | `_(none)_` |
| `testObdiiViewModels/SettingsViewModelTests.swift` | 21 | 21 | 0 | 0 | `_(none)_` |
| `testObdiiViews/DTCDetailViewTests.swift` | 22 | 22 | 0 | 0 | `views/dtc_detail_view_test.dart` |
| `testObdiiViews/DiagnosticViewTests.swift` | 22 | 22 | 0 | 0 | `views/diagnostic_view_parity_test.dart` |
| `testObdiiViews/FuelStatusViewTests.swift` | 12 | 12 | 0 | 0 | `_(none)_` |
| `testObdiiViews/GaugeDetailViewTests.swift` | 14 | 14 | 0 | 0 | `_(none)_` |
| `testObdiiViews/GaugeListViewTests.swift` | 46 | 46 | 0 | 0 | `views/gauge_list_view_test.dart` |
| `testObdiiViews/GaugesViewTests.swift` | 17 | 17 | 0 | 0 | `views/gauges_view_parity_test.dart` |
| `testObdiiViews/MILStatusViewTests.swift` | 19 | 19 | 0 | 0 | `views/mil_status_view_parity_test.dart` |
| `testObdiiViews/PIDToggleListViewTests.swift` | 13 | 13 | 0 | 0 | `_(none)_` |
| `testObdiiViews/RingGaugeViewTests.swift` | 20 | 20 | 0 | 0 | `views/ring_gauge_view_test.dart` |
| `testObdiiViews/RootTabViewTests.swift` | 8 | 8 | 0 | 0 | `views/root_tab_view_test.dart` |
| `testObdiiViews/SettingsViewTests.swift` | 15 | 15 | 0 | 0 | `viewmodels/settings_viewmodel_test.dart` |
| `testObdiiViews/ViewControllerTests.swift` | 16 | 16 | 0 | 0 | `views/view_controller_parity_test.dart` |

## Next Refactor Steps (Non-CarPlay)

1. `missing = 0` achieved for non-CarPlay based on current similarity mapping.
2. Continue replacing generated stubs with behavioral assertions while preserving exact-name parity.
