# Skill: swiftui-engineering

## Purpose
Implement or review SwiftUI views for W OS — the simulated desktop OS shell — following the repo's design-system tokens, keeping views small, testable, and touch-friendly on iPhone screens.

## Activation conditions
User asks to build/modify a W OS screen, window chrome, dock, status bar, control center, overlay, or app view in `Sources/wOS/Views/` or `Sources/wOS/Apps/`.

## Required inputs
- Target file path(s) in `Sources/wOS/`
- Description of desired behavior (states: loading/empty/error/success)
- Whether the view is a window content (routed via `WindowView.content`) or an overlay panel

## Step-by-step procedure
1. Read `Sources/wOS/Theme/Tokens.swift` and `Sources/wOS/Theme/Colors.swift`; reuse `WOSFont`, `WOSGrid`, `Color.wos*`.
2. Read `Sources/wOS/ViewModels/SystemState.swift` to understand `@EnvironmentObject systemState` routing (screen, windows, overlays).
3. Write the view as a value-type `struct View` taking `@EnvironmentObject var systemState: SystemState` when it needs OS state.
4. Add `.accessibilityLabel`/`.accessibilityHint` on every interactive control.
5. Avoid `force unwrap`, `try!`, `fatalError`, simulated progress bars presented as real work, and hard-coded credentials.
6. Keep animations non-blocking: use `withAnimation` / `.animation` only on state changes, never `Timer` for visual polling unless essential (see `MusicAppView` precedent).
7. Run `swift build`-equivalent checks mentally: all referenced symbols exist (`systemState.openApp`, `LinkingService.openRealApp`, `WindowInstance`).
8. Add a unit test in `Tests/wOS/` for any new logic (window focus, validation, error mapping).
9. Update `docs/ENGINEERING_AUDIT.md` defect table if the change fixes a logged defect.

## Safety constraints
- Never present simulated work as real (no fake install progress, no fake terminal shell).
- W OS views never control SpringBoard or other apps (documented iOS limitation).
- No secrets, keys, or credentials in source or logs.

## Validation checklist
- View compiles against existing symbols (cannot compile locally — no Xcode; verify on macOS runner via CI).
- All user-facing strings have accessibility labels.
- No new force-unwraps (`grep '!'` outside optional bool literals).
- Light and dark appearances respected (views use `Color.wos*`, not hard-coded `Color.white` backgrounds where dark mode matters).

## Expected outputs
- Modified/added Swift file(s) under `Sources/wOS/`
- Optional test(s) under `Tests/wOS/`
- Updated audit doc if a defect was fixed

## Relevant official references
- Apple: SwiftUI `View`, `EnvironmentObject`, `accessibilityLabel(_:)` — developer.apple.com/documentation/swiftui
- Repo: `docs/ENGINEERING_AUDIT.md`, `Sources/wOS/ViewModels/SystemState.swift`
