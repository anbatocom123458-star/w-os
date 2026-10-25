# W APK Lab — Architecture Proposal

**Status:** proposal only. No implementation in this release.

## 1. Platform constraint (stated up front)

An Android APK **cannot** be installed as a native iOS application by renaming, extracting, or repackaging it. iOS does not run Dalvik/ART bytecode, and there is no supported Android runtime on iOS. W APK Lab is an **analysis tool only**.

## 2. Boundaries

| What it is | What it is NOT |
|------------|----------------|
| APK archive inspection (ZIP structure, `AndroidManifest.xml` metadata) | Android app installation on iOS |
| Declared-permission and package-metadata reporting | App porting or compatibility assessment |
| Optional handoff to an authorized external Android environment | A promise of Android runtime support |

Every UI screen must visually distinguish **APK analysis** (local, offline, safe) from **remote Android installation/testing** (external, requires explicit user action) from **native iOS app installation** (handled by W Sign Center / SideStore handoff — unrelated to APKs).

## 3. Features

1. Import APK via system file picker (`UIDocumentPickerViewController`, `.apk`).
2. Validate archive structure: ZIP End of Central Directory, `AndroidManifest.xml` presence, `classes.dex`, `resources.arsc`.
3. Extract and display: package name, version code/name, target SDK, declared permissions, activities/services/receivers (from a parsed `AndroidManifest.xml`; binary XML parsing is best-effort, errors reported clearly).
4. Archive contents list + file sizes.
5. Clear parsing-error reporting: "Not a valid APK/ZIP", "Manifest unreadable", etc.
6. Optional: transfer the APK to an authorized remote Android emulator/external dev environment — only after explicit user action, with clear destination and privacy notice. No automatic execution of uploaded APKs.
7. Path-traversal rejection during extraction (reuse ZipImportService).

## 4. What is intentionally excluded

- No APK-to-IPA conversion.
- No Android emulator bundled with W OS.
- No background/automatic execution of imported APKs.
- No claims that any analyzed APK can run on iOS.
