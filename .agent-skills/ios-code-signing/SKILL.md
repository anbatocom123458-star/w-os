# Skill: ios-code-signing

## Purpose
Handle iOS code-signing material for W OS builds: import certificate + provisioning profile into a temporary keychain, validate compatibility, export a signed IPA, and clean up — without leaking secrets.

## Activation conditions
Running the `signed-ipa` job (`.github/workflows/release-ipa.yml`) or setting up signing secrets in GitHub.

## Required inputs
- GitHub Actions secrets: `IOS_SIGNING_CERTIFICATE` (base64 `.p12`), `IOS_SIGNING_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE` (base64 `.mobileprovision`)
- Generated Xcode project (`wOS.xcodeproj`), scheme `wOS`

## Step-by-step procedure
1. Create temp keychain: `security create-keychain -p <random> <path>`; `security default-keychain -s <path>`; unlock; `security set-key-partition-list -S apple-tool:,apple: -s -k <pw> <path>` so `codesign`/`xcodebuild` can access keys.
2. Decode base64 `.p12` to a temp file; `security import` with `-T /usr/bin/codesign -T /usr/bin/productbuild -T /usr/bin/xcodebuild`; delete temp p12 immediately.
3. Decode base64 `.mobileprovision`; copy to `~/Library/MobileDevice/Provisioning Profiles/`; delete temp file.
4. Validate: `security find-identity -v -p codesigning <keychain>`; read `TeamIdentifier` (array index 1 via `PlistBuddy -c 'Print :TeamIdentifier' | awk 'NR==2'`) and `UUID` via `PlistBuddy -c 'Print :UUID'`. Fail if either is empty.
5. Build archive: `xcodebuild archive -scheme wOS -sdk iphoneos -destination 'generic/platform=iOS' -configuration Release CODE_SIGN_IDENTITY="" PROVISIONING_PROFILE_SPECIFIER=<UUID>` — never hard-code an identity name.
6. Write ExportOptions.plist: `method` (app-store/ad-hoc/enterprise/development), `teamID` from the profile, `uploadSymbols: true`, `compileBitcode: false`.
7. `xcodebuild -exportArchive`; confirm an `.ipa` exists (`if-no-files-found: error`).
8. Verify signature: unzip IPA, `codesign --verify --verbose=4 Payload/W OS.app` (bundle name per resolved `CFBundleIdentifier`/`product name` — confirm via `xcodebuild -showBuildSettings`).
9. Cleanup (`if: always()`): `security delete-keychain <path>`; remove copied profiles.

## Safety constraints
- Never `echo`, log, or upload certificate/profile contents or passwords.
- Do not fabricate certificates or profiles.
- Do not bypass code signing (`CODE_SIGNING_ALLOWED=NO` only for unsigned validation builds).
- Paid Apple Developer membership is optional; unsigned CI build must succeed without secrets.

## Validation checklist
- Signed job skipped with visible notice when secrets are absent.
- `codesign --verify` passes on the `.app` inside the exported IPA.
- Temporary keychain deleted even when the job fails.

## Expected outputs
- Signed `.ipa` artifact (`wOS-signed-ipa`) + logs
- No secrets in build logs

## Relevant official references
- Apple: Code Signing Guide, App Distribution Guide, `security(1)`, `codesign(1)` (developer.apple.com)
