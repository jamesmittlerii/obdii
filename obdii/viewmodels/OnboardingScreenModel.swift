/**
 * Port of OnboardingScreenModel.kt — tab tour + demo intro flow.
 */

import Foundation

enum OnboardingPageKind {
  case welcome
  case tabTour
  case gaugePicker
  case connect
  case demo
}

struct OnboardingPage {
  let title: String
  let body: String
  let kind: OnboardingPageKind
  /// When set, onboarding switches the main app to this tab so the real screen shows behind the scrim.
  let previewTabIndex: Int?

  init(
    title: String,
    body: String,
    kind: OnboardingPageKind,
    previewTabIndex: Int? = nil
  ) {
    self.title = title
    self.body = body
    self.kind = kind
    self.previewTabIndex = previewTabIndex
  }
}

enum OnboardingScreenModel {
  static let settingsTabIndex = 0
  static let gaugesTabIndex = 1

  static let welcomeSummaryPoints = [
    "Settings — connect your adapter, units, and gauge selection",
    "Gauges — live PID values as rings or a list; tap for detail",
    "Fuel — fuel-system and O2 injector feedback by bank",
    "MIL — malfunction indicator (check engine) lamp and readiness",
    "DTCs — stored and pending diagnostic trouble codes",
  ]

  static let pages: [OnboardingPage] = [
    OnboardingPage(
      title: "Welcome to Rheosoft OBDII",
      body:
        "Read live OBD-II data from your vehicle on your phone or PC. Use an ELM327-compatible adapter on your OBD-II port (Bluetooth or Wi‑Fi), or Demo mode to explore without hardware.",
      kind: .welcome
    ),
    OnboardingPage(
      title: "Settings",
      body:
        "Connect an ELM327 adapter to your OBD-II port on your vehicle, then configure Bluetooth or Wi‑Fi here. See your adapter for details. If you don't have an adapter, choose Demo mode to see the app in action.",
      kind: .tabTour,
      previewTabIndex: settingsTabIndex
    ),
    OnboardingPage(
      title: "Gauges dashboard",
      body:
        "Live PID values on the dashboard. Switch ring or list layout at the top, and drag gauges to reorder.",
      kind: .tabTour,
      previewTabIndex: gaugesTabIndex
    ),
    OnboardingPage(
      title: "Gauge selection",
      body:
        "Choose which PIDs appear on the dashboard. Changes apply to both ring and list views.",
      kind: .gaugePicker,
      previewTabIndex: settingsTabIndex
    ),
    OnboardingPage(
      title: "Fuel Control Status",
      body:
        "Fuel-system status per bank—injector O2 closed-loop feedback and trim from the ECU.",
      kind: .tabTour,
      previewTabIndex: 2
    ),
    OnboardingPage(
      title: "MIL",
      body:
        "MIL (Malfunction Indicator Lamp), aka CEL (Check Engine Light). Lamp on/off status and OBD readiness monitors.",
      kind: .tabTour,
      previewTabIndex: 3
    ),
    OnboardingPage(
      title: "DTCs",
      body: "Stored and pending trouble codes. Tap a code for more detail.",
      kind: .tabTour,
      previewTabIndex: 4
    ),
    OnboardingPage(
      title: "Connect when you're ready",
      body:
        "When you have an adapter, stay on Settings, choose Bluetooth or Wi‑Fi, and tap Connect.",
      kind: .connect,
      previewTabIndex: settingsTabIndex
    ),
    OnboardingPage(
      title: "Try Demo mode",
      body:
        "Demo simulates a connected vehicle with live gauge updates—no adapter required. We'll open Gauges for you.",
      kind: .demo,
      previewTabIndex: gaugesTabIndex
    ),
  ]

  static var demoPageIndex: Int { pages.count - 1 }

  static var gaugePickerPageIndex: Int {
    pages.firstIndex(where: { $0.kind == .gaugePicker }) ?? 0
  }

  static func previewTabIndex(_ pageIndex: Int) -> Int? {
    guard pageIndex >= 0, pageIndex < pages.count else { return nil }
    return pages[pageIndex].previewTabIndex
  }

  static func highlightedNavTab(_ pageIndex: Int) -> Int? {
    showGaugePicker(pageIndex) ? nil : previewTabIndex(pageIndex)
  }

  static func showGaugePicker(_ pageIndex: Int) -> Bool {
    guard pageIndex >= 0, pageIndex < pages.count else { return false }
    return pages[pageIndex].kind == .gaugePicker
  }

  static func usesCompactScrim(_ pageIndex: Int) -> Bool {
    showGaugePicker(pageIndex) || isGaugesDashboardPage(pageIndex)
  }

  static func isGaugesDashboardPage(_ pageIndex: Int) -> Bool {
    guard pageIndex >= 0, pageIndex < pages.count else { return false }
    let page = pages[pageIndex]
    return page.kind == .tabTour && page.previewTabIndex == gaugesTabIndex
  }

  static func isDemoPage(_ pageIndex: Int) -> Bool {
    guard pageIndex >= 0, pageIndex < pages.count else { return false }
    return pages[pageIndex].kind == .demo
  }

  static func isLastPage(_ pageIndex: Int) -> Bool {
    pageIndex == pages.count - 1
  }

  static func showWelcomeSummary(_ pageIndex: Int) -> Bool {
    guard pageIndex >= 0, pageIndex < pages.count else { return false }
    return pages[pageIndex].kind == .welcome
  }
}
