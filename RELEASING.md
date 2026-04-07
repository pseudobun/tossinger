# Release Automation

This repo uses changesets-based versioning with automated releases for both macOS (Homebrew) and iOS (TestFlight).

## Pipeline Overview

```
PR with changeset → merge to main
  → versioning.yml bumps version, opens version PR
    → merge version PR to main
      → tag-release.yml creates vX.Y.Z tag
        → release.yml triggers on tag
          ├── macOS: build, sign, notarize → GitHub Release → Homebrew tap update
          └── iOS: archive, export IPA → TestFlight upload
```

## How to Release

1. Create a changeset in your PR:
   ```bash
   pnpm install
   pnpm run changeset
   ```
2. Merge PR to `main`.
3. `Versioning` workflow opens/updates a version PR that bumps `package.json` and syncs Xcode `MARKETING_VERSION`.
4. Merge the version PR.
5. `Tag Release` workflow creates tag `vX.Y.Z`.
6. `Release` workflow runs on the tag — both macOS and iOS jobs run in parallel.

Build numbers (`CURRENT_PROJECT_VERSION`) are set automatically from `GITHUB_RUN_NUMBER`.

## macOS Lane

1. Builds `Tossinger.app` in Release mode with Developer ID signing.
2. Codesigns with hardened runtime.
3. Notarizes via `xcrun notarytool` and staples the ticket.
4. Packages as `Tossinger-<version>-macos.zip` with SHA256 checksum.
5. Creates/updates a GitHub Release with the artifacts.
6. Auto-updates `pseudobun/homebrew-tap` with new version, SHA256, and download URL.

Users install with:
```bash
brew tap pseudobun/tap
brew install --cask tossinger
```

## iOS Lane

1. Archives for iOS with automatic signing via App Store Connect API key.
2. Exports `.ipa` with `app-store` method (includes share extension).
3. Uploads to TestFlight via `xcrun altool`.

## Required GitHub Secrets

### macOS Signing

| Secret | Description |
|--------|-------------|
| `MACOS_CERT_P12_BASE64` | Base64-encoded Developer ID Application `.p12` certificate with private key. Export from Keychain Access, then `base64 -i cert.p12 \| pbcopy`. |
| `MACOS_CERT_PASSWORD` | Password set during `.p12` export. |
| `MACOS_DEVELOPER_ID_APP_CERT` | Signing identity string, e.g. `Developer ID Application: Your Name (RFY9T5P84M)`. Find with `security find-identity -v -p codesigning`. |

### App Store Connect API Key (shared for notarization + TestFlight)

| Secret | Description |
|--------|-------------|
| `ASC_KEY_ID` | API Key ID from [App Store Connect → Keys](https://appstoreconnect.apple.com/access/integrations/api). Create with "App Manager" role. |
| `ASC_ISSUER_ID` | Issuer ID shown at top of the API Keys page. |
| `ASC_PRIVATE_KEY` | Base64-encoded `.p8` private key. Downloaded once when creating the key: `base64 -i AuthKey_XXXX.p8 \| pbcopy`. |

### iOS Signing

| Secret | Description |
|--------|-------------|
| `IOS_DIST_CERT_P12_BASE64` | Base64-encoded Apple Distribution `.p12` certificate with private key. Create at [developer.apple.com/certificates](https://developer.apple.com/account/resources/certificates/list) if needed. |
| `IOS_DIST_CERT_PASSWORD` | Password for the `.p12`. |

### Homebrew Tap

| Secret | Description |
|--------|-------------|
| `HOMEBREW_TAP_TOKEN` | Fine-grained GitHub PAT with Contents read+write on `pseudobun/homebrew-tap`. Create at [github.com/settings/tokens](https://github.com/settings/tokens). |

## Notes

- macOS is distributed outside the App Store (unsandboxed, for Accessibility API support).
- iOS uses automatic signing with API key auth — no manual provisioning profile management needed.
- The `tossShare` extension is automatically included in iOS archives since it's a dependency of the `toss` scheme.
