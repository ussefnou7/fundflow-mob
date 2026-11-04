import 'auth_user.dart';

abstract interface class AuthGateway {
  String get savedTenant;

  Future<AuthUser?> currentUser();

  Future<AuthUser> login({
    required String tenant,
    required String username,
    required String password,
    String? code,
  });

  Future<void> logout();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.mfaRequired = false});

  final bool mfaRequired;

  final String message;
}
