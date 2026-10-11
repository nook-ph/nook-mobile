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
2. Open a PR into `main`. The **iOS build** and **Android build** checks must pass (unsigned
   release builds; Android also runs analyze and tests).
3. Squash-merge.

### Releasing an update

1. Open a `release/<version>` PR that changes only:
   - `pubspec.yaml`: bump `version` (for example `1.1.5+13`). Only the part before `+` matters;
     CI sets the build number (`100 + run number`).
   - `ios/metadata/en-US/release_notes.txt`: the "What's New" text for this version. Android uses
     it too, so keep it under 500 characters.
2. Merge it, then tag a release candidate on `main`:
   ```bash
   git checkout main && git pull
   git tag v1.1.5-rc1 && git push origin v1.1.5-rc1
   ```
3. CI uploads Android to the Play **internal** track (tester list "Cris QA") and iOS to
   **TestFlight**. The run prints the build number; post it in the QA thread.
4. Bug found: fix it in a PR, merge, tag `v1.1.5-rc2`. Repeat until QA approves.
5. Approved: run Actions → **Android promote to production** (`version_code`) and
   **iOS submit for review** (`build_number`). Each store reviews, then it goes public.

The version must be higher than the one live on the App Store, or the submit step fails.
Details, tester opt-in link and setup: [QA loop and release candidates](docs/release_ci.md#qa-loop-and-release-candidates).

### Hotfix while `main` has unreleased work

```bash
git checkout -b hotfix/1.1.6 v1.1.5-rc3   # branch from the RC tag that shipped
# fix, bump version to 1.1.6, update release notes, commit
git tag v1.1.6-rc1 && git push origin v1.1.6-rc1   # then QA and promote as above
```

Then open a PR from `hotfix/1.1.6` into `main` so the fix isn't lost.

### If a release run fails

The signed `.ipa` is saved on the run page under **Artifacts** for 7 days. Upload it with
**Transporter**; it lands in TestFlight like a CI upload.
For Android, the signed `.aab` is saved the same way; upload it in Play Console → Test and release →
Internal testing → Create new release.

Signing secrets, renewal (certificate and profile expire **Oct 10, 2027**) and the full setup:
[`docs/release_ci.md`](docs/release_ci.md).
