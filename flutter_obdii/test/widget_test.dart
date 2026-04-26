import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
import 'package:flutter_obdii/views/main_scaffold.dart';

void main() {
  testWidgets('testAppSmokeTestScaffoldRenders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConfigData>.value(value: ConfigData.instance),
          ChangeNotifierProvider<PidStore>.value(value: PidStore.instance),
          ChangeNotifierProvider<PidInterestRegistry>.value(
              value: PidInterestRegistry.instance),
          ChangeNotifierProvider<OBDConnectionManager>.value(
              value: OBDConnectionManager.instance),
          ChangeNotifierProvider(create: (_) => GaugesViewModel()),
          ChangeNotifierProvider(create: (_) => DiagnosticsViewModel()),
          ChangeNotifierProvider(create: (_) => FuelStatusViewModel()),
          ChangeNotifierProvider(create: (_) => MilStatusViewModel()),
          ChangeNotifierProvider(create: (_) => SettingsViewModel()),
          ChangeNotifierProvider(create: (_) => PidToggleListViewModel()),
        ],
        child: const MaterialApp(home: MainScaffold()),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
