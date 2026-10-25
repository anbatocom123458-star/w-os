# Skill: ios-security-audit

## Purpose
Review W OS source for security defects: hard-coded credentials, insecure network settings, plain-text secrets, unsafe file handling, path traversal, and fake-success paths.

## Activation conditions
Security review of any change touching `Sources/wOS/Services/`, `Support/Info.plist`, networking, persistence, or file import.

## Required inputs
- Full source tree (`Sources/wOS/`, `Support/Info.plist`)
- List of known secrets locations (none should exist in repo)

## Step-by-step procedure
1. Grep for credentials: `sk-`, `AKIA`, `-----BEGIN`, `.p12`, `.mobileprovision`, `password`, `apiKey`, `token` — none may be committed.
2. Check `Info.plist`: `NSAppTransportSecurity` → `NSAllowsArbitraryLoads` must be `false`; any `LSApplicationQueriesSchemes` entries are scheme queries only, not credentials.
3. Check persistence: `UserDefaults` must not store passwords or tokens in plain text (current: `wos_password` is stored plain — logged as defect P0-3; mitigate via Keychain before storing secrets).
4. Check file handling: all imports must reject `..` components and absolute paths; ZIP extraction via `ZipImportService` enforces this; never write outside the app container.
5. Check network: user-configured server URL (`CloudSyncService.baseURL`) must fail soft; no arbitrary command execution; `TerminalAppView` install must be labeled simulated (current: honest message).
6. Check simulated-progress rule (rule 8): no `ProgressView`/timer that pretends real work (BootDriveService, UpdateAppView, AppStore install timer — documented in audit S-1..S-6).
7. Confirm no code can control SpringBoard, move the system pointer, or inject input into other apps (Virtual Mouse is confined to W OS content area — documented).

## Safety constraints
- Never commit secrets, keys, or provisioning profiles.
- Do not disable security controls to make builds pass (ATS stays `false` only after documented risk acceptance).
- Report findings to `docs/ENGINEERING_AUDIT.md` defect table with P0/P1/P2/P3 priority.

## Validation checklist
- `grep -R` for hard-coded secrets returns nothing committed.
- `NSAllowsArbitraryLoads = false`.
- ZIP/path traversal rejection present in `ZipImportService`.
- Every network path has an offline fallback or clear error.

## Expected outputs
- Audit findings added to `docs/ENGINEERING_AUDIT.md`
- Fix commits for P0 security items (not locally verifiable — no Xcode)

## Relevant official references
- Apple: App Transport Security (developer.apple.com/documentation/security/app_transport_security)
- OWASP Mobile Security Testing Guide (owasp.org/www-project-mstg)
