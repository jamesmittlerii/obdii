# Code Coverage TODOs

Baseline from `flutter test --coverage`:

- Line coverage: 80.87% (`1543 / 1908`)
- Report data: `coverage/lcov.info`

## Improve Flutter Coverage

- [ ] Review `coverage/lcov.info` after each test pass and target the lowest-covered files first.
- [ ] Add tests for `lib/core/pid_store.dart`, currently around 9.38% line coverage.
- [ ] Add tests for `lib/core/carplay_bridge.dart`, currently around 21.43% line coverage.
- [ ] Add widget/view tests for `lib/views/pid_toggle_list_view.dart`, currently around 31.18% line coverage.
- [ ] Add edge-case coverage for `lib/views/settings_view.dart`, currently around 70.29% line coverage.
- [ ] Add tests around `lib/core/logger.dart` behavior, currently around 74.00% line coverage.
- [ ] Add interaction tests for `lib/views/animated_tap_card.dart` and `lib/views/gauge_detail_view.dart`.
- [ ] Keep `lib/core/obd_connection_manager.dart` under review; it is near the current average but still has meaningful uncovered paths.
- [ ] Decide whether to add a CI coverage threshold once coverage is stable.
