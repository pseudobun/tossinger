# Changesets

Use Changesets to declare release intent from pull requests.

## Create a release note entry

```bash
npm install
npm run changeset
```

Commit the generated file under `.changeset/`.

When changesets are merged to `main`, GitHub Actions opens/updates a version PR that:

1. Bumps `package.json` version
2. Syncs `MARKETING_VERSION` in `toss.xcodeproj/project.pbxproj`

Merging the version PR auto-tags a release (`vX.Y.Z`) and triggers TestFlight upload workflow.
