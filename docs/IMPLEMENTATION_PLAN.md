# W OS — Implementation Plan

**Baseline:** docs/ENGINEERING_AUDIT.md (commit `b1d72ba`)  
**Environment constraint:** Linux x86_64 — no Swift/Xcode available. Source changes are written carefully but **cannot be compiled or executed here**; verification of builds/tests must happen on a macOS runner with Xcode (via the GitHub Actions workflows introduced in Phase 2).

## Guiding rules (from mission)

1. Inspect before modifying; never assume project values (done in audit).
2. Small, coherent, testable changes; preserve working features.
3. No fake UI / hard-coded success / simulated progress presented as real.
4. No credentials in logs; no force-push; no commits without authorization.
5. If a credential/device is unavailable, implement what is safe and document the blocker.

## Phase 1 — Discovery & audit (DONE)

- docs/ENGINEERING_AUDIT.md: inventory, confirmed defects P0–P8, simulated-path review S-1..S-6, security notes, working-features list.
- docs/IMPLEMENTATION_PLAN.md: this file.

## Phase 2 — GitHub Actions build + IPA distribution (priority P0/P1)

Goals: remove Codemagic; provide CI validation, unsigned build artifact, optional signed IPA export; document everything.

| Step | Action | File | Priority |
|------|--------|------|----------|
| 2.1 | Create `.github/workflows/ci.yml`: macOS runner, swift/xcode version checks, XcodeGen install + `xcodegen generate`, debug build for generic iOS device, Simulator build, run unit tests, preserve logs on failure, `workflow_dispatch` + `pull_request` + `push` triggers, `concurrency`, least-privilege `GITHUB_TOKEN`. | `.github/workflows/ci.yml` | P0 |
| 2.2 | Create `.github/workflows/release-ipa.yml`: optional signing job gated on signing secrets; temporary keychain; cert/profile import; `xcodebuild -archive` + `-exportArchive`; validate `.app` and `.ipa`; distinguish signed vs unsigned artifacts; upload with retention; fail explicitly on missing artifact. | `.github/workflows/release-ipa.yml` | P0 |
| 2.3 | Delete `codemagic.yaml`. Remove Codemagic references from `README.md` (build section, file tree, UpdateAppView credit line → GitHub Actions). | `codemagic.yaml`, `README.md`, `Sources/wOS/Apps/UpdateAppView.swift` | P0 |
| 2.4 | Write `docs/BUILD_IOS.md`: how to run builds, download artifacts, configure signing secrets, troubleshoot XcodeGen/scheme/provisioning/export errors, distinguish Simulator vs unsigned IPA vs signed installable IPA. | `docs/BUILD_IOS.md` | P1 |
| 2.5 | Align `project.yml` deployment target with README (iOS 17.0); evaluate removing the `xcodeVersion: "15.0"` pin so the runner's default Xcode is used. | `project.yml` | P1 |


## Phase 3 — W Desktop 2.0 (SwiftUI modernization) (P2)

| Step | Action | File |
|------|--------|------|
| 3.1 | Design-system token file: color + typography + spacing tokens; keep existing `Color.wos*` names; add `WOSFont`, `WOSGrid` spacing. | `Sources/wOS/Theme/Tokens.swift` |
| 3.2 | Reusable chrome: `WOSWindowChrome`, `WOSButton`, `WOSCard`, `WOSListRow`, `WOSToast` (loading/empty/error/success). | `Sources/wOS/Views/Components/` |
| 3.3 | Window manager: clamp positions to screen, resize, minimize animation, focus ring, z-order. | `SystemState.swift`, `Views/WindowView.swift`, `Views/DesktopView.swift` |
| 3.4 | Dock: configurable persisted app ids, active indicators, tap-to-focus/open. | `SystemState.swift`, `SystemAppsData.swift`, `Views/DesktopView.swift` |
| 3.5 | Accessibility labels on all controls; small-iPhone layout. | all views |
| 3.6 | Status bar / Control Center kept honest UI-only (iOS restriction documented). | existing views |

## Phase 4 — Virtual mouse + external input (P2)

| Step | Action | File |
|------|--------|------|
| 4.1 | `VirtualMouseService`: touchpad, pointer constrained to content area, single/double/secondary click, drag, speed/sensitivity, left-handed, haptics, enable/disable, persistence. | `Services/VirtualMouseService.swift`, `ViewModels/VirtualMouseViewModel.swift` |
| 4.2 | `VirtualMouseView` overlay; pointer uses same window ops (focus, drag, close). | `Views/VirtualMouseView.swift` |
| 4.3 | Document `UIPointerInteraction`/`UIHoverGesture` on iOS 17; keyboard shortcuts via `commands` scene modifier where supported. | docs + code |
| 4.4 | Explicit: W OS cannot move the system pointer or inject input into SpringBoard/other apps. | docs |


