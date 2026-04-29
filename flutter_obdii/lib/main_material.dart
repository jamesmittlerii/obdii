import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_bootstrap.dart';
import 'views/main_scaffold.dart';

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
