# CLAUDE.md - Development Guidelines

## Guidelines

### 1. Think Before Coding
*   **State assumptions:** Explicitly list assumptions before implementing.
*   **Clarify uncertainty:** If a request is unclear or has multiple interpretations, ask the user instead of picking one silently.
*   **Surface tradeoffs:** Present simpler approaches if they exist and push back on over-engineering.
*   **Stop on confusion:** If something is confusing, stop and name the specific point of confusion.

### 2. Simplicity First
*   **Minimum Viable Code:** Write the minimum amount of code necessary to solve the problem.
*   **Avoid speculation:** Do not add features, abstractions, "flexibility," or configurability that wasn't explicitly requested.
*   **Conciseness:** Prioritize brevity; if code can be 50 lines instead of 200, rewrite it.
*   **Limit error handling:** Do not write error handling for impossible scenarios.

### 3. Surgical Changes
*   **Minimize footprint:** Touch only the code required for the task.
*   **Scope control:** Do not "improve" or refactor adjacent code, comments, or formatting that is unrelated to the task.
*   **Cleanup:** Only remove imports, variables, or functions that your specific changes made obsolete. Do not remove pre-existing dead code unless asked.

### 4. Goal-Driven Execution
*   **Verifiable goals:** Transform vague tasks into success criteria (e.g., "Write a test that reproduces the bug, then make it pass").
*   **Planning:** For multi-step tasks, provide a brief plan (Step → Verification) before starting.

## Build and Test Commands
*   **Build:** `./gradlew assembleDebug`
*   **Unit Tests (Core):** `./gradlew :kotlinobd2:test`
*   **Unit Tests (Android):** `./gradlew :androidApp:testDebugUnitTest`
*   **UI Tests:** `./gradlew :androidApp:connectedDebugAndroidTest`

## Code Style Preferences
*   **Consistency:** Always match the existing style of the codebase.
*   **Traceability:** Every changed line should trace directly back to the specific request.
*   **Seniority Standard:** Write code that a senior engineer would consider clean and simple.

## Sonar / Compose Maintainability
Follow the workspace [Sonar rules](file:///c:/Users/chica/OneDrive/Documents/git/obdii/CLAUDE.md#5-sonar-maintainability-enforce-proactively). Kotlin-specific patterns:

*   **Composable complexity:** Keep root app composables (`KotlinObdiiApp`, scaffold screens) thin. Extract `@Composable` effect helpers (`*Effect`, `*Overlays`, `*TabContent`) and plain functions for non-UI logic (`completeOnboarding`, `syncTabVisibility`).
*   **Parameter grouping:** When a `@Composable` needs many screen models, VMs, or callbacks, bundle them into `private data class` holders at the bottom of the file — e.g. `KotlinObdiiTabViews`, `KotlinObdiiTabActions`, `KotlinObdiiScaffoldUiState`. Target ≤ 7 params per composable.
*   **State + Actions split:** Mirror `ConnectionSectionState` / `ConnectionSectionActions` in `SettingsScreen.kt` and `GaugeGridItemActions` in `DashboardScreen.kt` — separate read-only snapshot data from callbacks.
*   **Reference:** `androidApp/.../MainScaffoldScreen.kt` for the canonical scaffold refactor pattern.
