import 'package:flutter/foundation.dart';

import '../domain/auth_gateway.dart';
import '../domain/auth_user.dart';
import '../data/biometric_auth_coordinator.dart';

enum AuthStatus { booting, unauthenticated, authenticated, failed }

class AuthController extends ChangeNotifier {
  AuthController(this._gateway, {BiometricAuthCoordinator? biometrics})
    : _biometrics = biometrics;

  final AuthGateway _gateway;
  final BiometricAuthCoordinator? _biometrics;

  AuthStatus status = AuthStatus.booting;
  AuthUser? user;
  String? errorMessage;
  bool submitting = false;
  bool mfaRequired = false;
  void Function()? onSessionEnded;
  BindingOffer? biometricOffer;

  bool get biometricLoginAvailable => _biometrics?.configured ?? false;

  String get savedTenant => _gateway.savedTenant;

  Future<void> initialize() async {
    status = AuthStatus.booting;
    errorMessage = null;
    notifyListeners();
    try {
      user = await _gateway.currentUser();
      status = user == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
    } on AuthFailure catch (error) {
      status = AuthStatus.failed;
      errorMessage = error.message;
    }
    notifyListeners();
  }

  Future<bool> login({
    required String tenant,
    required String username,
    required String password,
    String? code,
  }) async {
    if (submitting) return false;
    submitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      user = await _gateway.login(
        tenant: tenant,
        username: username,
        password: password,
        code: code,
      );
      mfaRequired = false;
      try {
        biometricOffer = await _biometrics?.offer();
      } catch (_) {
        // Binding is optional and must not strand a successful login.
        biometricOffer = null;
      }
      if (biometricOffer == null) status = AuthStatus.authenticated;
      return true;
    } on AuthFailure catch (error) {
      errorMessage = error.message;
      mfaRequired = error.mfaRequired;
      return false;
    } catch (_) {
      errorMessage = 'تعذر إتمام الدخول. حاول مرة أخرى.';
      return false;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithBiometrics() async {
    if (submitting) return false;
    final biometrics = _biometrics;
    if (biometrics == null) return false;
    submitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      user = await biometrics.login();
      if (user == null) return false;
      status = AuthStatus.authenticated;
      return true;
    } on AuthFailure catch (error) {
      errorMessage = error.message;
      mfaRequired = error.mfaRequired;
      return false;
    } catch (_) {
      errorMessage = 'تعذر إتمام الدخول. حاول مرة أخرى.';
      return false;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  /// Binds this phone: true when it waits for the manager, false when it is
  /// bound now, null when it failed ([errorMessage] says why).
  Future<bool?> bindOfferedDevice() async {
    try {
      return await _biometrics?.bind() ?? false;
    } on AuthFailure catch (error) {
      errorMessage = error.message;
      mfaRequired = error.mfaRequired;
      return null;
    } catch (_) {
      errorMessage = 'تعذر ربط الجهاز. يمكنك المتابعة بكلمة المرور.';
      return null;
    }
  }

  void completeLogin() {
    biometricOffer = null;
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  void expireSession() {
    user = null;
    biometricOffer = null;
    mfaRequired = false;
    errorMessage = null;
    submitting = false;
    status = AuthStatus.unauthenticated;
    onSessionEnded?.call();
    notifyListeners();
  }

  Future<void> logout() async {
    expireSession();
    submitting = true;
    notifyListeners();
    try {
      await _gateway.logout();
    } catch (_) {
      // The local session must end even when server revocation cannot be reached.
    } finally {
      expireSession();
    }
  }
}
