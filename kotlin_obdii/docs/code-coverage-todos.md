# Code Coverage TODOs

Baseline from `.\gradlew.bat :coreApp:test :coreApp:jacocoTestReport`:

- Instruction coverage: 86.41%
- Branch coverage: 70.34%
- Report: `app/build/reports/jacoco/test/html/index.html`

## Improve Core Coverage

- [ ] Review the JaCoCo package report and target the lowest-covered package first.
- [x] Add tests for `com.rheosoft.obdii.bootstrap`, now around 88.76% instruction coverage and 75.00% branch coverage.
- [x] Add tests for untested `com.rheosoft.obdii.core` branches, now around 71.62% branch coverage.
- [x] Add model edge-case tests to improve `com.rheosoft.obdii.models` branch coverage, now around 68.79%.
- [x] Add screen model edge-case tests to improve `com.rheosoft.obdii.screenmodels` branch coverage, now around 72.82%.
- [ ] Re-run `.\gradlew.bat :coreApp:test :coreApp:jacocoTestReport` after each coverage pass.
- [ ] Decide whether to add `jacocoTestCoverageVerification` minimum thresholds once coverage is stable.

## Android Coverage

- [ ] Run `.\gradlew.bat :androidApp:createDebugUnitTestCoverageReport` for Android debug unit-test coverage.
- [ ] Run `.\gradlew.bat :androidApp:createDebugCoverageReport` with an emulator or device connected for instrumentation coverage.
- [ ] Compare Android UI/instrumentation coverage against Flutter parity tests and add missing Kotlin cases.
