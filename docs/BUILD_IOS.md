# Building wOS on iOS (GitHub Actions)

This document replaces the former Codemagic instructions. `codemagic.yaml` has been removed from the repository.

**Environment note:** this document was written on a Linux machine without Xcode. Steps involving `xcodebuild`, `xcodegen`, or device execution have not been executed here and must be validated on a macOS runner with Xcode (the CI workflows do exactly that).

## 1. Repository facts (verified)

| Item | Value |
|------|-------|
| Project generator | XcodeGen from `project.yml` (`.xcodeproj` is gitignored, never committed) |
| Generated project | `wOS.xcodeproj` |
| Target / scheme | `wOS` |
| Test target/scheme | `wOSTests` |
| Bundle ID prefix | `com.wOS` (set in `project.yml` options; `CFBundleIdentifier` is not in `Info.plist`, so XcodeGen synthesizes it — confirm from `xcodebuild -showBuildSettings`) |
| Deployment target | iOS 17.0 |
| Signing | None configured in repo; unsigned CI builds use `CODE_SIGNING_ALLOWED=NO` |

## 2. GitHub Actions workflows

### `.github/workflows/ci.yml` — runs on push to `main`, pull requests, and `workflow_dispatch`

1. `actions/checkout@v4` — pinned to v4 (reviewed stable release).
2. `xcodebuild -version` + `swift --version` — toolchain checks.
3. `brew install xcodegen` — XcodeGen installed from Homebrew each run.
4. `xcodegen generate` — generates `wOS.xcodeproj` from `project.yml`.
5. `xcodebuild -list` — validates the generated project and lists schemes/destinations.
6. `xcodebuild -showBuildSettings` — prints resolved `PRODUCT_BUNDLE_IDENTIFIER`, `SDKROOT`, deployment target, code-signing state.
7. Build for **generic iOS device** (`-sdk iphoneos -destination 'generic/platform=iOS'`), unsigned (`CODE_SIGNING_ALLOWED=NO`, `ONLY_ACTIVE_ARCH=NO`).
8. Build for **iOS Simulator** (`-sdk iphonesimulator -destination 'generic/platform=iOS Simulator'`), unsigned.
9. Run unit tests on Simulator (`-scheme wOSTests`, `OS=latest, name=iPhone 15`).
10. Locate produced `.app` bundles in DerivedData, zip them with `ditto`, verify with `unzip -t`.
11. Upload `wOS-unsigned-build` artifact (`.app` zips + logs), retention 30 days, `if-no-files-found: error`.

**Failure handling:** every build/test step uses `set -o pipefail` so a failing `xcodebuild` fails the step even when piped through `tee`. The upload step uses `if: always()` so logs are preserved when a job fails.

### `.github/workflows/release-ipa.yml` — runs on release `published` and `workflow_dispatch`

- `prepare` job: checks that `IOS_SIGNING_CERTIFICATE`, `IOS_SIGNING_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE` secrets exist (never prints their values); outputs `signing_available`.
- `unsigned-build` job: always runs; unsigned Release build for generic iOS device; uploads `wOS-unsigned-release-app`.
- `signed-ipa` job: runs only when signing secrets are present: temporary keychain with random per-run password; certificate + provisioning profile imported (base64-decoded, never logged); identity validation via `security find-identity`; export-options plist with `method` and `teamID` from the profile; `xcodebuild archive`/`exportArchive`; `codesign --verify` on the `.app` inside the IPA; upload `wOS-signed-ipa`; temporary keychain cleanup (`if: always()`).

### Trigger matrix

| Workflow | `push` | `pull_request` | `release` | `workflow_dispatch` |
|----------|--------|----------------|-----------|---------------------|
| ci.yml | main | main | — | yes |
| release-ipa.yml | — | — | published | yes (optional `export_method`) |

### Permissions and concurrency

- `GITHUB_TOKEN`: `contents: read` only (least privilege).
- Concurrency groups cancel in-progress CI runs for the same ref; release runs do not cancel.
- No secrets are logged: certificate/profile material is base64-decoded to files, never echoed.

## 3. How to run a build

### On GitHub Actions

- Push to `main` or open a PR → `ci.yml` runs automatically.
- Manual: Actions tab → "CI — build and test wOS" → Run workflow.
- Signed IPA: Actions tab → "Release — signed IPA export" → Run workflow (choose export method), or publish a GitHub release. The signed job is skipped with a visible notice when secrets are absent.

