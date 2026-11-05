import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/device/installation_id.dart';
import '../presentation/face_capture_screen.dart';
import 'face_liveness.dart';

/// Where the phone is when punching, or why it could not tell.
class PunchFix {
  const PunchFix({
    this.lat,
    this.lng,
    this.accuracyM,
    this.mocked = false,
    this.problem,
  });

  final double? lat;
  final double? lng;
  final int? accuracyM;

  /// The phone reported a simulated location (Android only).
  final bool mocked;

  /// A reason in Arabic when there are no coordinates.
  final String? problem;

  bool get located => lat != null && lng != null;
}

/// The phone-side facts a punch carries; behind an interface so tests fake
/// them. Who punches is the signed-in account; whether this phone is theirs
/// is the server's call, by [installationId].
abstract class PunchSensors {
  String get installationId;
  Future<PunchFix> locate();

  /// The live check and its photos: for a punch the server's [action]
  /// (`TURN_RIGHT`, `TURN_LEFT`) then the front, three to enrol. Null when the
  /// employee closed the camera.
  Future<FaceCapture?> captureFace(
    BuildContext context, {
    bool enrol = false,
    String? action,
  });
}

class DevicePunchSensors implements PunchSensors {
  DevicePunchSensors(this._prefs);
  final SharedPreferences _prefs;

  @override
  String get installationId => installationIdOf(_prefs);

  @override
  Future<FaceCapture?> captureFace(
    BuildContext context, {
    bool enrol = false,
    String? action,
  }) => FaceCaptureScreen.open(
    context,
    poses: enrol
        ? const [FacePose.front, FacePose.right, FacePose.left]
        : [if (action != null) poseFor(action), FacePose.front],
  );

  @override
  Future<PunchFix> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const PunchFix(problem: 'خدمة الموقع مغلقة على الجهاز');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const PunchFix(problem: 'لم يُسمح للتطبيق باستخدام الموقع');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return PunchFix(
        lat: position.latitude,
        lng: position.longitude,
        accuracyM: position.accuracy.round(),
        mocked: Platform.isAndroid && position.isMocked,
      );
    } catch (_) {
      return const PunchFix(problem: 'تعذّر تحديد الموقع، حاول مرة أخرى');
    }
  }
}
