# kotlin_obdii

Native Kotlin/Android implementation of `flutter_obdii` with strict 1:1 parity goals.

## Scope

- Match Flutter architecture (`core`, `models`, `viewmodels`, `views`, `bootstrap`)
- Preserve behavior and feature flow exactly
- Port and maintain equivalent test coverage

## Port Tracking

Use `docs/port-matrix.md` as the source of truth for file-level migration status.
Use `docs/code-coverage-todos.md` to track Kotlin coverage improvement work.

## Structure

- `app/src/main/java/com/rheosoft/obdii/core`
- `app/src/main/java/com/rheosoft/obdii/models`
- `app/src/main/java/com/rheosoft/obdii/viewmodels`
- `app/src/main/java/com/rheosoft/obdii/views`
- `app/src/main/java/com/rheosoft/obdii/bootstrap`

Tests:

- `app/src/test/java/com/rheosoft/obdii/core`
- `app/src/test/java/com/rheosoft/obdii/models`
- `app/src/test/java/com/rheosoft/obdii/viewmodels`
- `app/src/test/java/com/rheosoft/obdii/views`
- `app/src/test/java/com/rheosoft/obdii/parity`
