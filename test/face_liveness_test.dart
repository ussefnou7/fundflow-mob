import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/features/hr/application/face_liveness.dart';

/// The employee's own right, in ML Kit's yaw on the front camera.
const _right = FaceLiveness.rightYaw;

FaceFrame _face(
  int ms, {
  double yaw = 0,
  double eyes = .95,
  int id = 1,
  double width = .4,
  double x = .5,
}) => FaceFrame(
  faces: 1,
  trackingId: id,
  leftEyeOpen: eyes,
  rightEyeOpen: eyes,
  yaw: yaw,
  width: width,
  centerX: x,
  at: Duration(milliseconds: ms),
);

FaceFrame _none(int ms) => FaceFrame(faces: 0, at: Duration(milliseconds: ms));

/// A punch whose server action is a turn to the employee's [right] or left.
FaceLiveness _punch({bool right = true}) => FaceLiveness(
  poses: [right ? FacePose.right : FacePose.left, FacePose.front],
  strict: true,
);

/// Holds [frame]'s pose from [from] long enough to be photographed.
FacePose? _hold(FaceLiveness liveness, int from, {double yaw = 0}) {
  FacePose? shoot;
  for (var ms = from; ms <= from + 600 && shoot == null; ms += 100) {
    shoot = liveness.see(_face(ms, yaw: yaw)).shoot;
  }
  return shoot;
}

