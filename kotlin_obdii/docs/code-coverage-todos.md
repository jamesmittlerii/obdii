# Code Coverage TODOs

Baseline from `.\gradlew.bat :coreApp:test :coreApp:jacocoTestReport`:

- Instruction coverage: 74%
- Branch coverage: 53%
- Report: `app/build/reports/jacoco/test/html/index.html`

## Improve Core Coverage

- [ ] Review the JaCoCo package report and target the lowest-covered package first.
- [ ] Add tests for `com.rheosoft.obdii.bootstrap`, currently around 53% instruction coverage.
- [ ] Add tests for untested `com.rheosoft.obdii.core` branches, currently around 41% branch coverage.
- [ ] Add model edge-case tests to improve `com.rheosoft.obdii.models` branch coverage.
- [ ] Add screen model edge-case tests to improve `com.rheosoft.obdii.screenmodels` branch coverage.
- [ ] Re-run `.\gradlew.bat :coreApp:test :coreApp:jacocoTestReport` after each coverage pass.
- [ ] Decide whether to add `jacocoTestCoverageVerification` minimum thresholds once coverage is stable.

## Android Coverage

- [ ] Run `.\gradlew.bat :androidApp:createDebugUnitTestCoverageReport` for Android debug unit-test coverage.
- [ ] Run `.\gradlew.bat :androidApp:createDebugCoverageReport` with an emulator or device connected for instrumentation coverage.
- [ ] Compare Android UI/instrumentation coverage against Flutter parity tests and add missing Kotlin cases.
