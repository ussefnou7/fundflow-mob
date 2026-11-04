# FundFlow Mobile

FundFlow mobile client for custody, custody requests, project planning, and notifications.

The app targets Android and iOS from one Flutter codebase. It consumes the API
from the separate `FundFlow` backend repository; the browser client lives in
`fundflow-web`.

## Local development

The debug app currently targets the local backend at
`http://192.168.1.28:8080`, the development computer's Wi-Fi address. Keep the
phone and computer on the same network and start Spring Boot on port `8080`.
Override the URL when the Wi-Fi address changes or when using an emulator:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://192.168.1.28:8080
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

The application IDs are reserved as `org.smart.fundflow.mobile` for both
platforms. Release signing and Firebase configuration will be added with the
first application milestone.
