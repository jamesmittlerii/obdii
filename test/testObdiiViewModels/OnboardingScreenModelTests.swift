/**
 * Port of OnboardingScreenModelTest.kt
 */

import XCTest
@testable import obdii

final class OnboardingScreenModelTests: XCTestCase {

  func testHasNineIntroPagesEndingWithDemo() {
    XCTAssertEqual(OnboardingScreenModel.pages.count, 9)
    XCTAssertEqual(OnboardingScreenModel.pages.last?.kind, .demo)
  }

  func testDemoPageIsLastAndHighlightsGaugesTab() {
    XCTAssertTrue(OnboardingScreenModel.isDemoPage(OnboardingScreenModel.demoPageIndex))
    XCTAssertEqual(
      OnboardingScreenModel.previewTabIndex(OnboardingScreenModel.demoPageIndex),
      OnboardingScreenModel.gaugesTabIndex
    )
  }

  func testGaugePickerPageOpensPickerAndHidesNavHighlight() {
    let idx = OnboardingScreenModel.gaugePickerPageIndex
    XCTAssertTrue(OnboardingScreenModel.showGaugePicker(idx))
    XCTAssertTrue(OnboardingScreenModel.usesCompactScrim(idx))
    XCTAssertNil(OnboardingScreenModel.highlightedNavTab(idx))
  }

  func testGaugesDashboardPageUsesCompactScrim() {
    let idx = OnboardingScreenModel.pages.firstIndex {
      $0.kind == .tabTour && $0.previewTabIndex == OnboardingScreenModel.gaugesTabIndex
    }
    XCTAssertNotNil(idx)
    guard let idx else { return }

    XCTAssertTrue(OnboardingScreenModel.isGaugesDashboardPage(idx))
    XCTAssertTrue(OnboardingScreenModel.usesCompactScrim(idx))
    XCTAssertEqual(
      OnboardingScreenModel.highlightedNavTab(idx),
      OnboardingScreenModel.gaugesTabIndex
    )
  }

  func testWelcomeHasNoLiveTabPreviewAndShowsSummary() {
    XCTAssertNil(OnboardingScreenModel.previewTabIndex(0))
    XCTAssertTrue(OnboardingScreenModel.showWelcomeSummary(0))
    XCTAssertEqual(OnboardingScreenModel.welcomeSummaryPoints.count, 5)
  }

  func testLastPageDetection() {
    XCTAssertFalse(OnboardingScreenModel.isLastPage(0))
    XCTAssertTrue(OnboardingScreenModel.isLastPage(OnboardingScreenModel.pages.count - 1))
  }
}
