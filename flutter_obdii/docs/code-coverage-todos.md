# Code Coverage TODOs

Baseline from `flutter test --coverage`:

- Line coverage: 90.08% (`1726 / 1916`)
- Report data: `coverage/lcov.info`

## Improve Flutter Coverage

- [ ] Review `coverage/lcov.info` after each test pass and target the lowest-covered files first.
- [x] Add tests for `lib/core/pid_store.dart`, now at 100.00% line coverage.
- [x] Add tests for `lib/core/carplay_bridge.dart`, now at 93.75% line coverage.
- [x] Add widget/view tests for `lib/views/pid_toggle_list_view.dart`, now at 83.84% line coverage.
- [x] Add edge-case coverage for `lib/views/settings_view.dart`, now at 77.14% line coverage.
- [x] Add tests around `lib/core/logger.dart` behavior, now at 98.00% line coverage.
- [ ] Add interaction tests for `lib/views/animated_tap_card.dart` and `lib/views/gauge_detail_view.dart`.
- [ ] Keep `lib/core/obd_connection_manager.dart` under review; it is near the current average but still has meaningful uncovered paths.
- [ ] Decide whether to add a CI coverage threshold once coverage is stable.
