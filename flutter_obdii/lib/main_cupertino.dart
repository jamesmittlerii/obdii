import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_bootstrap.dart';
import 'views/main_scaffold_cupertino.dart';

Future<void> main() async {
  await bootstrapObdApp();
  runApp(const ObdCupertinoApp());
}

class ObdCupertinoApp extends StatelessWidget {
  const ObdCupertinoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ObdAppProviders(
      child: const CupertinoApp(
        title: 'Rheosoft OBDII',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en', 'US')],
        theme: CupertinoThemeData(
          primaryColor: Color(0xFF00C2FF),
        ),
        home: MainScaffoldCupertino(),
      ),
    );
  }
}
