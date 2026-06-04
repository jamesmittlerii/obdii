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
    ConfigData.instance.hasCompletedOnboarding = false;
  });

  testWidgets('shows welcome intro on first launch', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp());
    await tester.pump();

    expect(find.text('Welcome to Rheosoft OBDII'), findsOneWidget);
    expect(find.text('Try Demo'), findsNothing);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('skip completes onboarding', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildApp());
    await tester.pump();

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(find.text('Welcome to Rheosoft OBDII'), findsNothing);
    expect(ConfigData.instance.hasCompletedOnboarding, isTrue);
  });
}
