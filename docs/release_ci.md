# Release CI: plan

Status: **proposed, not built.** Today every iOS release is built, signed and uploaded by hand on
a teammate's Mac, and the Android release is built by hand too. This doc records the options and
the recommended setup, so the work can be picked up without redoing the research.

Built so far: `.github/workflows/ios-build.yml` runs an unsigned iOS release build
(`flutter build ios --release --no-codesign`) on every pull request and every push to `main`. It
uses no secrets and uploads nothing; it only catches iOS build breaks.

`.github/workflows/ios-release.yml` builds an App Store-signed `.ipa` on a `v*` tag or by hand
(Actions → iOS release IPA → Run workflow), using the exported-certificate route below, and keeps
the `.ipa` as a run artifact for 7 days, then uploads it to App Store Connect with `xcrun altool`.
It needs the `IOS_*`, `ASC_*` and `.env` secrets. Choosing the build for a version and submitting
for review stay manual. The project itself still signs
automatically; CI switches the Runner target to manual signing only for its own build.

## Goal

Tag a release (for example `v1.1.4`) and get:

- an iOS build on **TestFlight**, and
- an Android build on the **Play internal track**,

without anyone building on their own machine. Promoting to the public App Store and Play Store
stays a manual click: Apple's review has to happen anyway, and a person should decide when a
build goes out.

```
git tag v1.1.4 && git push --tags
  └─ GitHub Actions
       ├─ macOS runner:  flutter build ipa ─▶ upload ─▶ TestFlight ─▶ (manual) Submit for Review
       └─ Linux runner:  flutter build appbundle ─▶ Play internal track ─▶ (manual) promote
```

## Where the iOS build runs

iOS builds need macOS. There are two choices.

### Option A: GitHub-hosted macOS runner (recommended)

GitHub's own Macs, started fresh for every job.

- **Free**: `nook-ph/nook-mobile` is a public repo, and standard GitHub-hosted runners cost nothing
  for public repos.
- Doesn't depend on anyone's Mac being on, never slows a teammate down, and runs no code on
  personal hardware.
- Costs one extra setup step: signing has to be handed to CI (see [Signing](#ios-signing)).

### Option B: self-hosted runner on the team's Mac

The Mac registers as a runner (GitHub → Settings → Actions → Runners → New self-hosted runner →
macOS, then `./svc.sh install && ./svc.sh start`). It reuses the Xcode signing setup that already
works there.

The catches:

- **The Mac must be on, awake, logged in and online.** A MacBook sleeps with its lid closed
  unless it's on power with an external display (or kept awake with Amphetamine or `caffeinate`).
  A job queued while the Mac is asleep waits up to 24 hours, then GitHub cancels it.
- **It shares the machine.** A release build pegs the CPU for about 5–15 minutes. The runner
  works in its own folder (`actions-runner/_work/`) and doesn't touch the teammate's checkout,
  but it uses the same Flutter, Xcode and CocoaPods, so upgrading them upgrades CI too.
- **Keychain.** Run as a background service, the runner sometimes can't read the login keychain,
  and signing fails with `errSecInternalComponent`. Run it from a logged-in Terminal with
  `./run.sh`, or give it its own keychain. The first signing may also ask to allow keychain access
  once ("Always Allow").
- **Security: the repo is public.** GitHub advises against self-hosted runners on public repos,
  because a fork's pull request could run code on the machine. If this option is used, the
  workflow must trigger only on tags, `push` to `main` or `workflow_dispatch`, **never on
  `pull_request`**, and Settings → Actions → General → "Require approval for all outside
  collaborators" must be on. Making the repo private removes this risk.

## iOS signing

Needed for option A. Set it up once, from the Mac that releases today.

1. **App Store Connect API key.** App Store Connect → Users and Access → Integrations → App Store
   Connect API → generate a key with the **App Manager** role. Download the `.p8` (only possible
   once) and note the **Key ID** and **Issuer ID**.
2. **Signing identity.** Pick one:
   - *Automatic signing with the API key*: `xcodebuild` with `-allowProvisioningUpdates` and the
     `-authenticationKey*` flags lets Xcode create and fetch the certificate and profile itself.
     Less to maintain.
   - *Exported certificate*: export the Apple Distribution certificate from Keychain Access as a
     `.p12` with a password, plus the App Store provisioning profile for `app.nookph`. CI imports
     both into a temporary keychain. More predictable, but the certificate expires yearly.
3. **GitHub Secrets** (repo → Settings → Secrets and variables → Actions):

   | Secret | Value |
   |---|---|
   | `ASC_KEY_ID`, `ASC_ISSUER_ID` | from step 1 |
   | `ASC_PRIVATE_KEY` | contents of the `.p8` |
   | `IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD`, `IOS_PROFILE_BASE64` | only for the exported-certificate route |
   | `SUPABASE_URL`, `SUPABASE_KEY`, `POSTHOG_PROJECT_TOKEN`, `POSTHOG_HOST`, `UPLOAD_PRESIGN_URL` | the release `.env` values; CI writes `.env` from them |

## Build numbers

Apple and Google reject an upload whose build number was already used. CI sets it from the run
number, offset past the last manual build (`1.1.3+12`):

```bash
flutter build ipa --release --build-number=$((100 + GITHUB_RUN_NUMBER)) \
  --export-options-plist=ios/ExportOptions.plist
xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
```

The version name still comes from `pubspec.yaml`, so bump it before tagging.

## Android

Doesn't need a Mac; a GitHub-hosted Linux runner does it.

- Secrets: the upload keystore (`.jks` as base64), its passwords and alias, and a Google Play
  **service account** JSON with release permissions on the app (Play Console → Users and
  permissions).
- Build `flutter build appbundle --release --build-number=…` and upload to the **internal** track
  with an action such as `r0adkll/upload-google-play` or fastlane `supply`.
- The upload key was reset in 2026; Google's app signing key holds the real signature, so CI only
  needs the upload key.

## Triggers

| Trigger | Does |
|---|---|
| `push` tag `v*` | builds and uploads iOS to TestFlight and Android to Play internal |
| `workflow_dispatch` | same, by hand, for re-runs |
| `pull_request` | (optional, GitHub-hosted only) unsigned build check, no secrets |

Building on every push to `main` was considered and rejected: it fills TestFlight with builds
nobody tests and burns build numbers.

## Next steps

1. Someone with the releasing Mac creates the API key and (if chosen) exports the certificate.
2. Add the secrets.
3. Add `.github/workflows/release.yml` and `ios/ExportOptions.plist`, then tag a test release and
   confirm it lands in TestFlight and on Play internal.