## Phase 5 — File manager + built-in apps (P2)

| Step | Action | File |
|------|--------|------|
| 5.1 | Real file browsing: `FileManager` Documents directory, import via `UIDocumentPickerViewController`, preview, search/sort/rename/move/copy/delete, duplicates, low-storage errors, progress + cancellation + actionable errors, no silent data loss. | `Apps/FileManagerAppView.swift` |
| 5.2 | ZIP import safety: reject path traversal (`..`), absolute paths, unsafe extraction; extract into app container only. | `Services/ZipImportService.swift` (new) |
| 5.3 | Terminal: label commands simulated vs real; `install` wired to real import or clearly unavailable; no fake shell. | `Apps/TerminalAppView.swift` |
| 5.4 | Notes/Weather/Music/Calendar/Calculator/Settings/AppStore/Browser/Update reviewed; error and empty states added where missing. | `Apps/*.swift` |

## Phase 6 — W Sign Center architecture proposal (P2/P3 — docs only)

Architecture proposal (no implementation, no fake installer):

1. IPA metadata inspection (`CFBundleIdentifier`, version, entitlements).
2. Signature + provisioning-profile inspection; distinguish malformed / unsigned / invalid / expired / incompatible / unknown.
3. Certificate expiration + Team ID reporting — never trust a certificate file alone.
4. Device/profile compatibility checks where verifiable on-device.
5. IPA import into supported installation workflows (handoff to SideStore or manual instructions).
6. SideStore via documented interfaces only; no undocumented APIs.
7. Status + diagnostics; no credential upload; minimize retention.

Deliverable: `docs/W_SIGN_CENTER.md`.

## Phase 7 — W APK Lab architecture proposal (P3 — docs only)

APK analysis on iOS: import via file picker, validate archive structure, extract package name/version/permissions, report parse errors, optional authorized remote-emulator integration with explicit user action. No Android runtime on iOS; distinguish analysis vs install vs porting. Deliverable: `docs/W_APK_LAB.md`.

## Phase 8 — Modern features (P2/P3, evaluated)

- Global search (exists — SearchView), recent apps/files, file sharing/export, app favorites, configurable dock (3.4), themes/wallpapers (exists), keyboard shortcuts (4.3), preferences import/export, diagnostic logs, crash-resistant state restoration, `NS*UsageDescription` keys, offline-first, AI assistant behind explicit config (no paid APIs without reason), version info + update notifications via documented source.

## Phase 9 — Testing and quality gates (P0/P1)

| Step | Action | File |
|------|--------|------|
| 9.1 | Add `Tests/` unit-test target to `project.yml`; tests for `SystemState` window management, `BootDriveError`, URL normalization, calculator. | `Tests/`, `project.yml` |
| 9.2 | CI runs `xcodebuild test` (Simulator) + device build. | `.github/workflows/ci.yml` |
| 9.3 | ZIP safety unit tests; IPA packaging artifact checks. | CI + tests |

## Phase 10 — AI CLI skills (P3)

| Skill | File |
|-------|------|
| swiftui-engineering | `.agent-skills/swiftui-engineering/SKILL.md` |
| github-actions-ios | `.agent-skills/github-actions-ios/SKILL.md` |
| ios-code-signing | `.agent-skills/ios-code-signing/SKILL.md` |
| ui-ux-review | `.agent-skills/ui-ux-review/SKILL.md` |
| ios-security-audit | `.agent-skills/ios-security-audit/SKILL.md` |
| testing-and-debugging | `.agent-skills/testing-and-debugging/SKILL.md` |
| sidestore-research | `.agent-skills/sidestore-research/SKILL.md` |
| apk-analysis | `.agent-skills/apk-analysis/SKILL.md` |

## Immediate execution order

1. Phase 2 steps 2.1–2.5 (CI workflows, remove Codemagic, BUILD_IOS.md, project.yml target alignment).
2. P0 source fixes: Calendar force unwrap, Notes force unwrap, Browser force unwrap, `NSAllowsArbitraryLoads → false`.
3. Test target + unit tests.
4. Phase 3 design tokens + Phase 4 virtual mouse + Phase 5 file manager.
5. Phase 6/7 proposal docs; Phase 10 skills.
6. Final report: changes list, actual command results, known limitations, blockers.

## Verification statement

Because this environment lacks Swift/Xcode, no `xcodebuild`, `swift test`, or device test has been executed. All source edits below are static edits only. CI workflows will perform the first real validation on macOS runners.
