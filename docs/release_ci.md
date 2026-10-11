# Release CI: plan

Status: **built.** iOS and Android releases are built, signed and uploaded by GitHub Actions on a
version tag. The sections below keep the options that were weighed, plus the setup.

Built so far: `.github/workflows/ios-build.yml` runs an unsigned iOS release build
(`flutter build ios --release --no-codesign`) on every pull request and every push to `main`. It
uses no secrets and uploads nothing; it only catches iOS build breaks.

`.github/workflows/ios-release.yml` builds an App Store-signed `.ipa` on a `v*` tag or by hand
(Actions → iOS release IPA → Run workflow), using the exported-certificate route below, and keeps
the `.ipa` as a run artifact for 7 days, then uploads it to App Store Connect with `xcrun altool`.
It needs the `IOS_*`, `ASC_*` and `.env` secrets. On a release tag without a dash (`v1.1.4`, not
`v1.1.4-test`) it then runs `fastlane deliver`: creates the App Store version from `pubspec.yaml`,
sets "What's New" from `ios/metadata/en-US/release_notes.txt`, waits for Apple to process the build,
attaches it and submits for review. Update that file before every release. Apple releases it to
the App Store as soon as review approves it. The project itself still signs
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

Runs on GitHub-hosted Linux runners; no Mac involved.

`.github/workflows/android-build.yml` runs on every pull request and push to `main`, like the iOS
check: `flutter analyze` (errors only), `flutter test`, then an unsigned
`flutter build appbundle --release`. It uses no secrets. The unsigned build works because it sets
`NOOK_ALLOW_UNSIGNED_RELEASE=true`; without that (or `android/key.properties`) a release build
fails on purpose so nobody ships an unsigned bundle by accident.

`.github/workflows/android-release.yml` runs on the same `v*` tags as the iOS release, so one tag
ships both. It writes `.env` and `android/key.properties` from secrets, builds a signed `.aab`
with version code `100 + run number` (past the last manual Play upload, `1.1.3+12`), keeps it as a
run artifact for 7 days, and uploads it with
[`r0adkll/upload-google-play`](https://github.com/r0adkll/upload-google-play) to the **internal**
track, with `ios/metadata/en-US/release_notes.txt` as the "What's new" text (Play's limit is 500
characters; the run fails if the file is longer) and the R8 mapping file for deobfuscated crash
reports. Tags with or without a dash both go to internal; promoting to production is a manual
step in Play Console. A hand run (Actions → Android release AAB → Run workflow) can pick another
track (`alpha`, `beta`, `production`); `production` rolls out to everyone once Google reviews it.

Local release builds are unchanged: they still sign from `android/key.properties`.

### Android secrets

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the upload keystore: `base64 -w0 upload-keystore.jks` (on macOS: `base64 -i upload-keystore.jks`) |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` from your local `android/key.properties` |
| `ANDROID_KEY_ALIAS` | `keyAlias` (currently `upload`) |
| `ANDROID_KEY_PASSWORD` | `keyPassword` |
| `PLAY_SERVICE_ACCOUNT_JSON` | the full JSON key of the Play service account below |
| `SUPABASE_URL`, `SUPABASE_KEY`, `POSTHOG_PROJECT_TOKEN`, `POSTHOG_HOST`, `UPLOAD_PRESIGN_URL` | already added for iOS; shared |

The keystore is the **upload** key (reset in 2026). Play App Signing holds the real app signing
key, so CI never needs it.

### Play service account

1. Google Cloud Console → pick (or create) a project → **IAM & Admin → Service Accounts → Create
   service account**, for example `github-play-upload`. It needs no Cloud roles.
2. Open it → **Keys → Add key → Create new key → JSON**. The file downloads once; its whole
   contents go into `PLAY_SERVICE_ACCOUNT_JSON`. Then delete the local copy.
3. Enable the **Google Play Android Developer API** for that project (APIs & Services → Library).
4. Play Console → **Users and permissions → Invite new users** → the service account's email
   (`…@….iam.gserviceaccount.com`). Under **App permissions** add Nook (`app.nookph`) and grant
   **Release apps to testing tracks** (enough for internal/alpha/beta), plus **Release to
   production, exclude devices, and use Play App Signing** if hand runs should be able to target
   `production`. Invite the user.
5. New service accounts can take up to a day before uploads stop failing with "The caller does
   not have permission".

### Version codes

Play rejects a version code it has seen before. The last hand upload was `1.1.3+12`, so CI starts at
`101`. The iOS and Android workflows count runs separately, so the same tag gets different build
numbers on each store; that is fine, each store only compares against itself. Re-running a failed
job reuses its run number, so if the upload already succeeded, start a new run instead.

## Triggers

| Trigger | Does |
|---|---|
| `push` tag `v*` | builds and uploads iOS to TestFlight and Android to Play internal (both workflows) |
| `workflow_dispatch` | same, by hand, for re-runs |
| `pull_request` | unsigned iOS and Android build checks, no secrets |

Building on every push to `main` was considered and rejected: it fills TestFlight with builds
nobody tests and burns build numbers.

## Next steps

1. Someone with the releasing Mac creates the API key and (if chosen) exports the certificate.
2. Add the secrets.
3. Add `.github/workflows/release.yml` and `ios/ExportOptions.plist`, then tag a test release and
   confirm it lands in TestFlight and on Play internal.
