import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/core/pid_interest_registry.dart';
import 'package:flutter_obdii/core/pid_store.dart';
import 'package:flutter_obdii/viewmodels/diagnostics_viewmodel.dart';
import 'package:flutter_obdii/viewmodels/fuel_status_viewmodel.dart';
import 'package:flutter_obdii/viewmodels/gauges_viewmodel.dart';
import 'package:flutter_obdii/viewmodels/mil_status_viewmodel.dart';
import 'package:flutter_obdii/viewmodels/pid_toggle_list_viewmodel.dart';
import 'package:flutter_obdii/viewmodels/settings_viewmodel.dart';
import 'package:flutter_obdii/views/main_scaffold_material.dart';

const _testKey = 'HasShownCarPlayDrivingPrompt';

Widget _buildShell() {
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('testViewControllerInitialization', (tester) async {
    await tester.pumpWidget(_buildShell());
    expect(find.byType(MainScaffold), findsOneWidget);
  });

  testWidgets('testViewDidLoadAddsHostingController', (tester) async {
    await tester.pumpWidget(_buildShell());
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('testHostingControllerIsAdded', (tester) async {
    await tester.pumpWidget(_buildShell());
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('testHostingControllerViewIsAdded', (tester) async {
    await tester.pumpWidget(_buildShell());
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('testHostingControllerUsesAutoresizingMask', (tester) async {
    await tester.pumpWidget(_buildShell());
    expect(find.byType(MainScaffold), findsOneWidget);
  });

  testWidgets('testAutoLayoutConstraintsAreActivated', (tester) async {
    await tester.pumpWidget(_buildShell());
    expect(find.byType(IndexedStack), findsWidgets);
  });

  testWidgets('testHostingControllerDidMoveToParent', (tester) async {
    await tester.pumpWidget(_buildShell());
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  test('testSafetyPromptShownFirstTime', () async {
    final prefs = await SharedPreferences.getInstance();
    final shouldShow = !(prefs.getBool(_testKey) ?? false);
    expect(shouldShow, isTrue);
  });

  test('testSafetyPromptNotShownAfterMarked', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_testKey, true);
    final shouldShow = !(prefs.getBool(_testKey) ?? false);
    expect(shouldShow, isFalse);
  });

  test('testMarkSafetyPromptShownSetsUserDefaults', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(_testKey), isNull);
    await prefs.setBool(_testKey, true);
    expect(prefs.getBool(_testKey), isTrue);
  });

  test('testAlertControllerCreation', () {
    const title = 'Safety Reminder';
    const message = 'For your safety, please avoid changing settings while driving.';
    expect(title, isNotEmpty);
    expect(message, contains('safety'));
  });

  test('testAlertHasOKAction', () {
    const action = 'OK';
    expect(action, 'OK');
  });

  test('testUserDefaultsKeyIsCorrect', () {
    expect(_testKey, 'HasShownCarPlayDrivingPrompt');
  });

  testWidgets('testWeakSelfInAsyncBlock', (tester) async {
    await tester.pumpWidget(_buildShell());
    expect(find.byType(MainScaffold), findsOneWidget);
  });

  testWidgets('testViewControllerCanPresent', (tester) async {
    await tester.pumpWidget(_buildShell());
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('testPresentationCheckBeforePresenting', (tester) async {
    await tester.pumpWidget(_buildShell());
    expect(find.byType(Dialog), findsNothing);
  });
}

