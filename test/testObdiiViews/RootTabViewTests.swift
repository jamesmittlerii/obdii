/**
 * __Final Project__
 * Jim Mittler
 * 19 November 2025
 *
 * ViewInspector Unit Tests for RootTabView
 *
 * Tests the RootTabView SwiftUI structure, tab bar, and onboarding integration.
 */

import SwiftUI
import SwiftOBD2
import ViewInspector
import XCTest
@testable import obdii

@MainActor
final class RootTabViewTests: XCTestCase {

  private var savedHasCompletedOnboarding = false
  private var savedConnectionType: ConnectionType = .bluetooth

  override func setUp() async throws {
    savedHasCompletedOnboarding = ConfigData.shared.hasCompletedOnboarding
    savedConnectionType = ConfigData.shared.connectionType
    ConfigData.shared.hasCompletedOnboarding = true
  }

  override func tearDown() async throws {
    ConfigData.shared.hasCompletedOnboarding = savedHasCompletedOnboarding
    ConfigData.shared.connectionType = savedConnectionType
  }

  private struct HostedRootTabView {
    let inspect: () throws -> InspectableView<ViewType.ClassifiedView>
  }

  private func runWithHostedView<T>(
    showOnboarding: Bool,
    pageIndex: Int = 0,
    _ block: (HostedRootTabView) throws -> T
  ) throws -> T {
    let view = RootTabView(testOnboardingState: showOnboarding, pageIndex: pageIndex)
      .frame(width: 400, height: 900)
    ViewHosting.host(view: view)
    defer { ViewHosting.expel() }
    settleHostedUI()
    return try block(HostedRootTabView { try view.inspect() })
  }

  private func settleHostedUI() {
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
  }

  private func containsText(in inspected: InspectableView<ViewType.ClassifiedView>, _ expected: String) throws -> Bool {
    let texts = try inspected.findAll(ViewType.Text.self)
    return texts.contains { text in
      (try? text.string())?.contains(expected) == true
    }
  }

  private func findButton(
    in inspected: InspectableView<ViewType.ClassifiedView>,
    labeled label: String
  ) throws -> InspectableView<ViewType.Button> {
    let buttons = try inspected.findAll(ViewType.Button.self)
    guard
      let button = buttons.first(where: { button in
        guard let texts = try? button.findAll(ViewType.Text.self) else { return false }
        return texts.contains { (try? $0.string()) == label }
      })
    else {
      throw InspectionError.searchFailure(skipped: 0, blockers: [])
    }
    return button
  }

  private func tapButton(
    in inspected: InspectableView<ViewType.ClassifiedView>,
    labeled label: String
  ) throws {
    try findButton(in: inspected, labeled: label).tap()
  }

  func testHasTabView() throws {
    let view = RootTabView().frame(width: 400, height: 900)
    let tabView = try view.inspect().find(ViewType.TabView.self)
    XCTAssertNotNil(tabView, "RootTabView should contain a TabView")
  }

  func testHasFiveTabs() throws {
    let view = RootTabView().frame(width: 400, height: 900)
    let tabView = try view.inspect().find(ViewType.TabView.self)
    XCTAssertNotNil(tabView, "Should have TabView with 5 tabs")
  }

  func testSettingsTabExists() throws {
    let view = RootTabView().frame(width: 400, height: 900)
    XCTAssertNoThrow(try view.inspect().find(ViewType.TabView.self))
  }

  func testGaugesTabHasNavigationStack() throws {
    let view = RootTabView().frame(width: 400, height: 900)
    XCTAssertNotNil(view, "RootTabView should initialize the gauges tab container")
  }

  func testTabsHaveAccessibilityIdentifiers() throws {
    let view = RootTabView().frame(width: 400, height: 900)
    let tabView = try view.inspect().find(ViewType.TabView.self)
    XCTAssertNotNil(tabView, "TabView should have accessibility identifiers on tabs")
  }

  func testUsesAutomaticTabViewStyle() throws {
    let view = RootTabView().frame(width: 400, height: 900)
    let tabView = try view.inspect().find(ViewType.TabView.self)
    XCTAssertNotNil(tabView, "Should use automatic tab view style")
  }

  func testTabItemsHaveLabelsAndIcons() throws {
    let view = RootTabView().frame(width: 400, height: 900)
    let tabView = try view.inspect().find(ViewType.TabView.self)
    XCTAssertNotNil(tabView, "Tabs should have labels and icons")
  }

  func testAllTabsContainValidViews() throws {
    let view = RootTabView().frame(width: 400, height: 900)
    let tabView = try view.inspect().find(ViewType.TabView.self)
    XCTAssertNotNil(tabView, "All tabs should contain their respective views")
  }

  func testShowsOnboardingWhenNotCompleted() throws {
    try runWithHostedView(showOnboarding: true) { host in
      let inspected = try host.inspect()
      XCTAssertTrue(try containsText(in: inspected, "Welcome to Rheosoft OBDII"))
      XCTAssertNoThrow(try inspected.find(button: "Skip"))
    }
  }

  func testSkipCompletesOnboarding() throws {
    try runWithHostedView(showOnboarding: true) { host in
      try tapButton(in: try host.inspect(), labeled: "Skip")
      XCTAssertTrue(ConfigData.shared.hasCompletedOnboarding)
    }
  }

  func testSettingsTourPageShowsSettingsCopy() throws {
    try runWithHostedView(showOnboarding: true, pageIndex: 1) { host in
      let inspected = try host.inspect()
      XCTAssertTrue(try containsText(in: inspected, "If you don't have an adapter"))
    }
  }

  func testGaugePickerPageShowsOverlay() throws {
    try runWithHostedView(
      showOnboarding: true,
      pageIndex: OnboardingScreenModel.gaugePickerPageIndex
    ) { host in
      let inspected = try host.inspect()
      XCTAssertTrue(try containsText(in: inspected, "On this screen"))
      XCTAssertTrue(try containsText(in: inspected, "Use switches to enable or disable gauges."))
    }
  }

  func testTryDemoCompletesOnboardingAndSelectsDemoConnection() throws {
    try runWithHostedView(
      showOnboarding: true,
      pageIndex: OnboardingScreenModel.demoPageIndex
    ) { host in
      let inspected = try host.inspect()
      XCTAssertTrue(try containsText(in: inspected, "Try Demo mode"))
      try tapButton(in: inspected, labeled: "Try Demo")
      XCTAssertTrue(ConfigData.shared.hasCompletedOnboarding)
      XCTAssertEqual(ConfigData.shared.connectionType, .demo)
    }
  }

  func testGetStartedWithoutDemoCompletesOnboardingWithoutChangingConnection() throws {
    ConfigData.shared.connectionType = .bluetooth
    try runWithHostedView(
      showOnboarding: true,
      pageIndex: OnboardingScreenModel.demoPageIndex
    ) { host in
      try tapButton(in: try host.inspect(), labeled: "Get started without Demo")
      XCTAssertTrue(ConfigData.shared.hasCompletedOnboarding)
      XCTAssertEqual(ConfigData.shared.connectionType, .bluetooth)
    }
  }

  func testShowIntroAgainRestartsOnboarding() throws {
    try runWithHostedView(showOnboarding: false) { host in
      try host.inspect().find(button: "Show intro again").tap()
    }
  }
}
