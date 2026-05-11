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

## Project Structure
*   **[flutter_obdii/](file:///c:/Users/chica/OneDrive/Documents/git/obdii/flutter_obdii)**: Flutter implementation (iOS/Android/Windows).
*   **[kotlin_obdii/](file:///c:/Users/chica/OneDrive/Documents/git/obdii/kotlin_obdii)**: Kotlin/Compose implementation (Android/JVM).

## Build and Test Commands
Refer to subproject-specific `CLAUDE.md` files for detailed commands:
*   [Flutter Commands](file:///c:/Users/chica/OneDrive/Documents/git/obdii/flutter_obdii/CLAUDE.md)
*   [Kotlin Commands](file:///c:/Users/chica/OneDrive/Documents/git/obdii/kotlin_obdii/CLAUDE.md)
