// Port of OnboardingScreenModel.kt — tab tour + demo intro flow.

enum OnboardingPageKind {
  welcome,
  tabTour,
  gaugePicker,
  connect,
  demo,
}

class OnboardingPage {
  const OnboardingPage({
    required this.title,
    required this.body,
    required this.kind,
    this.previewTabIndex,
  });

  final String title;
  final String body;
  final OnboardingPageKind kind;

  /// When set, onboarding switches the main app to this tab so the real screen shows behind the scrim.
  final int? previewTabIndex;
}

abstract final class OnboardingScreenModel {
  static const settingsTabIndex = 0;
  static const gaugesTabIndex = 1;

  static const welcomeSummaryPoints = [
    'Settings — connect your adapter, units, and gauge selection',
    'Gauges — live PID values as rings or a list; tap for detail',
    'Fuel — fuel-system and O2 injector feedback by bank',
    'MIL — malfunction indicator (check engine) lamp and readiness',
    'DTCs — stored and pending diagnostic trouble codes',
  ];

  static const pages = [
    OnboardingPage(
      title: 'Welcome to Rheosoft OBDII',
      body:
          'Read live OBD-II data from your vehicle on your phone or PC. Use an ELM327-compatible adapter on your OBD-II port (Bluetooth or Wi‑Fi), or Demo mode to explore without hardware.',
      kind: OnboardingPageKind.welcome,
    ),
    OnboardingPage(
      title: 'Settings',
      body:
          'Connect an ELM327 adapter to your OBD-II port on your vehicle, then configure Bluetooth or Wi‑Fi here. See your adapter for details. If you don\'t have an adapter, choose Demo mode to see the app in action.',
      kind: OnboardingPageKind.tabTour,
      previewTabIndex: settingsTabIndex,
    ),
    OnboardingPage(
      title: 'Gauges dashboard',
      body:
          'Live PID values on the dashboard. Switch ring or list layout at the top, and drag gauges to reorder.',
      kind: OnboardingPageKind.tabTour,
      previewTabIndex: gaugesTabIndex,
    ),
    OnboardingPage(
      title: 'Gauge selection',
      body:
          'Choose which PIDs appear on the dashboard. Changes apply to both ring and list views.',
      kind: OnboardingPageKind.gaugePicker,
      previewTabIndex: settingsTabIndex,
    ),
    OnboardingPage(
      title: 'Fuel Control Status',
      body:
          'Fuel-system status per bank—injector O2 closed-loop feedback and trim from the ECU.',
      kind: OnboardingPageKind.tabTour,
      previewTabIndex: 2,
    ),
    OnboardingPage(
      title: 'MIL',
      body:
          'MIL (Malfunction Indicator Lamp), aka CEL (Check Engine Light). Lamp on/off status and OBD readiness monitors.',
      kind: OnboardingPageKind.tabTour,
      previewTabIndex: 3,
    ),
    OnboardingPage(
      title: 'DTCs',
      body: 'Stored and pending trouble codes. Tap a code for more detail.',
      kind: OnboardingPageKind.tabTour,
      previewTabIndex: 4,
    ),
    OnboardingPage(
      title: 'Connect when you\'re ready',
      body:
          'When you have an adapter, stay on Settings, choose Bluetooth or Wi‑Fi, and tap Connect.',
      kind: OnboardingPageKind.connect,
      previewTabIndex: settingsTabIndex,
    ),
    OnboardingPage(
      title: 'Try Demo mode',
      body:
          'Demo simulates a connected vehicle with live gauge updates—no adapter required. We\'ll open Gauges for you.',
      kind: OnboardingPageKind.demo,
      previewTabIndex: gaugesTabIndex,
    ),
  ];

  static int get demoPageIndex => pages.length - 1;

  static int get gaugePickerPageIndex =>
      pages.indexWhere((p) => p.kind == OnboardingPageKind.gaugePicker);

  static int? previewTabIndex(int pageIndex) =>
      pageIndex >= 0 && pageIndex < pages.length
          ? pages[pageIndex].previewTabIndex
          : null;

  static int? highlightedNavTab(int pageIndex) =>
      showGaugePicker(pageIndex) ? null : previewTabIndex(pageIndex);

  static bool showGaugePicker(int pageIndex) =>
      pageIndex >= 0 &&
      pageIndex < pages.length &&
      pages[pageIndex].kind == OnboardingPageKind.gaugePicker;

  static bool usesCompactScrim(int pageIndex) =>
      showGaugePicker(pageIndex) || isGaugesDashboardPage(pageIndex);

  static bool isGaugesDashboardPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= pages.length) return false;
    final page = pages[pageIndex];
    return page.kind == OnboardingPageKind.tabTour &&
        page.previewTabIndex == gaugesTabIndex;
  }

  static bool isDemoPage(int pageIndex) =>
      pageIndex >= 0 &&
      pageIndex < pages.length &&
      pages[pageIndex].kind == OnboardingPageKind.demo;

  static bool isLastPage(int pageIndex) => pageIndex == pages.length - 1;

  static bool showWelcomeSummary(int pageIndex) =>
      pageIndex >= 0 &&
      pageIndex < pages.length &&
      pages[pageIndex].kind == OnboardingPageKind.welcome;
}
