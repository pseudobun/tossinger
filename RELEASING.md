# Release Automation

This repo uses [release-please](https://github.com/googleapis/release-please) with conventional commits for **batched** versioning and releases. Multiple PRs can merge into `main` freely; releases are cut explicitly by merging a "Release PR" that release-please maintains.

## Pipeline Overview

```
PR with conventional commit title → squash-merge to main
  → release-please.yml runs release-please
    → aggregates all unreleased commits into a single "Release PR"
    → updates CHANGELOG.md and .release-please-manifest.json in that PR

(maintainer reviews and merges the Release PR when ready to ship)

  → release-please creates git tag vX.Y.Z and a GitHub Release
    → release.yml triggers on `release: published`
      ├── macOS: build, sign, notarize → upload artifacts → Homebrew tap update
      └── iOS: archive, export IPA → TestFlight upload
```

## How to Release

1. Merge feature/fix PRs to `main` with conventional commit titles whenever you want:
   - `feat: add new feature` → minor bump
   - `fix: resolve bug` → patch bump
   - `feat!: breaking change` → major bump
   - `chore: update deps` → no release
2. release-please keeps a single **"chore(main): release X.Y.Z"** PR open on `main`, aggregating every unreleased commit and showing the proposed version + changelog.
3. When you're ready to ship, review that Release PR and merge it. Everything after is automated:
   - Tag `vX.Y.Z` is created.
   - A GitHub Release is published.
   - `release.yml` builds, signs, notarizes, publishes the Homebrew cask, and uploads to TestFlight.
4. If you merge three fixes in a day but want them in a single release, just don't merge the Release PR until all three are in — it batches automatically.

### Syncing local dev build version

`MARKETING_VERSION` in `toss.xcodeproj/project.pbxproj` is **not** auto-committed back to `main`. CI overwrites it from the git tag at build time, so releases are unaffected, but local Xcode dev builds may show a stale marketing version. To sync:

```bash
./scripts/update_xcode_versions.sh --marketing 1.2.3
```

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
| `RELEASE_TOKEN` | Fine-grained PAT with Contents + Pull Requests read+write on `pseudobun/tossinger`. Required so the `release: published` event emitted by release-please triggers `release.yml` (the default `GITHUB_TOKEN` does not trigger downstream workflows). |
