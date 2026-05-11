import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_obdii/main_cupertino.dart';
import 'package:flutter_obdii/views/main_scaffold_cupertino.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('applies dark Cupertino and Material themes from system brightness', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const ObdCupertinoApp());
    await tester.pump();

    final context = tester.element(find.byType(MainScaffoldCupertino));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(CupertinoTheme.of(context).brightness, Brightness.dark);
  });

  testWidgets('applies light Cupertino and Material themes from system brightness', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(const ObdCupertinoApp());
    await tester.pump();

    final context = tester.element(find.byType(MainScaffoldCupertino));
    expect(Theme.of(context).brightness, Brightness.light);
    expect(CupertinoTheme.of(context).brightness, Brightness.light);
  });
}
