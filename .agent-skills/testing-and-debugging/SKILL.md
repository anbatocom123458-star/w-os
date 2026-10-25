# Skill: testing-and-debugging

## Purpose
Run and extend W OS verification: XcodeGen project generation, device + Simulator builds, unit tests, static checks — via GitHub Actions (no Xcode locally).

## Activation conditions
Before/after source changes; CI failures; test additions.

## Required inputs
- macOS runner with Xcode (GitHub Actions `macos-15`)
- `project.yml`, `.github/workflows/ci.yml`, `Tests/wOS/`

## Step-by-step procedure
1. Locally (macOS): `brew install xcodegen`, `xcodegen generate`, `open wOS.xcodeproj`, build scheme `wOS` for Generic iOS Device and Simulator.
2. CI: push to `main` or run `workflow_dispatch` on `ci.yml`; confirm steps pass: version checks, project generation, `xcodebuild -list` (schemes `wOS`, `wOSTests`), device build, Simulator build, unit tests, artifact upload.
3. On CI failure: download the failed run's artifacts (`build-device.log`, `build-simulator.log`, `test.log`), find the earliest `xcodebuild` error, classify cause (source / project generation / dependencies / toolchain / signing / environment), fix root cause, re-run.
4. Never weaken checks to hide failures (no `CODE_SIGNING_ALLOWED=NO` on signed jobs; no ignoring `xcodebuild` exit codes).
5. Add unit tests in `Tests/wOS/` using XCTest + `@testable import wOS` for: state transitions, window open/close/focus, URL normalization, error descriptions.
6. Static checks: grep for `try!`, `fatalError`, force unwraps (`!` outside bool literals), hard-coded secrets, `TODO`/`FIXME`.

## Safety constraints
- Do not claim physical-device testing unless performed on a physical device (state the limitation otherwise).
- Do not hide build failures by disabling code signing on signed jobs.

## Validation checklist
- `xcodebuild -list` shows both schemes after `xcodegen generate`.
- `xcodebuild build -sdk iphoneos -destination 'generic/platform=iOS'` succeeds unsigned.
- `xcodebuild test -scheme wOSTests` succeeds on Simulator.
- Artifacts contain `.app` zips + logs; `if-no-files-found: error` triggers only when missing.

## Expected outputs
- Passing CI run on GitHub Actions
- New/updated tests under `Tests/wOS/`
- Fixed root cause (not suppressed error)

## Relevant official references
- Apple: `xcodebuild(1)`, Xcode Testing Guide (developer.apple.com)
- GitHub Actions: `actions/upload-artifact` (github.com/actions)
