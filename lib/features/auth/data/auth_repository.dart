import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_gateway.dart';
import '../domain/auth_user.dart';

class AuthRepository implements AuthGateway {
  AuthRepository({required ApiClient client, required SharedPreferences prefs})
    : _client = client,
      _prefs = prefs;

  static const _tenantKey = 'fundflow.tenantCode';

  final ApiClient _client;
  final SharedPreferences _prefs;

  static Future<AuthRepository> create() async {
    return AuthRepository(
      client: await ApiClient.create(),
      prefs: await SharedPreferences.getInstance(),
    );
  }

  @override
  String get savedTenant => _prefs.getString(_tenantKey) ?? '';

  @override
  Future<AuthUser?> currentUser() async {
    try {
      final response = await _client.get('/auth/me');
      if (response.statusCode == 401) return null;
      if (response.statusCode != 200 || response.data is! Map) {
        throw AuthFailure(
          _messageFor(response),
          mfaRequired:
              response.data is Map && response.data['mfaRequired'] == true,
        );
      }
      return AuthUser.fromJson(Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (error) {
      throw AuthFailure(_networkMessage(error));
    } on ApiConnectionException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  @override
  Future<AuthUser> login({
    required String tenant,
    required String username,
    required String password,
    String? code,
  }) async {
    final cleanTenant = tenant.trim().toUpperCase();
    final values = <String, String>{
      'tenant': cleanTenant,
      'username': username.trim(),
      'password': password,
      if (code != null && code.isNotEmpty) 'code': code.trim(),
    };
    try {
      final response = await _client.postForm('/auth/login', values);
      if (response.statusCode != 200) {
        throw AuthFailure(
          _messageFor(response),
          mfaRequired:
              response.data is Map && response.data['mfaRequired'] == true,
        );
      }
      _client.clearCsrf();
      final me = await _client.get('/auth/me');
      if (me.statusCode != 200 || me.data is! Map) {
        throw AuthFailure(_messageFor(me));
      }
      await _prefs.setString(_tenantKey, cleanTenant);
      return AuthUser.fromJson(Map<String, dynamic>.from(me.data as Map));
    } on AuthFailure {
      rethrow;
    } on DioException catch (error) {
      throw AuthFailure(_networkMessage(error));
    } on ApiConnectionException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.postForm('/auth/logout', const {});
    } finally {
      await _client.clearSession();
    }
  }

  String _messageFor(Response<dynamic> response) {
    if (response.data case {
      'message': final String message,
    } when message.isNotEmpty && message != 'Invalid credentials') {
      return message;
    }
    return switch (response.statusCode) {
      401 => 'اسم الدخول أو كلمة المرور غير صحيحة',
      403 => 'ليس لديك صلاحية لتنفيذ هذا الإجراء.',
      429 => 'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.',
      _ => 'تعذر إتمام الطلب. حاول مرة أخرى.',
    };
  }

  String _networkMessage(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => 'انتهت مهلة الاتصال بالخادم',
      _ => 'تعذر الاتصال بالخادم',
    };
  }
}
