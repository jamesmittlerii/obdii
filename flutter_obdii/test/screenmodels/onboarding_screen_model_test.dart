import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_obdii/screenmodels/onboarding_screen_model.dart';

void main() {
  test('has nine intro pages ending with demo', () {
    expect(OnboardingScreenModel.pages.length, 9);
    expect(
      OnboardingScreenModel.pages.last.kind,
      OnboardingPageKind.demo,
    );
  });

  test('demo page is last and highlights gauges tab', () {
    expect(
      OnboardingScreenModel.isDemoPage(OnboardingScreenModel.demoPageIndex),
      isTrue,
    );
    expect(
      OnboardingScreenModel.previewTabIndex(OnboardingScreenModel.demoPageIndex),
      OnboardingScreenModel.gaugesTabIndex,
    );
  });

  test('gauge picker page opens picker and hides nav highlight', () {
    final idx = OnboardingScreenModel.gaugePickerPageIndex;
    expect(OnboardingScreenModel.showGaugePicker(idx), isTrue);
    expect(OnboardingScreenModel.usesCompactScrim(idx), isTrue);
    expect(OnboardingScreenModel.highlightedNavTab(idx), isNull);
  });

  test('gauges dashboard page uses compact scrim', () {
    final idx = OnboardingScreenModel.pages.indexWhere(
      (p) =>
          p.kind == OnboardingPageKind.tabTour &&
          p.previewTabIndex == OnboardingScreenModel.gaugesTabIndex,
    );
    expect(OnboardingScreenModel.isGaugesDashboardPage(idx), isTrue);
    expect(OnboardingScreenModel.usesCompactScrim(idx), isTrue);
    expect(
      OnboardingScreenModel.highlightedNavTab(idx),
      OnboardingScreenModel.gaugesTabIndex,
    );
  });

  test('welcome has no live tab preview and shows summary', () {
    expect(OnboardingScreenModel.previewTabIndex(0), isNull);
    expect(OnboardingScreenModel.showWelcomeSummary(0), isTrue);
    expect(OnboardingScreenModel.welcomeSummaryPoints.length, 5);
  });

  test('last page detection', () {
    expect(OnboardingScreenModel.isLastPage(0), isFalse);
    expect(
      OnboardingScreenModel.isLastPage(OnboardingScreenModel.pages.length - 1),
      isTrue,
    );
  });
}
