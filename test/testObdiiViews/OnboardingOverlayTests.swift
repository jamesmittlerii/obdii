/**
 * ViewInspector unit tests for OnboardingContentScrim and OnboardingNavHighlight.
 * Port of flutter_obdii/test/views/onboarding_overlay_test.dart.
 */

import SwiftUI
import ViewInspector
import XCTest
@testable import obdii

@MainActor
final class OnboardingOverlayTests: XCTestCase {

  private func makeScrim(
    pageIndex: Int,
    onPageIndexChange: @escaping (Int) -> Void = { _ in },
    onComplete: @escaping (Bool) -> Void = { _ in }
  ) -> some View {
    OnboardingContentScrim(
      pageIndex: pageIndex,
      onPageIndexChange: onPageIndexChange,
      onComplete: onComplete
    )
    .frame(width: 400, height: 900)
  }

  private func containsText(in view: some View, _ expected: String) throws -> Bool {
    let texts = try view.inspect().findAll(ViewType.Text.self)
    return try texts.contains { try $0.string().contains(expected) }
  }

  func testWelcomePageShowsSummaryAndNext() throws {
    let view = makeScrim(pageIndex: 0)

    XCTAssertTrue(try containsText(in: view, "Welcome to Rheosoft OBDII"))
    XCTAssertTrue(try containsText(in: view, "What you can do"))
    XCTAssertNoThrow(try view.inspect().find(button: "Next"))
  }

  func testNextInvokesOnPageIndexChange() throws {
    var nextIndex: Int?
    let view = makeScrim(pageIndex: 0) { nextIndex = $0 }

    try view.inspect().find(button: "Next").tap()

    XCTAssertEqual(nextIndex, 1)
  }

  func testSettingsTourPageShowsSettingsCopy() throws {
    let view = makeScrim(pageIndex: 1)

    XCTAssertTrue(try containsText(in: view, "Settings"))
    XCTAssertNoThrow(try view.inspect().find(button: "Next"))
  }

  func testGaugesDashboardPageShowsLayoutHint() throws {
    let pageIndex = OnboardingScreenModel.pages.firstIndex {
      $0.title == "Gauges dashboard"
    }
    XCTAssertNotNil(pageIndex)
    guard let pageIndex else { return }

    let view = makeScrim(pageIndex: pageIndex)

    XCTAssertTrue(try containsText(in: view, "Ring vs list"))
    XCTAssertTrue(
      try containsText(
        in: view,
        "Gauges shows circular ring tiles; List shows compact rows."
      )
    )
  }

  func testGaugePickerPageShowsEnabledHints() throws {
    let view = makeScrim(pageIndex: OnboardingScreenModel.gaugePickerPageIndex)

    XCTAssertTrue(try containsText(in: view, "On this screen"))
    XCTAssertTrue(try containsText(in: view, "Use switches to enable or disable gauges."))
  }

  func testDemoPageShowsTryDemoActions() throws {
    let view = makeScrim(pageIndex: OnboardingScreenModel.demoPageIndex)

    XCTAssertTrue(try containsText(in: view, "Try Demo mode"))
    XCTAssertNoThrow(try view.inspect().find(button: "Try Demo"))
    XCTAssertNoThrow(try view.inspect().find(button: "Get started without Demo"))
  }

  func testSkipInvokesOnCompleteWithoutDemo() throws {
    var completedWithDemo: Bool?
    let view = makeScrim(pageIndex: 0, onComplete: { completedWithDemo = $0 })

    try view.inspect().find(button: "Skip").tap()

    XCTAssertEqual(completedWithDemo, false)
  }

  func testTryDemoInvokesOnCompleteWithDemo() throws {
    var completedWithDemo: Bool?
    let view = makeScrim(
      pageIndex: OnboardingScreenModel.demoPageIndex,
      onComplete: { completedWithDemo = $0 }
    )

    try view.inspect().find(button: "Try Demo").tap()

    XCTAssertEqual(completedWithDemo, true)
  }

  func testGetStartedWithoutDemoInvokesOnCompleteWithoutDemo() throws {
    var completedWithDemo: Bool?
    let view = makeScrim(
      pageIndex: OnboardingScreenModel.demoPageIndex,
      onComplete: { completedWithDemo = $0 }
    )

    try view.inspect().find(button: "Get started without Demo").tap()

    XCTAssertEqual(completedWithDemo, false)
  }

  func testNavHighlightRendersForGaugesTab() throws {
    let view = OnboardingNavHighlight(
      highlightedIndex: OnboardingScreenModel.gaugesTabIndex
    )
    .frame(width: 400, height: 49)

    let hStacks = try view.inspect().findAll(ViewType.HStack.self)
    XCTAssertFalse(hStacks.isEmpty)
  }

  func testNavHighlightHiddenWhenIndexIsNil() throws {
    let view = OnboardingNavHighlight(highlightedIndex: nil)
      .frame(width: 400, height: 49)

    let hStacks = try view.inspect().findAll(ViewType.HStack.self)
    XCTAssertTrue(hStacks.isEmpty)
  }
}
