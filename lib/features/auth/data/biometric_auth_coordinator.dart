import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:biometric_storage/biometric_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/device/installation_id.dart';
import '../../../core/network/api_client.dart';
import '../domain/auth_gateway.dart';
import '../domain/auth_user.dart';

/// Why the app asks, after a password sign-in, to bind this phone to the
/// account. The phone and the account are bound one to one.
enum BindingReason {
  /// Neither this phone nor the account is bound.
  unbound,

  /// The account is bound to another phone; binding here replaces it.
  accountOnOtherPhone,

  /// This phone is bound to another account; binding here takes it over.
  phoneOfOtherAccount,

  /// This is the account's phone; only biometric sign-in is off here.
  renew,
}

class BindingOffer {
  const BindingOffer(this.reason);

  final BindingReason reason;
}

/// Binding this phone to the signed-in account: biometric sign-in on it, and
/// the phone attendance trusts. An employee's binding waits for their direct
/// manager; until then the phone stays as it was.
class BiometricAuthCoordinator {
  BiometricAuthCoordinator({
    required ApiClient client,
    required SharedPreferences prefs,
  }) : _client = client,
       _prefs = prefs;

  static const _configuredKey = 'fundflow.biometricConfigured';

  /// The token is stored and waits for the manager to approve the binding.
  static const _awaitingKey = 'fundflow.bindingAwaitingApproval';
  static const _storageName = 'fundflow-device-login';

  final ApiClient _client;
  final SharedPreferences _prefs;

  bool get configured => _prefs.getBool(_configuredKey) ?? false;

  /// What to ask after a password sign-in, or null when this phone is the
  /// account's and ready, or its binding already waits for approval.
  Future<BindingOffer?> offer() async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    final response = await _client.get(
      '/auth/device?installationId=${Uri.encodeQueryComponent(_installationId)}',
    );
    if (response.statusCode != 200 || response.data is! Map) return null;
    final data = Map<String, dynamic>.from(response.data as Map);
    final registered = data['registered'] == true;
    final current = data['currentDevice'] == true;
    if (current) {
      // Approved since it was asked for: the stored token is the bound one.
      if (_prefs.getBool(_awaitingKey) ?? false) {
        await _prefs.setBool(_awaitingKey, false);
        await _prefs.setBool(_configuredKey, true);
      }
      if (configured || !await _canUseBiometrics()) return null;
      return const BindingOffer(BindingReason.renew);
    }
    if (data['requested'] == true) return null;
    if (data['takenByOther'] == true) {
      return const BindingOffer(BindingReason.phoneOfOtherAccount);
    }
    return BindingOffer(
      registered ? BindingReason.accountOnOtherPhone : BindingReason.unbound,
    );
  }

  /// Asks to bind this phone. Returns true when the binding waits for the
  /// manager, false when it is in effect. Without biometrics on the phone
  /// the token is not kept: the phone is bound for attendance only.
  Future<bool> bind() async {
    final token = _randomToken();
    final biometrics = await _canUseBiometrics();
    final storage = biometrics ? await _storage() : null;
    await storage?.write(token);
    final response = await _client.postJson('/auth/device', {
      'installationId': _installationId,
      'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
      'deviceName': Platform.isIOS ? 'iPhone / iPad' : 'Android',
      'token': token,
    });
    if (response.statusCode != 200 || response.data is! Map) {
      await storage?.delete();
      throw AuthFailure(_message(response.statusCode));
    }
    final awaiting =
        Map<String, dynamic>.from(response.data as Map)['awaitingApproval'] ==
        true;
    await _prefs.setBool(_awaitingKey, awaiting && biometrics);
    await _prefs.setBool(_configuredKey, !awaiting && biometrics);
    return awaiting;
  }

  Future<bool> _canUseBiometrics() async {
    try {
      return await BiometricStorage().canAuthenticate() ==
          CanAuthenticateResponse.success;
    } catch (_) {
      return false;
    }
  }

  Future<AuthUser?> login() async {
    if (!configured) return null;
    try {
      final token = await (await _storage()).read();
      if (token == null || token.isEmpty) return null;
      await _client.clearSession();
      final response = await _client.postJson('/auth/device/login', {
        'installationId': _installationId,
        'token': token,
      });
      if (response.statusCode != 200) {
        if (response.statusCode == 401) {
          await _prefs.setBool(_configuredKey, false);
        }
        throw AuthFailure(_message(response.statusCode));
      }
      _client.clearCsrf();
      final me = await _client.get('/auth/me');
      if (me.statusCode != 200 || me.data is! Map) {
        throw AuthFailure(_message(me.statusCode));
      }
      return AuthUser.fromJson(Map<String, dynamic>.from(me.data as Map));
    } on AuthException {
      return null;
    } on BiometricStorageException {
      await _prefs.setBool(_configuredKey, false);
      return null;
    }
  }

  String get _installationId => installationIdOf(_prefs);

  Future<BiometricStorageFile> _storage() => BiometricStorage().getStorage(
    _storageName,
    options: StorageFileInitOptions(
      authenticationRequired: true,
      authenticationValidityDurationSeconds: -1,
      androidBiometricOnly: true,
      darwinBiometricOnly: true,
    ),
    promptInfo: const PromptInfo(
      androidPromptInfo: AndroidPromptInfo(
        title: 'الدخول إلى Monetizer',
        subtitle: 'استخدم بصمة الجهاز',
        negativeButton: 'إلغاء',
      ),
      iosPromptInfo: IosPromptInfo(
        saveTitle: 'فعّل الدخول بالبصمة إلى Monetizer',
        accessTitle: 'استخدم البصمة للدخول إلى Monetizer',
      ),
    ),
  );

  String _randomToken() {
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _message(int? status) => status == 401
      ? 'تم إلغاء ربط هذا الجهاز. ادخل بكلمة المرور واربطه من جديد.'
      : 'تعذر ربط الجهاز. حاول مرة أخرى.';
}
