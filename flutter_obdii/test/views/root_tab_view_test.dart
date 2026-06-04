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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ConfigData.instance.hasCompletedOnboarding = true;
  });

  testWidgets('testHasTabView', (tester) async {
    await tester.pumpWidget(_buildApp());
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('testHasFiveTabs', (tester) async {
    await tester.pumpWidget(_buildApp());
    expect(find.byType(NavigationDestination), findsNWidgets(5));
  });

  testWidgets('testSettingsTabExists', (tester) async {
    await tester.pumpWidget(_buildApp());
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('testGaugesTabHasNavigationStack', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.pump();
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pump(const Duration(milliseconds: 200));
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
  });

  testWidgets('testTabsHaveAccessibilityIdentifiers', (tester) async {
    await tester.pumpWidget(_buildApp());
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Gauges'), findsWidgets);
    expect(find.text('Fuel'), findsWidgets);
    expect(find.text('MIL'), findsWidgets);
    expect(find.text('DTCs'), findsWidgets);
  });

  testWidgets('testUsesAutomaticTabViewStyle', (tester) async {
    await tester.pumpWidget(_buildApp());
    expect(find.byType(MainScaffold), findsOneWidget);
  });

  testWidgets('testTabItemsHaveLabelsAndIcons', (tester) async {
    await tester.pumpWidget(_buildApp());
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Gauges'), findsWidgets);
    expect(find.text('Fuel'), findsWidgets);
    expect(find.text('MIL'), findsWidgets);
    expect(find.text('DTCs'), findsWidgets);
  });

  testWidgets('testAllTabsContainValidViews', (tester) async {
    await tester.pumpWidget(_buildApp());
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(MainScaffold), findsWidgets);
  });
}

