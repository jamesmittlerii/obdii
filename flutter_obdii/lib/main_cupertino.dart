import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_bootstrap.dart';
import 'theme/app_theme.dart';
import 'views/main_scaffold_cupertino.dart';

Future<void> main() async {
  await bootstrapObdApp();
  runApp(const ObdCupertinoApp());
}

class ObdCupertinoApp extends StatelessWidget {
  const ObdCupertinoApp({super.key});

  static const Color _primaryAccent = Color(0xFF00C2FF);

  @override
  Widget build(BuildContext context) {
    return ObdAppProviders(
      child: CupertinoApp(
        title: 'Rheosoft OBDII',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US')],
        theme: const CupertinoThemeData(
          primaryColor: _primaryAccent,
        ),
        builder: (context, child) {
          final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
          final materialTheme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;
          final cupertinoTheme = CupertinoThemeData(
            primaryColor: _primaryAccent,
            brightness: isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: materialTheme.scaffoldBackgroundColor,
            barBackgroundColor: materialTheme.navigationBarTheme.backgroundColor,
          );

          return CupertinoTheme(
            data: cupertinoTheme,
            child: Theme(data: materialTheme, child: child ?? const SizedBox.shrink()),
          );
        },
        home: const MainScaffoldCupertino(),
      ),
    );
  }
}
