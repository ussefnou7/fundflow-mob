import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/app/app.dart';

void main() {
  test('the Face ID prompt does not raise the privacy cover', () {
    expect(
      shouldObscureApp(AppLifecycleState.inactive, biometricPrompt: true),
      isFalse,
    );
  });

  test('the app switcher and leaving the app still cover it', () {
    expect(
      shouldObscureApp(AppLifecycleState.inactive, biometricPrompt: false),
      isTrue,
    );
    for (final state in [AppLifecycleState.hidden, AppLifecycleState.paused]) {
      expect(shouldObscureApp(state, biometricPrompt: true), isTrue);
    }
  });
}
