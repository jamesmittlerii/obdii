import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_obdii/app_bootstrap.dart';
import 'package:flutter_obdii/views/main_scaffold_cupertino.dart';

Widget _buildApp() {
  return const ObdAppProviders(
    child: CupertinoApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('en', 'US')],
      home: Material(child: MainScaffoldCupertino()),
    ),
  );
}

void _useDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('restores saved selected tab', (WidgetTester tester) async {
    _useDesktopSurface(tester);
    SharedPreferences.setMockInitialValues({'ui.selectedTab': 2});

    await tester.pumpWidget(_buildApp());
    await tester.pump();

    final scaffold = tester.widget<CupertinoTabScaffold>(
      find.byType(CupertinoTabScaffold),
    );
    expect(scaffold.controller?.index, 2);
  });

  testWidgets('persists selected tab changes', (WidgetTester tester) async {
    _useDesktopSurface(tester);
    await tester.pumpWidget(_buildApp());

    await tester.tap(find.text('DTCs').first);
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('ui.selectedTab'), 4);
  });
}
