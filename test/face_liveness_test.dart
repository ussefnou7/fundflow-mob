import 'dart:math' as math;

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

/// A punch flow whose action is [challenge].
FaceLiveness _punch(FaceChallenge challenge) {
  for (var seed = 0; ; seed++) {
    final liveness = FaceLiveness(
      poses: const [FacePose.front],
      random: math.Random(seed),
    );
    if (liveness.challenge == challenge) return liveness;
  }
}

/// Holds [frame]'s pose from [from] long enough to be photographed.
FacePose? _hold(FaceLiveness liveness, int from, {double yaw = 0}) {
  FacePose? shoot;
  for (var ms = from; ms <= from + 600 && shoot == null; ms += 100) {
    shoot = liveness.see(_face(ms, yaw: yaw)).shoot;
  }
  return shoot;
}

void main() {
  test('a punch asks for one action drawn at random', () {
    final drawn = {
      for (var seed = 0; seed < 40; seed++)
        FaceLiveness(
          poses: const [FacePose.front],
          random: math.Random(seed),
        ).challenge,
    };
    expect(drawn, FaceChallenge.values.toSet());
    // Enrolment has no action of its own: turning to each side is the proof.
    expect(
      FaceLiveness(
        poses: const [FacePose.front, FacePose.right, FacePose.left],
      ).challenge,
      isNull,
    );
  });

  test('a blink, then the face held to the front, takes the photo', () {
    final liveness = _punch(FaceChallenge.blink);
    expect(liveness.see(_face(0)).prompt, 'رمّش بعينيك');
    // Open eyes alone never count as a blink.
    for (var ms = 100; ms < 1000; ms += 100) {
      expect(liveness.see(_face(ms)).shoot, isNull);
    }
    expect(liveness.passed, isFalse);
    liveness.see(_face(1000, eyes: .05));
    final step = liveness.see(_face(1100));
    expect(liveness.passed, isTrue);
    expect(step.prompt, 'انظر إلى الكاميرا مباشرة');
    // Not on the first frame: the pose has to hold half a second.
    expect(liveness.see(_face(1200)).shoot, isNull);
    expect(liveness.see(_face(1500)).shoot, isNull);
    expect(liveness.see(_face(1700)).shoot, FacePose.front);
    liveness.shot(FacePose.front);
    expect(liveness.done, isTrue);
  });

  test('a turn counts only toward the side asked for', () {
    final liveness = _punch(FaceChallenge.turnRight);
    expect(liveness.see(_face(0)).prompt, 'لف وجهك ناحية اليمين');
    liveness.see(_face(100, yaw: -_right * 30));
    expect(liveness.passed, isFalse);
    liveness.see(_face(200, yaw: _right * 30));
    expect(liveness.passed, isTrue);
    // Still turned: no photo until the face comes back to the front.
    expect(_hold(liveness, 300, yaw: _right * 30), isNull);
    expect(_hold(liveness, 1000), FacePose.front);
  });

  test('another face before the photo asks for the action again', () {
    final liveness = _punch(FaceChallenge.turnLeft);
    liveness.see(_face(0, yaw: -_right * 30));
    expect(liveness.passed, isTrue);
    liveness.see(_face(100, id: 2));
    expect(liveness.passed, isFalse);

    liveness.see(_face(200, id: 2, yaw: -_right * 30));
    expect(liveness.passed, isTrue);
    // Out of view long enough to swap faces: the action again.
    liveness.see(_none(300));
    liveness.see(_none(700));
    liveness.see(_face(800, id: 2));
    expect(liveness.passed, isFalse);
  });

  test('a dropped frame does not undo the punch action', () {
    final liveness = _punch(FaceChallenge.turnRight);
    liveness.see(_face(0, yaw: _right * 30));
    liveness.see(_none(100));
    liveness.see(_face(200));
    expect(liveness.passed, isTrue);
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
