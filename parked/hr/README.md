# HR (parked)

The HR module is kept out of the mobile app for the store release: no HR
screen, notification, permission or native plugin ships in the Android or iOS
build. The code is kept here, with the same paths it had, so it can come back.

## Bringing it back

1. Move the code and tests back:
   - `parked/hr/lib/features/hr` → `lib/features/hr`
   - `parked/hr/test/*.dart` → `test/`
   - `parked/hr/test/goldens/*.png` → `test/goldens/`
2. Add the packages back to `pubspec.yaml` (listed there in a comment):
   `geolocator`, `camera`, `google_mlkit_face_detection`.
3. Add back the permissions:
   - Android `AndroidManifest.xml`: `ACCESS_FINE_LOCATION`,
     `ACCESS_COARSE_LOCATION` and `CAMERA`.
   - iOS `Info.plist`: `NSLocationWhenInUseUsageDescription`, and the face
     photo wording in `NSCameraUsageDescription`.
4. Re-wire it, using the commit that parked it as the guide:
   `lib/main.dart` (HrRepository, DevicePunchSensors),
   `WorkspaceController` (hr, punchSensors, approvals) and
   `workspace_shell.dart` (HR pages, drawer group, push routing).
   Remove the `HR_` filter in `notification_models.dart` and add the HR
   titles back.
