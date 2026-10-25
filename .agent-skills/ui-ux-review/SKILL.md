# Skill: ui-ux-review

## Purpose
Review W OS screens for the design system, touch targets, small-iPhone layout, accessibility, animation hygiene, and honest states (loading/empty/error/success).

## Activation conditions
Any change to `Sources/wOS/Views/`, `Sources/wOS/Apps/`, `Sources/wOS/Theme/`, or desktop/dock/window chrome.

## Required inputs
- Target view file(s)
- `Sources/wOS/Theme/Tokens.swift` (token reference)
- Device context: iPhone, portrait + landscape, small screens (SE size), deployment target iOS 17.0

## Step-by-step procedure
1. Colors/typography/spacing must use `Color.wos*`, `WOSFont`, `WOSGrid` — no hard-coded hex strings in views (keep existing `Color(hex:)` only inside token files).
2. Touch targets: buttons ≥ 44×44 pt.
3. Layout must not place windows off-screen: `SystemState.openApp` offsets windows by `count % 5 * 16` — clamp positions to screen bounds (`WindowView`/desktop) and keep windows reachable on small iPhones.
4. Overlays (Control Center, Search, Notifications, Multitask, Virtual Mouse) use high `zIndex` and `transition`; closing returns focus appropriately.
5. Every interactive control: `.accessibilityLabel` and `.accessibilityHint`.
6. States: empty (`Thư mục trống`), error (actionable message + "Đóng"), loading (`ProgressView` with real work behind it — never fake), success (`checkmark.seal.fill` + `.wosSuccess`).
7. Animations: `easeInOut` ≤ 0.4s, no main-thread-blocking timers for UI; avoid excessive blur/gradient/oversized cards.
8. Light/dark: `.preferredColorScheme(.dark)` at root; views must not assume white backgrounds.

## Safety constraints
- No fake UI presenting simulated features as real (rule 8).
- No desktop layouts copied unadapted to touch.
- W OS never claims system-wide pointer control.

## Validation checklist
- All buttons ≥ 44 pt.
- Accessibility labels on all interactive controls.
- Window positions clamped to screen bounds.
- No new `Color(hex:)` literals outside `Theme/`.

## Expected outputs
- Review notes (PR comments or audit doc updates)
- Fixed view files where issues found

## Relevant official references
- Apple: Human Interface Guidelines (touch targets, accessibility), SwiftUI `accessibilityLabel(_:)` (developer.apple.com)
