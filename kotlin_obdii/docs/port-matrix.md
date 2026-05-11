# Flutter -> Kotlin 1:1 Port Matrix

Status legend:
- `todo`: not started
- `in_progress`: active translation
- `ported`: translated with parity checks
- `structural_only`: kept for 1:1 file/symbol parity; no Android runtime equivalent needed

## App Source Mapping

| Flutter source | Kotlin target | Status |
|---|---|---|
| `lib/app_bootstrap.dart` | `app/src/main/java/com/rheosoft/obdii/bootstrap/AppBootstrap.kt` | ported |
| `lib/main.dart` | `app/src/main/java/com/rheosoft/obdii/bootstrap/MainMaterial.kt` | ported |
| `lib/main_material.dart` | `app/src/main/java/com/rheosoft/obdii/bootstrap/MainMaterial.kt` | ported |
| `lib/main_cupertino.dart` | `app/src/main/java/com/rheosoft/obdii/bootstrap/MainCupertino.kt` | structural_only |
| `lib/core/carplay_bridge.dart` | `app/src/main/java/com/rheosoft/obdii/core/CarplayBridge.kt` | ported |
| `lib/core/config_data.dart` | `app/src/main/java/com/rheosoft/obdii/core/ConfigData.kt` | ported |
| `lib/core/obd_connection_manager.dart` | `app/src/main/java/com/rheosoft/obdii/core/ObdConnectionManager.kt` | ported |
| `lib/core/pid_interest_registry.dart` | `app/src/main/java/com/rheosoft/obdii/core/PidInterestRegistry.kt` | ported |
| `lib/core/pid_store.dart` | `app/src/main/java/com/rheosoft/obdii/core/PidStore.kt` | ported |
| `lib/models/obdii_pid.dart` | `app/src/main/java/com/rheosoft/obdii/models/ObdiiPid.kt` | ported |
| `lib/viewmodels/base_view_model.dart` | `app/src/main/java/com/rheosoft/obdii/viewmodels/BaseViewModel.kt` | ported |
| `lib/viewmodels/diagnostics_viewmodel.dart` | `app/src/main/java/com/rheosoft/obdii/viewmodels/DiagnosticsViewModel.kt` | ported |
| `lib/viewmodels/fuel_status_viewmodel.dart` | `app/src/main/java/com/rheosoft/obdii/viewmodels/FuelStatusViewModel.kt` | ported |
| `lib/viewmodels/gauge_detail_viewmodel.dart` | `app/src/main/java/com/rheosoft/obdii/viewmodels/GaugeDetailViewModel.kt` | ported |
| `lib/viewmodels/gauges_viewmodel.dart` | `app/src/main/java/com/rheosoft/obdii/viewmodels/GaugesViewModel.kt` | ported |
| `lib/viewmodels/mil_status_viewmodel.dart` | `app/src/main/java/com/rheosoft/obdii/viewmodels/MilStatusViewModel.kt` | ported |
| `lib/viewmodels/pid_toggle_list_viewmodel.dart` | `app/src/main/java/com/rheosoft/obdii/viewmodels/PidToggleListViewModel.kt` | ported |
| `lib/viewmodels/settings_viewmodel.dart` | `app/src/main/java/com/rheosoft/obdii/viewmodels/SettingsViewModel.kt` | ported |
| `lib/views/dashboard_view.dart` | `app/src/main/java/com/rheosoft/obdii/views/DashboardView.kt` | ported |
| `lib/views/diagnostics_view.dart` | `app/src/main/java/com/rheosoft/obdii/views/DiagnosticsView.kt` | ported |
| `lib/views/fuel_status_view.dart` | `app/src/main/java/com/rheosoft/obdii/views/FuelStatusView.kt` | ported |
| `lib/views/gauge_detail_view.dart` | `app/src/main/java/com/rheosoft/obdii/views/GaugeDetailView.kt` | ported |
| `lib/views/main_scaffold.dart` | `app/src/main/java/com/rheosoft/obdii/views/MainScaffold.kt` | ported |
| `lib/views/main_scaffold_cupertino.dart` | `app/src/main/java/com/rheosoft/obdii/views/MainScaffoldCupertino.kt` | structural_only |
| `lib/views/mil_status_view.dart` | `app/src/main/java/com/rheosoft/obdii/views/MilStatusView.kt` | ported |
| `lib/views/pid_toggle_list_view.dart` | `app/src/main/java/com/rheosoft/obdii/views/PidToggleListView.kt` | ported |
| `lib/views/ring_gauge_widget.dart` | `app/src/main/java/com/rheosoft/obdii/views/RingGaugeView.kt` | ported |
| `lib/views/settings_view.dart` | `app/src/main/java/com/rheosoft/obdii/views/SettingsView.kt` | ported |

## Test Mapping

