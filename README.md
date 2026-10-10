# nook

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Branching and releases

`main` is always shippable. Releases are cut by pushing a version tag; merging to `main` never
releases anything.

### Day-to-day work

1. Branch from `main`: `feat/<name>` or `fix/<name>`.
2. Open a PR into `main`. The **iOS build** check must pass (an unsigned release build).
3. Squash-merge.

### Releasing an iOS update

1. Open a `release/<version>` PR that changes only:
   - `pubspec.yaml`: bump `version` (for example `1.1.5+12`). Only the part before `+` matters;
     CI sets the build number.
   - `ios/metadata/en-US/release_notes.txt`: the "What's New" text for this version.
2. Merge it, then tag `main`:
   ```bash
   git checkout main && git pull
   git tag v1.1.5 && git push origin v1.1.5
   ```
3. The **iOS release IPA** workflow builds and signs the app, uploads it to App Store Connect,
   waits for processing, and submits it for review (about 45 minutes).
4. Apple releases it to the App Store as soon as review approves it. No click needed.

The version must be higher than the one live on the App Store, or the submit step fails.

### Test build without submitting

Tag with a dash, such as `v1.1.5-test`. CI builds and uploads to TestFlight but skips the review
submission. Delete the tag after:

```bash
git push origin :v1.1.5-test && git tag -d v1.1.5-test
```

### Hotfix while `main` has unreleased work

```bash
git checkout -b hotfix/1.1.6 v1.1.5   # branch from the released tag
# fix, bump version to 1.1.6, update release notes, commit
git tag v1.1.6 && git push origin v1.1.6
```

Then open a PR from `hotfix/1.1.6` into `main` so the fix isn't lost.

### If a release run fails

The signed `.ipa` is saved on the run page under **Artifacts** for 7 days. Upload it with
**Transporter** and submit for review in App Store Connect by hand.

Signing secrets, renewal (certificate and profile expire **Oct 10, 2027**) and the full setup:
[`docs/release_ci.md`](docs/release_ci.md).
