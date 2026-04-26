import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'views/main_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bootstrap singletons — mirrors Swift app init order
  await ConfigData.instance.load();
  await PidStore.instance.load();
  OBDConnectionManager.instance.initialize();
  if (ConfigData.instance.autoConnectToOBD) {
    unawaited(OBDConnectionManager.instance.connect());
  }

  runApp(const ObdApp());
}

class ObdApp extends StatelessWidget {
  const ObdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core singletons — exposed as ChangeNotifiers for reactive UI
        ChangeNotifierProvider<ConfigData>.value(value: ConfigData.instance),
        ChangeNotifierProvider<PidStore>.value(value: PidStore.instance),
        ChangeNotifierProvider<PidInterestRegistry>.value(
            value: PidInterestRegistry.instance),
        ChangeNotifierProvider<OBDConnectionManager>.value(
            value: OBDConnectionManager.instance),

        // ViewModels — each creates its own subscriptions
        ChangeNotifierProvider(create: (_) => GaugesViewModel()),
        ChangeNotifierProvider(create: (_) => DiagnosticsViewModel()),
        ChangeNotifierProvider(create: (_) => FuelStatusViewModel()),
        ChangeNotifierProvider(create: (_) => MilStatusViewModel()),
        ChangeNotifierProvider(create: (_) => SettingsViewModel()),
        ChangeNotifierProvider(create: (_) => PidToggleListViewModel()),
      ],
      child: Consumer<ConfigData>(
        builder: (context, config, _) {
          return CupertinoApp(
            title: 'OBDII',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
            ],
            theme: const CupertinoThemeData(
              brightness: Brightness.light,
              primaryColor: Color(0xFF00C2FF),
            ),
            home: const MainScaffold(),
          );
        },
      ),
    );
  }
}
