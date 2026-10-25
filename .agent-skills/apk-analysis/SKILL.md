# Skill: apk-analysis

## Purpose
Analyze Android APK files safely on iOS: archive validation, manifest metadata, permissions, sizes — and clearly separate analysis from (unsupported) Android installation.

## Activation conditions
Work touching `docs/W_APK_LAB.md`, `Services/ZipImportService.swift`, or APK import flows.

## Required inputs
- APK file from system file picker (`UTType` `com.google.android.package-archive` / `.apk`)
- `ZipImportService` (ZIP EOCD/central-directory parsing, path-traversal rejection)

## Step-by-step procedure
1. Import via `UIDocumentPickerViewController` into the app container only; never outside the sandbox.
2. Validate ZIP structure with `ZipImportService.inspectArchive(at:)`: entries, sizes, compression methods.
3. Locate `AndroidManifest.xml` entry; parse binary XML best-effort; report package name, version code/name, target SDK, declared permissions; on parse failure report a clear error ("Manifest unreadable") — never invent values.
4. Reject path-traversal entries (`..`, absolute paths) before any extraction (ZipImportService).
5. Extraction: stored entries only; deflated entries → clear `unsupportedCompression` error (no bundled decompression library).
6. Optional remote transfer: only after explicit user action, with destination and privacy notice; never auto-execute.
7. UI must visually separate: APK analysis | remote Android testing | native iOS installation.

## Safety constraints
- State the platform constraint up front: APK cannot run natively on iOS (no ART/Dalvik); no porting/compatibility promises.
- No automatic execution of uploaded APKs.
- No claims of Android runtime support unless a tested, technically valid implementation exists (none in this repo).

## Validation checklist
- Invalid ZIP/APK produces a clear error, not a crash.
- Path-traversal entries are rejected before extraction.
- Manifest metadata labeled "best-effort" when binary XML parsing is limited.

## Expected outputs
- `docs/W_APK_LAB.md` (proposal); implementation via `ZipImportService` + file picker when added

## Relevant official references
- Android: APK format (source.android.com/docs/core/apex/apk-format), AndroidManifest binary XML (developer.android.com/guide/topics/manifest/manifest-intro)
