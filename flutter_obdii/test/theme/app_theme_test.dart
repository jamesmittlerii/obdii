import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:flutter_obdii/theme/app_theme.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('lightTheme defines expected Material colors and component themes', () {
    final theme = AppTheme.lightTheme;

    expect(theme.brightness, Brightness.light);
    expect(theme.colorScheme.primary, const Color(0xFF00C2FF));
    expect(theme.colorScheme.secondary, const Color(0xFF0096C7));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF8FAFC));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFFF8FAFC));
    expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
    expect(theme.cardTheme.color, Colors.white);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.cardTheme.margin, EdgeInsets.zero);
    expect(theme.listTileTheme.iconColor, theme.colorScheme.primary);
    expect(theme.dividerTheme.thickness, 1);
  });

  test('darkTheme defines expected Material colors and component themes', () {
    final theme = AppTheme.darkTheme;

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, const Color(0xFF00C2FF));
    expect(theme.colorScheme.surface, const Color(0xFF1E293B));
    expect(theme.colorScheme.surfaceContainer, const Color(0xFF334155));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0F172A));
    expect(theme.appBarTheme.backgroundColor, const Color(0xFF0F172A));
    expect(theme.appBarTheme.centerTitle, false);
    expect(theme.cardTheme.color, const Color(0xFF1E293B));
    expect(theme.listTileTheme.iconColor, theme.colorScheme.primary);
    expect(theme.dividerTheme.space, 1);
  });

  test('navigation bar selected and unselected styles resolve', () {
    final light = AppTheme.lightTheme.navigationBarTheme;
    final dark = AppTheme.darkTheme.navigationBarTheme;

    final lightSelectedText = light.labelTextStyle!.resolve({
      WidgetState.selected,
    })!;
    final lightUnselectedText = light.labelTextStyle!.resolve({})!;
    final darkSelectedIcon = dark.iconTheme!.resolve({WidgetState.selected})!;
    final darkUnselectedIcon = dark.iconTheme!.resolve({})!;

    expect(lightSelectedText.fontWeight, FontWeight.w600);
    expect(lightUnselectedText.fontWeight, FontWeight.w500);
    expect(darkSelectedIcon.color, const Color(0xFF00C2FF));
    expect(darkSelectedIcon.size, 26);
    expect(darkUnselectedIcon.size, 24);
  });

  test('semantic colors are stable', () {
    expect(AppTheme.criticalRed, const Color(0xFFEF4444));
    expect(AppTheme.highOrange, const Color(0xFFF59E0B));
    expect(AppTheme.moderateAmber, const Color(0xFFFCD34D));
    expect(AppTheme.lowBlue, const Color(0xFF3B82F6));
    expect(AppTheme.successGreen, const Color(0xFF10B981));
  });
}
