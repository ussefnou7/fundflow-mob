# Monetizer Mobile (fundflow-mob)

Mobile client for custody, treasury, contractor extracts, purchasing and
warehouses, inspections and meetings, approvals, and notifications.

HR is kept out of this app for now: its code waits in `parked/hr` and nothing
of it ships in the Android or iOS build. See `parked/hr/README.md` to bring it
back.

The app targets Android and iOS from one Flutter codebase. It consumes the API
from the separate `FundFlow` backend repository; the browser client lives in
`fundflow-web`.

## Local development

The debug app currently targets the backend computer directly over the local
Wi-Fi network at `http://10.1.1.210:8080` (the laptop's `wlp3s0` address;
not `virbr0`, which a phone cannot reach). Keep the phone and computer on
the same network, then run normally without USB port forwarding:

```bash
flutter pub get
flutter run
```

If the computer's LAN address changes, pass the new address explicitly. For the
standard Android emulator, use its host alias:

```bash
flutter run --dart-define=API_BASE_URL=http://LAN_IP:8080
# Android emulator:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

The first milestones include the Arabic login flow, persisted session cookies,
CSRF protection, tenant-code memory, and logout, followed by the custody
dashboard, personal and aggregate custody tables, custody requests, and custody
transfers. Visual tokens come directly from the current web client: bundled
Cairo font, all nine tenant color themes, shared spacing and status colors, and
Lucide icons.

The custody and aggregate screens preserve the current web table columns in a
horizontally scrollable mobile table. Offline-first synchronization and
single-device biometric login with an administrative reset are planned next.

## Verification

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Store builds

The application ID is `com.monetizer.app` on both platforms. Release builds
talk to the production API (`AppConfig.productionUrl`) unless
`API_BASE_URL` is given. The privacy and support links the stores require
open the web app (`AppConfig.webBaseUrl`, https://fundflow-stg.up.railway.app)
unless `WEB_BASE_URL` is given. The iOS build is iPhone-only.
Android release blocks screenshots (`FLAG_SECURE`); take store screenshots
from a debug build. Android release
also needs `android/key.properties` (never committed). Raise the build number
after `+` in `pubspec.yaml` for every upload.

Create the Play upload key once with `scripts/create-upload-key.sh` (it asks
for the password and writes the git-ignored `android/key.properties`; back up
the `.jks` and the password).

```bash
# Google Play
flutter build appbundle --release
# App Store (on a Mac with Xcode, then upload from Xcode or Transporter)
flutter build ipa --release
```

### iOS builds on Codemagic (no Mac needed)

`codemagic.yaml` builds the iOS release, signs it and uploads it to
TestFlight. One-time setup:

1. On developer.apple.com, register the App ID `com.monetizer.app` with Push
   Notifications. In App Store Connect, create the app with that bundle ID.
2. In App Store Connect → Users and Access → Integrations, create an API key
   with the App Manager role and download the `.p8` (it downloads only once).
3. In Codemagic, connect the GitHub repo. Under Team integrations → Developer
   Portal, add the key (issuer ID, key ID, `.p8`) and name it `monetizer_asc`.
4. The API and web addresses and the app's Apple ID (`6839345338`) are in
   `codemagic.yaml`; no environment variables are needed.
5. Start `iOS release → TestFlight` by hand, or push a tag such as `v1.0.0`.

The build number is set automatically to one above the latest TestFlight
build; the version name comes from `pubspec.yaml`.
