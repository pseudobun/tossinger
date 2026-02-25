# Release Automation

This repo is configured for:

1. Changesets-based versioning
2. Automatic release tagging
3. macOS Homebrew artifact build + GitHub Release upload

## How versioning works

1. Create a changeset in your PR:
   - `pnpm install`
   - `pnpm run changeset`
2. Merge PR to `main`.
3. `Versioning` workflow opens/updates a version PR:
   - bumps `package.json` version
   - syncs Xcode `MARKETING_VERSION` in `toss.xcodeproj/project.pbxproj`
4. Merge version PR.
5. `Tag Release` workflow creates tag `vX.Y.Z`.
6. `macOS Homebrew Artifact` workflow runs on the new tag and uploads a macOS zip + sha256 for Homebrew.

## Homebrew artifact publishing

`macOS Homebrew Artifact` runs on `v*` tags (and can also be run manually with `workflow_dispatch`).

It will:

1. Build `Tossinger.app` in Release mode.
2. Optionally sign + notarize (if secrets are provided).
3. Create `Tossinger-<version>-macos.zip`.
4. Generate `Tossinger-<version>-macos.sha256.txt`.
5. Attach both files to the GitHub Release `v<version>`.
6. Print a ready-to-paste cask snippet in the workflow summary.

To publish via Homebrew, use a tap repo (for example `homebrew-tossinger`) and update the cask there with the emitted URL + sha256:

- URL: `https://github.com/<owner>/<repo>/releases/download/v<version>/Tossinger-<version>-macos.zip`
- `sha256`: value from the generated `.sha256.txt` file

## Required GitHub Secrets

For Homebrew artifact signing/notarization (optional, but recommended):

- `MACOS_CERT_P12_BASE64` (base64-encoded Developer ID Application cert `.p12`)
- `MACOS_CERT_PASSWORD`
- `MACOS_DEVELOPER_ID_APP_CERT` (codesign identity name, for example `Developer ID Application: Your Name (TEAMID)`)
- `NOTARY_KEY_ID` (App Store Connect API key ID)
- `NOTARY_ISSUER_ID` (App Store Connect issuer ID)
- `NOTARY_PRIVATE_KEY` (base64-encoded ASC API private key `.p8`)

## Notes

- macOS App Store submission is currently out-of-scope for this setup because the macOS target is configured unsandboxed for Accessibility-based cross-app text capture.
