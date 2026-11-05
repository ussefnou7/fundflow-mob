/// The photos the camera took, one per pose, and whether the live check
/// passed before them.
class FaceCapture {
  const FaceCapture({
    required this.paths,
    required this.livenessOk,
    this.poses = const [],
  }) : problem = null;

  /// The phone has no usable camera, or the employee did not allow it.
  const FaceCapture.unavailable(this.problem)
    : paths = const [],
      poses = const [],
      livenessOk = false;

  final List<String> paths;
  final bool livenessOk;

  /// The pose of each photo in [paths], in the same order.
  final List<FacePose> poses;

  /// The photo of [pose], or null when none was taken.
  String? of(FacePose pose) {
    final index = poses.indexOf(pose);
    return index < 0 || index >= paths.length ? null : paths[index];
  }

  /// The front photo, matched against the employee's face.
  String? get path =>
      of(FacePose.front) ?? (paths.isEmpty ? null : paths.first);

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
    this.centerX = .5,
    this.centerY = .5,
    this.at = Duration.zero,
  });

  /// How many faces are in the frame.
  final int faces;
  final int? trackingId;

  /// Probabilities from 0 to 1; null when the detector could not tell.
  final double? leftEyeOpen;
  final double? rightEyeOpen;

  /// Degrees the head is turned sideways, as ML Kit reports it on the front
  /// camera's frames; 0 faces the camera. See [FaceLiveness.rightYaw].
  final double? yaw;

  /// The face's width as a fraction of the upright frame's width.
  final double width;

  /// The face's centre as fractions of the upright frame, 0 to 1.
  final double centerX;
  final double centerY;

  /// When the frame came, from the start of the capture.
  final Duration at;
}

/// A photo the flow takes: for a punch, the head turned the way the server
/// asked, then the front; for enrolment the front, the right and the left.
enum FacePose { front, right, left }

/// The pose that answers the server's challenge (`TURN_RIGHT`, `TURN_LEFT`).
FacePose poseFor(String action) =>
    action == 'TURN_RIGHT' ? FacePose.right : FacePose.left;

/// Where the flow stands, for the screen to prompt and to shoot.
class FaceStep {
  const FaceStep(
    this.prompt, {
    this.shoot,
    this.done = false,
    this.aligned = false,
  });

  /// What the employee is asked to do now, in Arabic.
  final String prompt;

  /// Take this photo now; null while the flow waits.
  final FacePose? shoot;
  final bool done;

  /// The face sits inside the frame at a good size: the frame turns green.
  final bool aligned;
}

/// The camera side of the live check (§8.1), one step at a time so every
/// prompt can be read and followed. The server draws a punch's action and
/// checks its photo; the phone only makes sure it gets the right photos:
///
/// * A punch photographs the head turned the way the server asked, then the
///   front. It is [strict]: if the face leaves the frame for more than a
///   moment, or another face appears, it starts over from the first photo.
/// * Enrolment takes the front, then the right, then the left. A face leaving
///   the frame for a moment only restarts the pose in hand, as the server
///   checks that every photo is the same person.
/// * A photo is taken only once its pose has held for [hold] inside the frame,
///   and a prompt stays at least [promptFor] before another replaces it.
///
/// The phone never matches the face; the server does.
class FaceLiveness {
  FaceLiveness({required this.poses, this.strict = false});

  /// The sign of [FaceFrame.yaw] when the employee turns to their own right.
  /// ML Kit's yaw is positive toward the right of the processed image, and the
  /// front camera's frames are not mirrored, so the employee's right is
  /// negative. Flip this if a device ever reads the other way.
  static const rightYaw = -1.0;

  static const hold = Duration(milliseconds: 500);
  static const promptFor = Duration(milliseconds: 700);

  /// How long the face may be out of view before a [strict] capture starts
  /// over: long enough for a dropped frame, too short to swap faces.
  static const _punchGap = Duration(milliseconds: 300);

  static const _open = .7;
  static const _frontal = 10.0;
  static const _sideMin = 15.0;
  static const _sideMax = 40.0;
  static const _minWidth = .25;
  static const _maxWidth = .8;
  static const _offCentre = .15;

  /// The photos to take, in order: two for a punch, three for enrolment.
  final List<FacePose> poses;

  /// Every photo from one face in one go (a punch).
  final bool strict;

  int _pose = 0;
  int? _trackingId;
  Duration? _readySince;
  Duration? _lostSince;
  String? _shown;
  Duration _shownAt = Duration.zero;

  bool get done => _pose == poses.length;

  /// Photos taken so far.
  int get taken => _pose;

  /// The pose in hand, or null once all are taken.
  FacePose? get pose => done ? null : poses[_pose];

  /// Starts over, as after a failed attempt.
  void reset() {
    _pose = 0;
    _trackingId = null;
    _readySince = null;
    _lostSince = null;
    _shown = null;
  }

