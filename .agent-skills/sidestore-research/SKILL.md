# Skill: sidestore-research

## Purpose
Research SideStore's documented interfaces before any W Sign Center integration; produce an honest handoff plan, never undocumented APIs or fake installation.

## Activation conditions
Work touching `docs/W_SIGN_CENTER.md`, IPA signing/install flows, or SideStore references.

## Required inputs
- SideStore docs: https://docs.sidestore.io/docs/advanced/url-schema and https://docs.sidestore.io/docs/advanced/app-sources (re-verify before relying)
- W OS files: `Services/ZipImportService.swift`, `docs/ENGINEERING_AUDIT.md`

## Step-by-step procedure
1. Fetch the official SideStore URL Schema doc; record exact schemes:
   - `sidestore://install?url=[download url]` — SideStore downloads and installs a remotely hosted IPA itself.
   - `sidestore://source?url=[source url]` — add an AltStore-compatible source.
2. Confirm SideStore has **no documented local-file install scheme** (a local IPA cannot be handed to SideStore as a file).
3. Confirm SideStore is AltSource-compatible (AltStore source JSON catalog).
4. Design W Sign Center handoff: inspect IPA locally (metadata, signature, profile), classify state; if the IPA is hosted at a user-controlled https URL and SideStore is installed (`canOpenURL(sidestore://install)`), offer to open `sidestore://install?url=<encoded url>`; otherwise show manual-install instructions.
5. Record the research date and source URLs in the proposal doc (docs are living; re-verify quarterly).

## Safety constraints
- Never invent SideStore endpoints or parameters.
- Never upload IPAs, certificates, private keys, or profiles to a remote server.
- Never claim W OS can install IPAs itself or bypass code signing.
- If SideStore is not installed, show a clear limitation message — no fake install button.

## Validation checklist
- SideStore scheme URLs quoted verbatim from official docs with retrieval date.
- Proposal distinguishes malformed/unsigned/invalid-signature/expired-profile/incompatible/unknown states.
- Handoff requires explicit user action and `canOpenURL` check.

## Expected outputs
- Updated `docs/W_SIGN_CENTER.md` with verified SideStore interface facts and limitations

## Relevant official references
- SideStore docs: docs.sidestore.io/docs/advanced/url-schema, docs.sidestore.io/docs/advanced/app-sources
- AltSource format: docs referenced by SideStore (AltStore Sources)
