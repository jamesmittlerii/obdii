import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─────────────────────────────────────────────
  // Colors - Dark
  // ─────────────────────────────────────────────
  static const Color _darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color _darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color _darkSurfaceContainer = Color(0xFF334155); // Slate 700

  // ─────────────────────────────────────────────
  // Colors - Light
  // ─────────────────────────────────────────────
  static const Color _lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color _lightSurface = Color(0xFFFFFFFF); // White
  static const Color _lightSurfaceContainer = Color(0xFFF1F5F9); // Slate 100

  // ─────────────────────────────────────────────
  // Colors - Shared
  // ─────────────────────────────────────────────
  static const Color _primaryAccent = Color(0xFF00C2FF); // Rheosoft Cyan
  static const Color _primaryAccentDarker = Color(0xFF0096C7);

  // Semantic Colors
  static const Color criticalRed = Color(0xFFEF4444);
  static const Color highOrange = Color(0xFFF59E0B);
  static const Color moderateAmber = Color(0xFFFCD34D);
  static const Color lowBlue = Color(0xFF3B82F6);
  static const Color successGreen = Color(0xFF10B981);

  // ─────────────────────────────────────────────
  // TextTheme
  // ─────────────────────────────────────────────
  static TextTheme _buildTextTheme(TextTheme base) {
    if (!GoogleFonts.config.allowRuntimeFetching) return base;
    return GoogleFonts.interTextTheme(base);
  }

  static TextStyle _inter({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
  }) {
    if (!GoogleFonts.config.allowRuntimeFetching) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  // ─────────────────────────────────────────────
  // Component Themes
  // ─────────────────────────────────────────────
  static CardThemeData _buildCardTheme(Color color) {
    return CardThemeData(
      elevation: 0,
      color: color,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.10), width: 1),
      ),
    );
  }

  static ListTileThemeData _buildListTileTheme() {
    return const ListTileThemeData(iconColor: _primaryAccent);
  }

  // ─────────────────────────────────────────────
  // ThemeData - Light
  // ─────────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: _primaryAccent,
        onPrimary: Colors.white,
        secondary: _primaryAccentDarker,
        surface: _lightSurface,
        surfaceContainer: _lightSurfaceContainer,
      ),
      scaffoldBackgroundColor: _lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: _buildTextTheme(base.textTheme),
      cardTheme: _buildCardTheme(_lightSurface),
      listTileTheme: _buildListTileTheme(),
      dividerTheme: DividerThemeData(
        color: Colors.black.withValues(alpha: 0.05),
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightSurface,
        indicatorColor: _primaryAccent.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _primaryAccentDarker,
            );
          }
          return _inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _primaryAccentDarker, size: 26);
          }
          return IconThemeData(color: Colors.grey.shade600, size: 24);
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ThemeData - Dark
  // ─────────────────────────────────────────────
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: _primaryAccent,
        onPrimary: Colors.white,
        secondary: _primaryAccentDarker,
        surface: _darkSurface,
        surfaceContainer: _darkSurfaceContainer,
      ),
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: _buildTextTheme(base.textTheme),
      cardTheme: _buildCardTheme(_darkSurface).copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
      ),
      listTileTheme: _buildListTileTheme(),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.05),
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkBackground,
        indicatorColor: _primaryAccent.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _primaryAccent,
            );
          }
          return _inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade400,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _primaryAccent, size: 26);
          }
          return IconThemeData(color: Colors.grey.shade400, size: 24);
        }),
      ),
    );
  }
}