### Locally (macOS with Xcode)

```bash
brew install xcodegen
cd /path/to/wOS
xcodegen generate
open wOS.xcodeproj
```

Then select the `wOS` scheme and build for "Generic iOS Device" or a Simulator destination. Unit tests: run the `wOSTests` scheme.

## 4. How to download artifacts

1. Go to the Actions tab → select the workflow run.
2. "Artifacts" section → download:
   - `wOS-unsigned-build` (CI): unsigned device `.app` zip, simulator `.app` zip, build/test logs.
   - `wOS-unsigned-release-app` (release workflow): unsigned Release `.app` zip.
   - `wOS-signed-ipa` (release workflow, only when secrets present): signed `.ipa` + export logs.

Artifacts are retained for **30 days** and then deleted automatically.

## 5. How to configure signing secrets

In GitHub: Settings → Secrets and variables → Actions → New repository secret:

| Secret | Content | Encoding |
|--------|---------|----------|
| `IOS_SIGNING_CERTIFICATE` | Contents of your `.p12` code-signing certificate | base64 |
| `IOS_SIGNING_CERTIFICATE_PASSWORD` | `.p12` file password | plaintext (stored as a secret) |
| `IOS_PROVISIONING_PROFILE` | Contents of your `.mobileprovision` | base64 |

Example (do not run with real values in plain sight):

```bash
base64 -i Certificate.p12 | pbcopy   # paste into IOS_SIGNING_CERTIFICATE
base64 -i profile.mobileprovision | pbcopy   # paste into IOS_PROVISIONING_PROFILE
```

## 6. Simulator vs unsigned IPA vs signed installable IPA

| Artifact | What it is | Can it be installed on an iPhone? |
|----------|-----------|-----------------------------------|
| Simulator `.app` (CI) | Compiled for `iphonesimulator` (x86_64/arm64 simulator) | **No** — simulator only |
| Unsigned device `.app` (CI/release) | Compiled for `iphoneos`, no code signature | **No** — iOS refuses to install unsigned apps |
| Signed `.ipa` (release workflow) | Signed Payload archive, signed with imported certificate + profile | **Yes** — for devices covered by the provisioning profile (Ad Hoc/Development) or via TestFlight/App Store Connect (App Store method) |

An **unsigned IPA is not directly installable as an ordinary signed iOS application**. iOS enforces code signing; an unsigned `.app`/`.ipa` can only be used for build validation, not installation. If you need an installable file, use the `signed-ipa` job with valid signing secrets and a provisioning profile covering the target devices.

## 7. Troubleshooting

### XcodeGen / project generation

- `xcodegen generate` fails: confirm `project.yml` is valid XcodeGen YAML; run `xcodegen generate` locally to see the full error. The project pins `xcodeVersion: "15.0"` — ensure the runner image has a compatible Xcode (the workflow uses `macos-15`; review this when Xcode is upgraded).
- `wOS.xcodeproj` not found after generation: the `.gitignore` excludes `*.xcodeproj`; it is generated fresh every run.

### Scheme

- `xcodebuild -list -project wOS.xcodeproj` prints available schemes and targets. The workflow expects schemes `wOS` and `wOSTests`. If the scheme name differs, update `env.XCODE_SCHEME` / `env.TEST_SCHEME` in the workflows — never hard-code a scheme that does not exist in the generated project.

### Provisioning and export

- `No .ipa was produced by exportArchive`: usually a signing mismatch (certificate not matching profile, `teamID` wrong, or profile not covering the app's bundle ID). Confirm `security find-identity` lists an imported identity, and that the profile UUID matches `PROVISIONING_PROFILE_SPECIFIER`.
- `codesign --verify` fails: the `.app` inside the IPA was not signed correctly — check export log and the export-options `method` (`app-store`, `ad-hoc`, `enterprise`, `development`).
- `if-no-files-found: error`: the artifact step fails explicitly when no `.app`/`.ipa` exists — this is intended; inspect `archive.log` / `export.log` (uploaded as artifacts).

### Common config drift

- `project.yml` deployment target is iOS 17.0; older README references to iOS 16.0+ were updated. Do not lower the deployment target without re-checking API usage (`scrollContentBackground` needs iOS 16+).
- `Info.plist` has no `CFBundleIdentifier`; XcodeGen synthesizes it from `options.bundleIdPrefix`. Check the resolved value with `xcodebuild -showBuildSettings` before writing any export-options `provisioningProfiles` mapping.
