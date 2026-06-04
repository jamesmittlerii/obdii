import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'core/config_data.dart';
import 'core/obd_connection_manager.dart';
import 'core/pid_interest_registry.dart';
import 'core/pid_store.dart';
import 'viewmodels/diagnostics_viewmodel.dart';
import 'viewmodels/fuel_status_viewmodel.dart';
import 'viewmodels/gauges_viewmodel.dart';
import 'viewmodels/mil_status_viewmodel.dart';
import 'viewmodels/pid_toggle_list_viewmodel.dart';
import 'viewmodels/settings_viewmodel.dart';

Future<void> bootstrapObdApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ConfigData.instance.load();
  await PidStore.instance.load();
  OBDConnectionManager.instance.initialize();
  if (ConfigData.instance.autoConnectToOBD &&
      ConfigData.instance.hasCompletedOnboarding) {
    unawaited(OBDConnectionManager.instance.connect());
  }
}

class ObdAppProviders extends StatelessWidget {
  final Widget child;

  const ObdAppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
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
      child: child,
    );
  }
}
