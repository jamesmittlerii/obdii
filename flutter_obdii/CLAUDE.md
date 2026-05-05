# CLAUDE.md - Flutter Development Guidelines

Guidelines and commands for the `flutter_obdii` project.

## Guidelines
Follow the 4 pillars (Think, Simplicity, Surgical, Goal-Driven) as defined in the [root CLAUDE.md](file:///c:/Users/chica/OneDrive/Documents/git/obdii/CLAUDE.md).

## Build and Test Commands

### Development
*   **Run App (Material):** `flutter run --flavor material -t lib/main_material.dart`
*   **Run App (Cupertino):** `flutter run --flavor cupertino -t lib/main_cupertino.dart`
*   **Check dependencies:** `flutter pub outdated`
*   **Update dependencies:** `flutter pub upgrade --major-versions`

### Testing
*   **Run All Tests:** `flutter test`
*   **Run Specific Test:** `flutter test test/path/to/test.dart`
*   **Run with Coverage:** `flutter test --coverage`

### Production Build
*   **Build Android APK:** `flutter build apk --flavor material -t lib/main_material.dart`
*   **Build Windows:** `flutter build windows`

## Code Style Preferences
*   **Architecture:** Provider for state management.
*   **Navigation:** Material 3 tabbed navigation with `IndexedStack`.
*   **Testing:** Use `WidgetTester` and mock ViewModels where appropriate.
