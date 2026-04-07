# Release Automation

This repo uses semantic-release with conventional commits for automated versioning and releases.

## Pipeline Overview

```
PR with conventional commit title → squash-merge to main
  → version.yml runs semantic-release
    → analyzes commits, determines version bump
    → updates MARKETING_VERSION in project.pbxproj
    → commits version change to main
    → creates git tag vX.Y.Z and GitHub Release
      → release.yml triggers on tag
        ├── macOS: build, sign, notarize → upload artifacts → Homebrew tap update
        └── iOS: archive, export IPA → TestFlight upload
```

## How to Release

1. Create a PR with a conventional commit title:
   - `feat: add new feature` → minor bump (1.0.3 → 1.1.0)
   - `fix: resolve bug` → patch bump (1.0.3 → 1.0.4)
   - `feat!: breaking change` → major bump (1.0.3 → 2.0.0)
   - `chore: update deps` → no release
2. Squash-merge to `main`.
3. Everything else is automated.

## Commit Types

| Type | Release |
|------|---------|
| `feat` | minor |
| `fix`, `perf` | patch |
| `feat!` / `BREAKING CHANGE` | major |
| `chore`, `docs`, `style`, `refactor`, `test`, `ci`, `build` | no release |

## Build Numbers

`CURRENT_PROJECT_VERSION` is set from `GITHUB_RUN_NUMBER` in the release workflow. `MARKETING_VERSION` is set by semantic-release.

## macOS Distribution

Distributed outside the App Store via Homebrew:

```bash
brew tap pseudobun/tap
brew install --cask tossinger
```

The macOS target is unsandboxed for Accessibility API support.

## iOS Distribution

Uploaded to TestFlight via App Store Connect API. Uses automatic signing with API key auth.

## Required GitHub Secrets

### macOS Signing

| Secret | Description |
|--------|-------------|
| `MACOS_CERT_P12_BASE64` | Base64-encoded Developer ID Application `.p12` |
| `MACOS_CERT_PASSWORD` | Password for the `.p12` |
| `MACOS_DEVELOPER_ID_APP_CERT` | Signing identity string |

### App Store Connect API Key

| Secret | Description |
|--------|-------------|
| `ASC_KEY_ID` | API Key ID |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_PRIVATE_KEY` | Base64-encoded `.p8` private key |

### iOS Signing

| Secret | Description |
|--------|-------------|
| `IOS_DIST_CERT_P12_BASE64` | Base64-encoded Apple Distribution `.p12` |
| `IOS_DIST_CERT_PASSWORD` | Password for the `.p12` |

### Homebrew Tap

| Secret | Description |
|--------|-------------|
| `HOMEBREW_TAP_TOKEN` | Fine-grained PAT with Contents read+write on `pseudobun/homebrew-tap` |

### Versioning

| Secret | Description |
|--------|-------------|
| `RELEASE_TOKEN` | Fine-grained PAT with Contents + Issues + PRs read+write on `pseudobun/tossinger` |
