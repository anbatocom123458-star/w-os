# W Sign Center — Architecture Proposal

**Status:** proposal only. No implementation in this release.  
**Related research:** SideStore URL Schema (docs.sidestore.io/docs/advanced/url-schema) — verified live on 2026-10-25.

## 1. Purpose

W Sign Center lets the user inspect IPA files and understand their signing/provisioning state before installation. It is **not** an app installer and does not bypass Apple code signing.

## 2. Subsystem boundaries

| Module | Responsibility | On-device? | External helper needed? |
|--------|----------------|------------|-------------------------|
| IPA metadata inspection | Read `Info.plist` from archive: `CFBundleIdentifier`, `CFBundleShortVersionString`, `CFBundleDisplayName`, `CFBundleExecutable`, `LSRequiresIPhoneOS`, entitlements | Yes | No |
| Signature inspection | Verify Mach-O code signature via `codesign -d --entitlements -` / `codesign -dv` where available | Yes (if `codesign` usable) | No |
| Provisioning profile inspection | Parse embedded `embedded.mobileprovision` (CMS/PKCS#7): Team ID, app ID, entitlements, expiration date, devices (Ad Hoc/Development), distribution type | Yes | No |
| Certificate reporting | Read certificate chain from profile/signature: issuer, subject, Team ID, expiration — **never trust a cert file alone** | Yes | No |
| Compatibility checks | Compare profile app ID vs bundle ID, expiration vs now, device UDID inclusion (provisioned devices list) | Yes | No |
| IPA import | Pick IPA via `UIDocumentPickerViewController` into app container; reject path traversal (reuse ZipImportService) | Yes | No |
| SideStore integration | Open `sidestore://install?url=<https url>` (SideStore downloads and installs) — only if SideStore is installed (`canOpenURL`) | Yes | SideStore app installed by user |
| Status & diagnostics | Classify state: malformed / unsigned / invalid signature / expired profile / incompatible profile / provisioned for this device / unknown | Yes | No |

## 3. State classification (exhaustive)

Every imported IPA must end in exactly one state:

| State | Meaning | Action offered |
|-------|---------|----------------|
| `malformed` | Not a ZIP, missing `Payload/*.app`, unreadable `Info.plist` | None (report error) |
| `unsigned` | Archive parses, but no valid code signature | Warn; no install path offered |
| `invalid-signature` | Signature present but does not validate (e.g. altered binary) | Warn; none |
| `expired-profile` | Valid signature, provisioning profile expired | Warn; none |
| `incompatible-profile` | Profile app ID/team doesn't match app, or device not in provisioned list | Warn; none |
| `signed-compatible` | Valid signature + valid profile + matches this device | Offer install handoff (SideStore or manual instructions) |
| `unknown` | Any other unparseable combination | Report diagnostics only |

Never report "valid" based only on the presence of a certificate file. A certificate file + valid signature + current profile + matching bundle ID are all required for `signed-compatible`.

## 4. SideStore integration (documented interface only)

Verified from SideStore docs (2026-10-25):

- `sidestore://install?url=[download url]` — SideStore downloads the IPA at that URL and installs it. **SideStore fetches the URL itself; W OS must not upload the IPA or any credentials anywhere.**
- `sidestore://source?url=[source url]` — add an AltSource (AltStore-compatible JSON catalog).

Handoff flow:
1. User imports an IPA into W OS documents.
2. W Sign Center inspects and classifies it.
3. If the IPA is hosted at an `https` URL the user controls, W Sign Center offers to open `sidestore://install?url=<url>` (URL-encoded), but only if `UIApplication.shared.canOpenURL(URL(string: "sidestore://install"))` — otherwise shows "SideStore not installed" with a link to SideStore's documentation.
4. W OS never invents SideStore APIs, never exports certificates, never uploads credentials/IPAs to a remote server.

Limitations documented:
- SideStore has **no documented local-file install scheme**. A local IPA copied into W OS cannot be handed to SideStore as a file; the user must host the IPA at an https URL or install manually via SideStore/AltStore on a computer.
- W OS cannot install IPAs itself; iOS reserves installation to the system installer.

## 5. Security rules

- No Apple credentials, private keys, or provisioning profiles are stored, logged, or transmitted by W OS.
- Credentials are never accepted from the user for "validation against a server".
- Diagnostics never include private keys, p12 contents, or team secrets.
- ZIP parsing rejects path traversal (`..`, absolute paths) before any file is read (see ZipImportService).

## 6. What W Sign Center will NOT do (honest boundaries)

- It will not install IPAs on behalf of the user.
- It will not claim a certificate is valid because a `.cer` file exists.
- It will not fabricate SideStore endpoints or pretend to be an AltStore.
- It will not bypass code signing, re-sign apps, or create profiles.
