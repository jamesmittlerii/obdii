import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_bootstrap.dart';
import 'theme/app_theme.dart';
import 'views/main_scaffold_material.dart';

Future<void> main() async {
  await bootstrapObdApp();
  runApp(const ObdMaterialApp());
}

class ObdMaterialApp extends StatelessWidget {
  const ObdMaterialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ObdAppProviders(
      child: MaterialApp(
        title: 'Rheosoft OBDII',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
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
