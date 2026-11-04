import 'dart:math' as math;

/// The photos the camera took and whether the live check passed before them.
class FaceCapture {
  const FaceCapture({required this.paths, required this.livenessOk})
    : problem = null;

  /// The phone has no usable camera, or the employee did not allow it.
  const FaceCapture.unavailable(this.problem)
    : paths = const [],
      livenessOk = false;

  final List<String> paths;
  final bool livenessOk;
  String? get path => paths.isEmpty ? null : paths.first;

  /// A reason in Arabic when no photo was taken.
  final String? problem;
}

/// What the face detector saw in one camera frame; only what liveness needs.
class FaceFrame {
  const FaceFrame({
    required this.faces,
    this.trackingId,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.yaw,
    this.width = 0,
  });

  /// How many faces are in the frame.
  final int faces;
  final int? trackingId;

  /// Probabilities from 0 to 1; null when the detector could not tell.
  final double? leftEyeOpen;
  final double? rightEyeOpen;

  /// Degrees the head is turned sideways; 0 faces the camera.
  final double? yaw;

  /// The face's width as a fraction of the frame's.
  final double width;
}

/// A live check the employee does in front of the camera.
enum FaceChallenge { blink, turn }

/// A photo the flow takes once the live check passed.
enum FacePose { front, side, otherSide }

/// Where the flow stands, for the screen to prompt and to shoot.
class FaceStep {
  const FaceStep(this.prompt, {this.shoot, this.done = false});

  /// What the employee is asked to do now, in Arabic.
  final String prompt;

  /// Take this photo now; null while the flow waits.
  final FacePose? shoot;
  final bool done;
}

/// Liveness on the phone (§8.1): the employee blinks and turns their head in
/// a random order while one face stays tracked, then holds each pose for its
/// photo. The phone never matches the face; the server does.
class FaceLiveness {
  FaceLiveness({required this.poses, math.Random? random})
    : _challenges = [FaceChallenge.blink, FaceChallenge.turn]
        ..shuffle(random ?? math.Random());

  /// The photos to take, in order: one for a punch, three for enrolment.
  final List<FacePose> poses;
  final List<FaceChallenge> _challenges;

  static const _closed = .3;
  static const _open = .7;
  static const _turned = 22.0;
  static const _frontal = 10.0;
  static const _sideMin = 8.0;
  static const _sideMax = 30.0;
  static const _minWidth = .25;

  int _challenge = 0;
  int _pose = 0;
  int? _trackingId;
  bool _eyesClosed = false;

  /// The side the first side photo took, so the second takes the other.
  double? _firstSide;

  bool get passed => _challenge == _challenges.length;
  bool get done => _pose == poses.length;
  List<FaceChallenge> get challenges => List.unmodifiable(_challenges);

  /// Starts over, as when the face left the frame.
  void reset() {
    _challenge = 0;
    _pose = 0;
    _trackingId = null;
    _eyesClosed = false;
    _firstSide = null;
  }

  FaceStep see(FaceFrame frame) {
    if (done) return const FaceStep('تم', done: true);
    if (frame.faces == 0) return _lost('ضع وجهك داخل الإطار');
    if (frame.faces > 1) return _lost('يجب أن يظهر وجه واحد فقط');
    // Another face took the place of the one that did the checks.
    if (_trackingId != null &&
        frame.trackingId != null &&
        frame.trackingId != _trackingId) {
      reset();
    }
    _trackingId ??= frame.trackingId;
    if (frame.width < _minWidth) {
      return FaceStep(_prompt('قرّب الهاتف من وجهك'));
    }

    if (!passed) {
      switch (_challenges[_challenge]) {
        case FaceChallenge.blink:
          final left = frame.leftEyeOpen;
          final right = frame.rightEyeOpen;
          if (left != null && right != null) {
            if (left < _closed && right < _closed) _eyesClosed = true;
            if (_eyesClosed && left > _open && right > _open) _next();
          }
        case FaceChallenge.turn:
          if ((frame.yaw ?? 0).abs() > _turned) _next();
      }
      return FaceStep(_prompt(null));
    }

    final yaw = frame.yaw ?? 0;
    final eyesOpen =
        (frame.leftEyeOpen ?? 1) > _open && (frame.rightEyeOpen ?? 1) > _open;
    final pose = poses[_pose];
    final ready = switch (pose) {
      FacePose.front => yaw.abs() < _frontal && eyesOpen,
      FacePose.side => yaw.abs() >= _sideMin && yaw.abs() <= _sideMax,
      FacePose.otherSide =>
        yaw.abs() >= _sideMin &&
            yaw.abs() <= _sideMax &&
            (_firstSide == null || yaw.sign != _firstSide!.sign),
    };
    if (!ready) return FaceStep(_prompt(null));
    if (pose == FacePose.side) _firstSide = yaw;
    return FaceStep(_prompt(null), shoot: pose);
  }

  /// The photo for [pose] was taken; move to the next one.
  void shot(FacePose pose) {
    if (!done && poses[_pose] == pose) _pose++;
  }

  void _next() {
    _challenge++;
    _eyesClosed = false;
  }

  FaceStep _lost(String prompt) {
    // Checks done for one face do not carry over to the next.
    if (_challenge > 0 || _pose > 0) reset();
    return FaceStep(prompt);
  }

  String _prompt(String? override) => override ?? prompt;

  /// What the employee is asked to do next, the face in place.
  String get prompt {
    if (done) return 'تم';
    if (!passed) {
      return switch (_challenges[_challenge]) {
        FaceChallenge.blink => 'رمّش بعينيك',
        FaceChallenge.turn => 'لف رأسك إلى أحد الجانبين',
      };
    }
    return switch (poses[_pose]) {
      FacePose.front => 'انظر إلى الكاميرا مباشرة',
      FacePose.side => 'لف رأسك قليلًا إلى جانب',
      FacePose.otherSide => 'لف رأسك قليلًا إلى الجانب الآخر',
    };
  }
}
