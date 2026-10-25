# Skill: github-actions-ios

## Purpose
Add, modify, or troubleshoot GitHub Actions workflows that build, test, and export wOS (XcodeGen-generated Xcode project, no committed `.xcodeproj`).

## Activation conditions
CI/CD changes: workflow files under `.github/workflows/`, `project.yml`, signing-secrets documentation, or `docs/BUILD_IOS.md`.

## Required inputs
- Xcode project name (`wOS.xcodeproj`), scheme names (`wOS`, `wOSTests`) — discover via `xcodebuild -list`, never hard-code without verification
- Deployment target (iOS 17.0 per `project.yml`)
- Signing secrets (release workflow only): `IOS_SIGNING_CERTIFICATE` (base64 `.p12`), `IOS_SIGNING_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE` (base64 `.mobileprovision`)

## Step-by-step procedure
1. Confirm runner image compatibility: `project.yml` pins `xcodeVersion: "15.0"` → workflow uses `macos-15`; review when Xcode changes.
2. Job steps: `actions/checkout@v4` → `xcodebuild -version`/`swift --version` → `brew install xcodegen` → `xcodegen generate` → `xcodebuild -list` (validate scheme) → `xcodebuild -showBuildSettings` → build for `generic/platform=iOS` device AND Simulator with `CODE_SIGNING_ALLOWED=NO` → `xcodebuild test -scheme wOSTests` on Simulator → zip `.app` bundles via `ditto` → `actions/upload-artifact@v4` (retention 30 days, `if-no-files-found: error`).
3. Every `xcodebuild` call piped through `tee` must use `set -o pipefail`.
4. Signed export (release workflow): temporary keychain with random per-run password; import cert/profile from secrets (never echo them); `security find-identity -v -p codesigning`; read `TeamIdentifier`/`UUID` from profile via `PlistBuddy`; `xcodebuild archive` with `CODE_SIGN_IDENTITY="" PROVISIONING_PROFILE_SPECIFIER=<UUID>`; `xcodebuild -exportArchive`; `codesign --verify --verbose=4` on the `.app` inside the IPA; delete keychain in `if: always()` step.
5. Fail explicitly when no artifact exists (`if-no-files-found: error`, or explicit `test -f`).

## Safety constraints
- Never print secret values or private-key contents (GitHub masks secrets; still never `echo` them).
- Least privilege: `contents: read` on `GITHUB_TOKEN`.
- Unsigned `.ipa`/`.app` is **not installable** on iOS — state this in docs (see `docs/BUILD_IOS.md` section 6).
- Do not require paid Apple Developer membership for unsigned builds; signing job is optional and skipped visibly when secrets are absent.

## Validation checklist
- `python3 -c "import yaml; yaml.safe_load(open(...))"` passes for both workflows.
- `xcodebuild -list` shows schemes `wOS` and `wOSTests` after `xcodegen generate`.
- Build succeeds for generic iOS device (not only Simulator).
- Artifacts distinguish `wOS-unsigned-build` vs `wOS-signed-ipa`.

## Expected outputs
- `.github/workflows/ci.yml`, `.github/workflows/release-ipa.yml`
- `docs/BUILD_IOS.md`
- Workflow run artifacts on GitHub Actions (cannot be verified locally — no Xcode)

## Relevant official references
- GitHub Actions: `actions/checkout`, `actions/upload-artifact` (github.com/actions)
- Apple: `xcodebuild`, Xcode Code Signing Guide, App Distribution Guide (developer.apple.com)
