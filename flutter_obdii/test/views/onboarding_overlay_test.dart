import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/core/pid_interest_registry.dart';
import 'package:flutter_obdii/core/pid_store.dart';
import 'package:flutter_obdii/screenmodels/onboarding_screen_model.dart';
import 'package:flutter_obdii/viewmodels/diagnostics_viewmodel.dart';
import 'package:flutter_obdii/viewmodels/fuel_status_viewmodel.dart';
import 'package:flutter_obdii/viewmodels/gauges_viewmodel.dart';
import 'package:flutter_obdii/viewmodels/mil_status_viewmodel.dart';
import 'package:flutter_obdii/viewmodels/pid_toggle_list_viewmodel.dart';
import 'package:flutter_obdii/viewmodels/settings_viewmodel.dart';
import 'package:flutter_obdii/views/main_scaffold_material.dart';
import 'package:flutter_obdii/views/onboarding_overlay.dart';

Widget _buildApp() {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ConfigData>.value(value: ConfigData.instance),
      ChangeNotifierProvider<PidStore>.value(value: PidStore.instance),
      ChangeNotifierProvider<PidInterestRegistry>.value(
        value: PidInterestRegistry.instance,
      ),
      ChangeNotifierProvider<OBDConnectionManager>.value(
        value: OBDConnectionManager.instance,
      ),
      ChangeNotifierProvider(create: (_) => GaugesViewModel()),
      ChangeNotifierProvider(create: (_) => DiagnosticsViewModel()),
      ChangeNotifierProvider(create: (_) => FuelStatusViewModel()),
      ChangeNotifierProvider(create: (_) => MilStatusViewModel()),
      ChangeNotifierProvider(create: (_) => SettingsViewModel()),
      ChangeNotifierProvider(create: (_) => PidToggleListViewModel()),
    ],
    child: const MaterialApp(home: MainScaffold()),
  );
}

Widget _buildScrim({
  required int pageIndex,
  ValueChanged<int>? onPageIndexChange,
  OnboardingCompleteCallback? onComplete,
}) {
  return MaterialApp(
    home: Scaffold(
      body: OnboardingContentScrim(
        pageIndex: pageIndex,
        onPageIndexChange: onPageIndexChange ?? (_) {},
        onComplete: onComplete ?? (_) {},
        bottomInset: 80,
      ),
    ),
  );
}

void _setLargePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ConfigData.instance.hasCompletedOnboarding = false;
  });

  testWidgets('shows welcome intro on first launch', (tester) async {
    _setLargePhoneSurface(tester);

    await tester.pumpWidget(_buildApp());
    await tester.pump();

    expect(find.text('Welcome to Rheosoft OBDII'), findsOneWidget);
    expect(find.text('Try Demo'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('skip completes onboarding', (tester) async {
    _setLargePhoneSurface(tester);

    await tester.pumpWidget(_buildApp());
    await tester.pump();

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(find.text('Welcome to Rheosoft OBDII'), findsNothing);
    expect(ConfigData.instance.hasCompletedOnboarding, isTrue);
  });

  testWidgets('welcome page shows summary and next', (tester) async {
    await tester.pumpWidget(_buildScrim(pageIndex: 0));

    expect(find.text('Welcome to Rheosoft OBDII'), findsOneWidget);
    expect(find.text('What you can do'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('next invokes onPageIndexChange', (tester) async {
    _setLargePhoneSurface(tester);
    int? nextIndex;

    await tester.pumpWidget(
      _buildScrim(
        pageIndex: 0,
        onPageIndexChange: (index) => nextIndex = index,
      ),
    );

    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(nextIndex, 1);
  });

  testWidgets('settings tour page shows settings copy', (tester) async {
    await tester.pumpWidget(_buildScrim(pageIndex: 1));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('gauges dashboard page shows layout hint', (tester) async {
    final pageIndex = OnboardingScreenModel.pages.indexWhere(
      (page) => page.title == 'Gauges dashboard',
    );

    await tester.pumpWidget(_buildScrim(pageIndex: pageIndex));

    expect(find.text('Ring vs list'), findsOneWidget);
    expect(
      find.text('Gauges shows circular ring tiles; List shows compact rows.'),
      findsOneWidget,
    );
  });

  testWidgets('gauge picker page shows enabled hints', (tester) async {
    await tester.pumpWidget(
      _buildScrim(pageIndex: OnboardingScreenModel.gaugePickerPageIndex),
    );

    expect(find.text('On this screen'), findsOneWidget);
    expect(
      find.text('Use switches to enable or disable gauges.'),
      findsOneWidget,
    );
  });

  testWidgets('demo page shows try demo actions', (tester) async {
    await tester.pumpWidget(
      _buildScrim(pageIndex: OnboardingScreenModel.demoPageIndex),
    );

    expect(find.text('Try Demo mode'), findsOneWidget);
    expect(find.text('Try Demo'), findsOneWidget);
    expect(find.text('Get started without Demo'), findsOneWidget);
  });

  testWidgets('skip invokes onComplete without demo', (tester) async {
    bool? completedWithDemo;

    await tester.pumpWidget(
      _buildScrim(
        pageIndex: 0,
        onComplete: (startDemo) => completedWithDemo = startDemo,
      ),
    );

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(completedWithDemo, isFalse);
  });

  testWidgets('try demo invokes onComplete with demo', (tester) async {
    bool? completedWithDemo;

    await tester.pumpWidget(
      _buildScrim(
        pageIndex: OnboardingScreenModel.demoPageIndex,
        onComplete: (startDemo) => completedWithDemo = startDemo,
      ),
    );

    await tester.tap(find.text('Try Demo'));
    await tester.pump();

    expect(completedWithDemo, isTrue);
  });

  testWidgets('get started without demo invokes onComplete without demo', (
    tester,
  ) async {
    bool? completedWithDemo;

    await tester.pumpWidget(
      _buildScrim(
        pageIndex: OnboardingScreenModel.demoPageIndex,
        onComplete: (startDemo) => completedWithDemo = startDemo,
      ),
    );

    await tester.tap(find.text('Get started without Demo'));
    await tester.pump();

    expect(completedWithDemo, isFalse);
  });

  testWidgets('nav highlight renders for gauges tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingNavHighlight(
            highlightedIndex: OnboardingScreenModel.gaugesTabIndex,
          ),
        ),
      ),
    );

    expect(find.byType(DecoratedBox), findsOneWidget);
  });

  testWidgets('nav highlight hidden when index is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OnboardingNavHighlight(highlightedIndex: null),
        ),
      ),
    );

    expect(find.byType(DecoratedBox), findsNothing);
  });
}
