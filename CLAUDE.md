# CLAUDE.md - Development Guidelines

Behavioral guidelines to reduce common LLM coding mistakes across the OBDII workspace.

## Guidelines

### 1. Think Before Coding
*   **State assumptions:** Explicitly list assumptions before implementing.
*   **Clarify uncertainty:** If a request is unclear, ask the user instead of picking silently.
*   **Surface tradeoffs:** Present simpler approaches and push back on over-engineering.

### 2. Simplicity First
*   **Minimum Viable Code:** Write only what is necessary to solve the problem.
*   **Avoid speculation:** No unrequested features, abstractions, or "flexibility."
*   **Conciseness:** Prioritize brevity; rewrite long solutions if a shorter one exists.

### 3. Surgical Changes
*   **Minimize footprint:** Touch only the code required for the task.
*   **Scope control:** Do not "improve" or refactor unrelated code.
*   **Targeted Cleanup:** Only remove what your changes made obsolete.

### 4. Goal-Driven Execution
*   **Verifiable goals:** Turn tasks into success criteria (e.g., test-driven).
*   **Planning:** For multi-step tasks, provide a brief plan (Step → Verification) before starting.

### 5. Sonar Maintainability (enforce proactively)
SonarCloud flags these across Swift, Flutter, and Kotlin. Fix them when writing or touching code — do not wait for a nag.

*   **Cognitive complexity ≤ 15 per function/method.** Split large `build()`, `@Composable`, or view `body` methods into private helpers. Move `LaunchedEffect` / side-effect blocks out of the root composable when they add branching.
*   **≤ 7 function parameters.** Group related arguments into small `data class` / struct holders (e.g. `*UiState`, `*Actions`, `*TabViews`). Follow existing patterns in each platform (`SettingsScreen`, `DashboardScreen`, etc.).
*   **Simple `switch` → `if`.** When a `switch` only distinguishes one case from `default`, use an `if` + early return instead (Sonar readability rule).
*   **No silent empty closures.** Default no-op callbacks (`{}`, `() {}`) must include a **nested comment** explaining why the body is intentionally empty, or implement the behavior.
*   **Refactor, don't suppress.** Prefer structural fixes (extract method, group params) over `@Suppress` or Sonar ignore comments unless platform constraints make extraction unreasonable.

#### Swift (`obdii/swiftui/`, `obdii/core/`)
*   **Keep `body` shallow:** Extract `@ViewBuilder` helpers or subviews when a view's `body` accumulates branching (tabs, overlays, loading vs content).
*   **Default closure parameters:** Optional `@escaping () -> Void = { ... }` defaults that are intentionally no-op need a comment **inside** the closure body (Sonar `suspicious` rule). The parent scaffold injects real navigation when the view is embedded.
*   **Simple `switch` → `if`:** Applies to core helpers too — e.g. unit-formatting branches with one special case and a `default` fallback.
*   **Parameter grouping:** Use small `struct` holders for related view inputs when an initializer or builder function exceeds seven parameters.
*   **References:** `MILStatusView.swift` (documented default `onSummaryTap`), `OBDIIPID.swift` (`usesGroupingSeparator`).

Platform-specific detail: [Flutter](file:///c:/Users/chica/OneDrive/Documents/git/obdii/flutter_obdii/CLAUDE.md#sonar--widget-maintainability), [Kotlin](file:///c:/Users/chica/OneDrive/Documents/git/obdii/kotlin_obdii/CLAUDE.md#sonar--compose-maintainability).

## Project Structure
*   **[obdii/](file:///c:/Users/chica/OneDrive/Documents/git/obdii/obdii)**: Swift/SwiftUI implementation (iOS).
*   **[flutter_obdii/](file:///c:/Users/chica/OneDrive/Documents/git/obdii/flutter_obdii)**: Flutter implementation (iOS/Android/Windows).
*   **[kotlin_obdii/](file:///c:/Users/chica/OneDrive/Documents/git/obdii/kotlin_obdii)**: Kotlin/Compose implementation (Android/JVM).

## Build and Test Commands
Refer to subproject-specific `CLAUDE.md` files for detailed commands:
*   [Flutter Commands](file:///c:/Users/chica/OneDrive/Documents/git/obdii/flutter_obdii/CLAUDE.md)
*   [Kotlin Commands](file:///c:/Users/chica/OneDrive/Documents/git/obdii/kotlin_obdii/CLAUDE.md)
