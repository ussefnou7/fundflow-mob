import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/features/hr/application/face_liveness.dart';

const _open = FaceFrame(
  faces: 1,
  trackingId: 1,
  leftEyeOpen: .95,
  rightEyeOpen: .95,
  yaw: 0,
  width: .4,
);
const _closed = FaceFrame(
  faces: 1,
  trackingId: 1,
  leftEyeOpen: .05,
  rightEyeOpen: .05,
  yaw: 0,
  width: .4,
);

FaceFrame _turned(double yaw, {int id = 1}) => FaceFrame(
  faces: 1,
  trackingId: id,
  leftEyeOpen: .9,
  rightEyeOpen: .9,
  yaw: yaw,
  width: .4,
);

/// Runs the challenges in whatever order the flow drew them.
void _pass(FaceLiveness liveness) {
  for (final challenge in liveness.challenges) {
    switch (challenge) {
      case FaceChallenge.blink:
        liveness.see(_closed);
        liveness.see(_open);
      case FaceChallenge.turn:
        liveness.see(_turned(30));
    }
  }
}

void main() {
  test('a punch shoots once both checks pass and the face looks ahead', () {
    final liveness = FaceLiveness(poses: const [FacePose.front]);
    expect(liveness.see(_open).shoot, isNull);
    _pass(liveness);
    expect(liveness.passed, isTrue);
    // Still turned from the check: wait for the frontal face.
    expect(liveness.see(_turned(25)).shoot, isNull);
    expect(liveness.see(_open).shoot, FacePose.front);
    liveness.shot(FacePose.front);
    expect(liveness.done, isTrue);
  });

  test('open eyes alone never count as a blink', () {
    final liveness = FaceLiveness(
      poses: const [FacePose.front],
      random: math.Random(1),
    );
    for (var i = 0; i < 20; i++) {
      liveness.see(_open);
    }
    expect(liveness.passed, isFalse);
  });

  test('the order of the checks is not fixed', () {
    final orders = {
      for (var seed = 0; seed < 20; seed++)
        FaceLiveness(
          poses: const [FacePose.front],
          random: math.Random(seed),
        ).challenges.first,
    };
    expect(orders, {FaceChallenge.blink, FaceChallenge.turn});
  });

  test('a second face or a lost face starts the checks over', () {
    final liveness = FaceLiveness(poses: const [FacePose.front]);
    _pass(liveness);
    expect(
      liveness.see(const FaceFrame(faces: 2)).prompt,
      'يجب أن يظهر وجه واحد فقط',
    );
    expect(liveness.passed, isFalse);

    _pass(liveness);
    // A different tracked face took over the frame.
    liveness.see(_turned(0, id: 2));
    expect(liveness.passed, isFalse);
  });

  test('a face too far away is asked closer and does not advance', () {
    final liveness = FaceLiveness(poses: const [FacePose.front]);
    final step = liveness.see(
      const FaceFrame(faces: 1, trackingId: 1, yaw: 40, width: .1),
    );
    expect(step.prompt, 'قرّب الهاتف من وجهك');
    expect(liveness.passed, isFalse);
  });

  test('enrolment takes the front and one photo on each side', () {
    final liveness = FaceLiveness(
      poses: const [FacePose.front, FacePose.side, FacePose.otherSide],
    );
    _pass(liveness);
    expect(liveness.see(_open).shoot, FacePose.front);
    liveness.shot(FacePose.front);
    expect(liveness.see(_turned(15)).shoot, FacePose.side);
    liveness.shot(FacePose.side);
    // The same side again is not the other side.
    expect(liveness.see(_turned(16)).shoot, isNull);
    expect(liveness.see(_turned(-14)).shoot, FacePose.otherSide);
    liveness.shot(FacePose.otherSide);
    expect(liveness.done, isTrue);
  });
}