| Flutter test | Kotlin test target | Status |
|---|---|---|
| `test/core/config_data_test.dart` | `app/src/test/java/com/rheosoft/obdii/core/ConfigDataTest.kt` | ported |
| `test/core/core_bulk_parity_test.dart` | `app/src/test/java/com/rheosoft/obdii/parity/CoreBulkParityTest.kt` | ported |
| `test/core/helpers_test.dart` | `app/src/test/java/com/rheosoft/obdii/core/HelpersTest.kt` | ported |
| `test/core/obd_connection_manager_demo_parity_test.dart` | `app/src/test/java/com/rheosoft/obdii/parity/ObdConnectionManagerDemoParityTest.kt` | ported |
| `test/core/obd_connection_manager_test.dart` | `app/src/test/java/com/rheosoft/obdii/core/ObdConnectionManagerTest.kt` | ported |
| `test/core/pid_interest_registry_test.dart` | `app/src/test/java/com/rheosoft/obdii/core/PidInterestRegistryTest.kt` | ported |
| `test/core/pid_store_test.dart` | `app/src/test/java/com/rheosoft/obdii/core/PidStoreTest.kt` | ported |
| `test/models/obdii_pid_bulk_parity_test.dart` | `app/src/test/java/com/rheosoft/obdii/parity/ObdiiPidBulkParityTest.kt` | ported |
| `test/models/obdii_pid_test.dart` | `app/src/test/java/com/rheosoft/obdii/models/ObdiiPidTest.kt` | ported |
| `test/parity/behavioral_parity_refinement_test.dart` | `app/src/test/java/com/rheosoft/obdii/parity/BehavioralParityRefinementTest.kt` | ported |
| `test/parity/swift_noncarplay_missing_exact_test.dart` | `app/src/test/java/com/rheosoft/obdii/parity/SwiftNoncarplayMissingExactTest.kt` | ported |
| `test/viewmodels/diagnostics_viewmodel_test.dart` | `app/src/test/java/com/rheosoft/obdii/viewmodels/DiagnosticsViewModelTest.kt` | ported |
| `test/viewmodels/fuel_status_viewmodel_test.dart` | `app/src/test/java/com/rheosoft/obdii/viewmodels/FuelStatusViewModelTest.kt` | ported |
| `test/viewmodels/gauge_detail_viewmodel_test.dart` | `app/src/test/java/com/rheosoft/obdii/viewmodels/GaugeDetailViewModelTest.kt` | ported |
| `test/viewmodels/gauges_viewmodel_test.dart` | `app/src/test/java/com/rheosoft/obdii/viewmodels/GaugesViewModelTest.kt` | ported |
| `test/viewmodels/mil_status_viewmodel_test.dart` | `app/src/test/java/com/rheosoft/obdii/viewmodels/MilStatusViewModelTest.kt` | ported |
| `test/viewmodels/pid_toggle_list_viewmodel_test.dart` | `app/src/test/java/com/rheosoft/obdii/viewmodels/PidToggleListViewModelTest.kt` | ported |
| `test/viewmodels/settings_viewmodel_test.dart` | `app/src/test/java/com/rheosoft/obdii/viewmodels/SettingsViewModelTest.kt` | ported |
| `test/views/diagnostic_view_parity_test.dart` | `app/src/test/java/com/rheosoft/obdii/parity/DiagnosticViewParityTest.kt` | ported |
| `test/views/diagnostics_view_test.dart` | `app/src/test/java/com/rheosoft/obdii/views/DiagnosticsViewTest.kt` | ported |
| `test/views/dtc_detail_view_test.dart` | `app/src/test/java/com/rheosoft/obdii/views/DtcDetailViewTest.kt` | ported |
| `test/views/gauge_detail_view_test.dart` | `app/src/test/java/com/rheosoft/obdii/views/GaugeDetailViewTest.kt` | ported |
| `test/views/gauge_list_view_test.dart` | `app/src/test/java/com/rheosoft/obdii/views/GaugeListViewTest.kt` | ported |
| `test/views/gauges_view_parity_test.dart` | `app/src/test/java/com/rheosoft/obdii/parity/GaugesViewParityTest.kt` | ported |
| `test/views/gauges_view_test.dart` | `app/src/test/java/com/rheosoft/obdii/views/GaugesViewTest.kt` | ported |
| `test/views/main_scaffold_test.dart` | `app/src/test/java/com/rheosoft/obdii/views/MainScaffoldTest.kt` | ported |
| `test/views/mil_status_view_parity_test.dart` | `app/src/test/java/com/rheosoft/obdii/parity/MilStatusViewParityTest.kt` | ported |
| `test/views/ring_gauge_view_test.dart` | `app/src/test/java/com/rheosoft/obdii/views/RingGaugeViewTest.kt` | ported |
| `test/views/root_tab_view_test.dart` | `app/src/test/java/com/rheosoft/obdii/views/RootTabViewTest.kt` | ported |
| `test/views/settings_view_test.dart` | `app/src/test/java/com/rheosoft/obdii/views/SettingsViewTest.kt` | ported |
| `test/views/status_views_test.dart` | `app/src/test/java/com/rheosoft/obdii/views/StatusViewsTest.kt` | ported |
| `test/views/view_controller_parity_test.dart` | `app/src/test/java/com/rheosoft/obdii/parity/ViewControllerParityTest.kt` | ported |
| `test/widget_test.dart` | `app/src/test/java/com/rheosoft/obdii/views/WidgetSmokeTest.kt` | ported |

Cupertino test note:
- Current Flutter `test/` suite does not contain Cupertino-only view tests.
- `structural_only` currently applies to Cupertino source mappings only (`main_cupertino`, `main_scaffold_cupertino`).

## Rules

- Do not mark any file `ported` until Kotlin test equivalent is green.
- Any Flutter behavior mismatch requires a note under parity tests before merge.
- Keep Kotlin package names and class names aligned with Flutter symbols where practical.