  FaceStep see(FaceFrame frame) {
    if (done) return const FaceStep('تم', done: true);
    if (frame.faces != 1) {
      _readySince = null;
      if (frame.faces > 1) {
        _startOver();
        return FaceStep(_say('يجب أن يظهر وجه واحد فقط', frame.at));
      }
      _lostSince ??= frame.at;
      if (frame.at - _lostSince! > _punchGap) _startOver();
      return FaceStep(_say('ضع وجهك داخل الإطار', frame.at));
    }
    _lostSince = null;
    // Another face took the place of the one already photographed.
    if (_trackingId != null &&
        frame.trackingId != null &&
        frame.trackingId != _trackingId) {
      _startOver();
      _readySince = null;
    }
    if (frame.trackingId != null) _trackingId = frame.trackingId;

    if (frame.width < _minWidth) {
      _readySince = null;
      return FaceStep(_say('قرّب الهاتف من وجهك', frame.at));
    }

    final aligned = _aligned(frame);
    if (!aligned) {
      _readySince = null;
      final where = frame.width > _maxWidth
          ? 'أبعد الهاتف قليلًا'
          : 'اجعل وجهك داخل الإطار';
      return FaceStep(_say(where, frame.at));
    }
    if (!_inPose(poses[_pose], frame)) {
      _readySince = null;
      return FaceStep(_say(prompt, frame.at), aligned: true);
    }
    _readySince ??= frame.at;
    if (frame.at - _readySince! < hold) {
      return FaceStep(_say('اثبت هكذا…', frame.at), aligned: true);
    }
    _readySince = null;
    return FaceStep(
      _say('اثبت هكذا…', frame.at),
      aligned: true,
      shoot: poses[_pose],
    );
  }

  /// The photo for [pose] was taken and looked right; move to the next one.
  void shot(FacePose pose) {
    if (!done && poses[_pose] == pose) {
      _pose++;
      _readySince = null;
      _shown = null;
    }
  }

  /// The photo for the pose in hand was not clear: the same pose again.
  void retake() {
    _readySince = null;
    _shown = null;
  }

  /// What the employee is asked to do next, the face in place.
  String get prompt {
    if (done) return 'تم';
    return switch (poses[_pose]) {
      FacePose.front => 'انظر إلى الكاميرا مباشرة',
      FacePose.right => 'لف وجهك قليلًا ناحية اليمين',
      FacePose.left => 'لف وجهك قليلًا ناحية الشمال',
    };
  }

  /// Why a photo taken for [pose] will not do, as the detector reads the still
  /// itself; null when it is fine. Checked before moving on, so a blurred or
  /// half-turned photo is retaken at once rather than refused by the server
  /// after the last one.
  static String? problemWith(FacePose pose, FaceFrame still) {
    if (still.faces == 0) return 'الصورة غير واضحة؛ ثبّت الهاتف ووجهك';
    if (still.faces > 1) return 'ظهر أكثر من وجه في الصورة';
    if (still.width < .2) return 'الوجه صغير في الصورة؛ قرّب الهاتف';
    final yaw = still.yaw ?? 0;
    final fits = switch (pose) {
      FacePose.front =>
        yaw.abs() < 15 &&
            (still.leftEyeOpen ?? 1) > .5 &&
            (still.rightEyeOpen ?? 1) > .5,
      FacePose.right => _towards(yaw, rightYaw, 10, 45),
      FacePose.left => _towards(yaw, -rightYaw, 10, 45),
    };
    return fits ? null : 'الصورة لم تلتقط الوضعية المطلوبة؛ أعدها';
  }

  static bool _inPose(FacePose pose, FaceFrame frame) {
    final yaw = frame.yaw ?? 0;
    return switch (pose) {
      FacePose.front =>
        yaw.abs() < _frontal &&
            (frame.leftEyeOpen ?? 1) > _open &&
            (frame.rightEyeOpen ?? 1) > _open,
      FacePose.right => _towards(yaw, rightYaw, _sideMin, _sideMax),
      FacePose.left => _towards(yaw, -rightYaw, _sideMin, _sideMax),
    };
  }

  static bool _towards(double yaw, double sign, double min, double max) {
    final turned = yaw * sign;
    return turned >= min && turned <= max;
  }

  static bool _aligned(FaceFrame frame) =>
      frame.width <= _maxWidth &&
      (frame.centerX - .5).abs() <= _offCentre &&
      (frame.centerY - .5).abs() <= _offCentre;

  /// A strict capture keeps only photos of one face taken in one go.
  void _startOver() {
    if (!strict || _pose == 0) return;
    _pose = 0;
    _readySince = null;
    _shown = null;
  }

  /// [text] once the current prompt has stood [promptFor], or at once when the
  /// flow moved on ([now]), so prompts never flicker frame by frame.
  String _say(String text, Duration at, {bool now = false}) {
    if (_shown == null || now || text == _shown || at - _shownAt >= promptFor) {
      if (text != _shown) _shownAt = at;
      _shown = text;
    }
    return _shown!;
  }
}