void main() {
  test('the action the server drew is the first photo, the front the next', () {
    expect(poseFor('TURN_RIGHT'), FacePose.right);
    expect(poseFor('TURN_LEFT'), FacePose.left);
    final liveness = _punch();
    expect(liveness.prompt, 'لف وجهك قليلًا ناحية اليمين');
    // The other side is not the action.
    expect(_hold(liveness, 0, yaw: -_right * 25), isNull);
    expect(_hold(liveness, 1000, yaw: _right * 25), FacePose.right);
    liveness.shot(FacePose.right);
    expect(
      liveness.see(_face(2000, yaw: _right * 25)).prompt,
      'انظر إلى الكاميرا مباشرة',
    );
    // Not on the first frame: the pose has to hold half a second.
    expect(liveness.see(_face(2800)).shoot, isNull);
    expect(liveness.see(_face(3100)).shoot, isNull);
    expect(liveness.see(_face(3300)).shoot, FacePose.front);
    liveness.shot(FacePose.front);
    expect(liveness.done, isTrue);
  });

  test('another face before the front photo starts the punch over', () {
    final liveness = _punch(right: false);
    expect(_hold(liveness, 0, yaw: -_right * 25), FacePose.left);
    liveness.shot(FacePose.left);
    expect(liveness.taken, 1);
    liveness.see(_face(1000, id: 2));
    expect(liveness.taken, 0);
    expect(liveness.prompt, 'لف وجهك قليلًا ناحية الشمال');
  });

  test('a punch face out of view for more than a moment starts over', () {
    final liveness = _punch();
    expect(_hold(liveness, 0, yaw: _right * 25), FacePose.right);
    liveness.shot(FacePose.right);
    // A dropped frame is nothing.
    liveness.see(_none(1000));
    liveness.see(_face(1100));
    expect(liveness.taken, 1);
    // Long enough to swap faces is.
    liveness.see(_none(1200));
    liveness.see(_none(1600));
    liveness.see(_face(1700));
    expect(liveness.taken, 0);
  });

  test('enrolment takes the front, then the right, then the left', () {
    final liveness = FaceLiveness(
      poses: const [FacePose.front, FacePose.right, FacePose.left],
    );
    expect(liveness.prompt, 'انظر إلى الكاميرا مباشرة');
    // Already facing the camera: told to hold still, not told again to look.
    expect(liveness.see(_face(0)).prompt, 'اثبت هكذا…');
    expect(_hold(liveness, 100), FacePose.front);
    liveness.shot(FacePose.front);
    expect(liveness.taken, 1);

    expect(liveness.see(_face(1000)).prompt, 'لف وجهك قليلًا ناحية اليمين');
    // The left is not the right, and too far a turn is no photo either.
    expect(_hold(liveness, 1100, yaw: -_right * 25), isNull);
    expect(_hold(liveness, 2000, yaw: _right * 60), isNull);
    expect(_hold(liveness, 3000, yaw: _right * 25), FacePose.right);
    liveness.shot(FacePose.right);

    expect(liveness.see(_face(4000)).prompt, 'لف وجهك قليلًا ناحية الشمال');
    expect(_hold(liveness, 4100, yaw: -_right * 25), FacePose.left);
    liveness.shot(FacePose.left);
    expect(liveness.done, isTrue);
  });

  test('losing the face in enrolment keeps the photos already taken', () {
    final liveness = FaceLiveness(
      poses: const [FacePose.front, FacePose.right, FacePose.left],
    );
    expect(_hold(liveness, 0), FacePose.front);
    liveness.shot(FacePose.front);
    liveness.see(_none(1000));
    liveness.see(_none(3000));
    expect(liveness.taken, 1);
    expect(_hold(liveness, 3100, yaw: _right * 25), FacePose.right);
  });

  test('a moving face restarts the hold, not the pose', () {
    final liveness = FaceLiveness(
      poses: const [FacePose.front, FacePose.right, FacePose.left],
    );
    liveness.see(_face(0));
    liveness.see(_face(300));
    // Off centre for a moment: the half second starts again.
    liveness.see(_face(400, x: .8));
    expect(liveness.see(_face(500)).shoot, isNull);
    expect(liveness.see(_face(800)).shoot, isNull);
    expect(liveness.see(_face(1000)).shoot, FacePose.front);
  });

  test('a prompt stays long enough to be read', () {
    final liveness = FaceLiveness(
      poses: const [FacePose.front, FacePose.right, FacePose.left],
    );
    expect(liveness.see(_face(0, yaw: 25)).prompt, 'انظر إلى الكاميرا مباشرة');
    // A frame too far away right after does not replace it yet.
    expect(
      liveness.see(_face(100, width: .1)).prompt,
      'انظر إلى الكاميرا مباشرة',
    );
    expect(liveness.see(_face(800, width: .1)).prompt, 'قرّب الهاتف من وجهك');
  });

  test('the frame turns green only for a centred face of a good size', () {
    final liveness = FaceLiveness(
      poses: const [FacePose.front, FacePose.right, FacePose.left],
    );
    expect(liveness.see(_face(0)).aligned, isTrue);
    expect(liveness.see(_face(100, x: .8)).aligned, isFalse);
    expect(liveness.see(_face(200, width: .9)).aligned, isFalse);
  });

  test('a photo that misses its pose is retaken on the spot', () {
    expect(FaceLiveness.problemWith(FacePose.front, _face(0)), isNull);
    expect(
      FaceLiveness.problemWith(FacePose.front, _none(0)),
      'الصورة غير واضحة؛ ثبّت الهاتف ووجهك',
    );
    expect(
      FaceLiveness.problemWith(FacePose.front, _face(0, eyes: .1)),
      isNotNull,
    );
    expect(
      FaceLiveness.problemWith(FacePose.right, _face(0, yaw: _right * 25)),
      isNull,
    );
    expect(
      FaceLiveness.problemWith(FacePose.right, _face(0, yaw: -_right * 25)),
      isNotNull,
    );
    expect(
      FaceLiveness.problemWith(FacePose.left, _face(0, width: .1)),
      'الوجه صغير في الصورة؛ قرّب الهاتف',
    );

    final liveness = FaceLiveness(
      poses: const [FacePose.front, FacePose.right, FacePose.left],
    );
    expect(_hold(liveness, 0), FacePose.front);
    liveness.retake();
    expect(liveness.taken, 0);
    expect(_hold(liveness, 1000), FacePose.front);
  });
}
