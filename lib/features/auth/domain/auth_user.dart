class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.username,
    required this.platformAdmin,
    this.roleName,
    this.custodyId,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      platformAdmin: json['platformAdmin'] as bool? ?? false,
      roleName: json['roleName'] as String?,
      custodyId: json['custodyId'] as String?,
    );
  }

  final String id;
  final String name;
  final String username;
  final bool platformAdmin;
  final String? roleName;
  final String? custodyId;
}
