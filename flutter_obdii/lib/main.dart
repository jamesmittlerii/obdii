import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;
import 'app_bootstrap.dart';
import 'core/logger.dart';
import 'core/obd_connection_manager.dart';
import 'views/main_scaffold.dart';

Future<void> main() async {
  // Bridge the library logger to the app's premium logger
  obd2lib.ObdLog.setHandler(
      (message, {level = 'info', category = 'Communication'}) {
    final cat = LogCategory.values.firstWhere(
      (c) => c.label.toLowerCase() == category.toLowerCase(),
      orElse: () => LogCategory.communication,
    );

    // Detect intermediate states that aren't explicit enums in the library
    if (message.contains('Setting up vehicle')) {
      OBDConnectionManager.instance.setSettingUpVehicle();
    }

    switch (level) {
      case 'error':
        obdError(message, category: cat);
        break;
      case 'warning':
        obdWarning(message, category: cat);
        break;
      case 'debug':
        obdDebug(message, category: cat);
        break;
      default:
        obdInfo(message, category: cat);
        break;
    }
  });

  obdInfo('Starting Rheosoft OBDII Application');
  await bootstrapObdApp();
  runApp(const ObdApp());
}

class ObdApp extends StatelessWidget {
  const ObdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ObdAppProviders(
      child: MaterialApp(
        title: 'Rheosoft OBDII',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00C2FF),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'SF Pro Display',
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00C2FF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US')],
        themeMode: ThemeMode.system,
        home: const MainScaffold(),
      ),
    );
  }
}
