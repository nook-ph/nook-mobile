# iOS `dev` flavor

The App Store build and a locally-built release build cannot coexist on a device
while they share a bundle identifier — the second install replaces the first.
The `dev` flavor gives the local build its own identity so both sit on the home
screen at once.

| | App Store build | `dev` build |
| --- | --- | --- |
| Bundle id | `app.nookph` | `app.nookph.dev` |
| Home screen name | Nook | Nook Dev |
| URL scheme | `ph.nook.app` | `ph.nook.app.dev` |
| Xcode scheme | `Runner` | `dev` |
| Build configurations | `Debug` / `Release` / `Profile` | `Debug-dev` / `Release-dev` / `Profile-dev` |

## Running it

```bash
flutter run --release --flavor dev --dart-define=DEEP_LINK_SCHEME=ph.nook.app.dev
```

The `--dart-define` matters: Dart has no view of the Xcode configuration, so
`AppConstants.scheme` needs telling which scheme this binary registered. Without
it the app builds and runs, but emails it sends link back to `ph.nook.app://` —
which iOS may well hand to the App Store build instead.

Omit `--flavor` entirely to build the store identity as before.

## How it is wired

`Info.plist` no longer hardcodes the values that differ per flavor. It reads
four build settings, defined per configuration in `project.pbxproj`:

- `APP_DISPLAY_NAME` — `CFBundleDisplayName`
- `DEEP_LINK_SCHEME` — the app's own URL scheme
- `GID_CLIENT_ID` / `GID_URL_SCHEME` — Google Sign-In client and its callback scheme

The `-dev` configurations inherit everything else from their non-dev
counterparts, and each has a matching `ios/Flutter/<Config>-dev.xcconfig` so
CocoaPods can generate per-configuration pod settings (`ios/Podfile` maps the
three new configurations to the same debug/release build types).

## Known limits

**Google Sign-In does not work on the `dev` build.** Google validates an iOS
OAuth client against the bundle id that requests it, and the only client that
exists is registered to `app.nookph`. To fix it: create a second iOS OAuth
client for `app.nookph.dev` in Google Cloud, then point `GID_CLIENT_ID` and
`GID_URL_SCHEME` on the three `-dev` configurations at it. Apple Sign-In needs
the same treatment — its App ID and Services ID are bundle-id-scoped too.

**Supabase email links need the dev scheme allow-listed.** Add
`ph.nook.app.dev://login-callback` to the project's redirect URLs, otherwise
sign-up confirmation and password reset emails from the dev build dead-end.

**Signing.** `app.nookph.dev` is a new App ID. Xcode's automatic signing will
register it under team `WD8496XKN8` on first build; a free Apple ID would instead
give a provisioning profile that expires after 7 days.
