# FundFlow Mobile

FundFlow mobile client for custody, custody requests, project planning, and notifications.

The app targets Android and iOS from one Flutter codebase. It consumes the API
from the separate `FundFlow` backend repository; the browser client lives in
`fundflow-web`.

## Local development

```bash
flutter pub get
flutter run
```

## Verification

```bash
flutter analyze
flutter test
```

The application IDs are reserved as `org.smart.fundflow.mobile` for both
platforms. Release signing and Firebase configuration will be added with the
first application milestone.
