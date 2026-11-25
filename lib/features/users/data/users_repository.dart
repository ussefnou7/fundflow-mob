import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../settings/domain/settings_models.dart';
import '../domain/user_models.dart';

/// Permissions that only let a person work on their own records. The server
/// leaves them out of the delegation ceiling, so the role picker does too
/// (the web's EditDialogs list). The HR codes stay so roles that carry them
/// are judged as on the web; nothing in this app shows them.
const assignmentCeilingExempt = {
  'CUSTODY_SELF_VIEW',
  'CUSTODY_EXPENSE_CREATE',
  'CUSTODY_REQUEST_CREATE',
  'CUSTODY_TRANSFER',
  'PROJECT_PLAN_SELF_VIEW',
  'PROJECT_PLAN_SUBMIT',
  'CUSTODY_SETTLEMENT_ALERTS',
  'HR_ATTENDANCE_PUNCH',
  'HR_REQUESTS_CREATE',
};

class UsersRepository {
  const UsersRepository(this._client);

  final ApiClient _client;

  Future<UsersPage> list({
    String query = '',
    bool? active,
    String? roleId,
    int page = 0,
    int size = 10,
  }) async {
    final parameters = <String, String>{
      'q': query.trim(),
      'page': '$page',
      'size': '$size',
      if (active != null) 'active': '$active',
      if (roleId != null && roleId.isNotEmpty) 'roleId': roleId,
    };
    return UsersPage.fromJson(
      requireMap(
        await _client.get('/users?${Uri(queryParameters: parameters).query}'),
      ),
    );
  }

  Future<UserProfile> profile(String id) async =>
      UserProfile.fromJson(requireMap(await _client.get('/users/$id/profile')));

  /// What the signed-in user may hand out. `/organization/options` needs
  /// ORGANIZATION_VIEW; without it, fall back to `/roles` (ROLES_VIEW) with
  /// the web's own ceiling, roles in the active company only and no
  /// membership changes.
  Future<OrganizationOptions> options({
    String? activeCompanyId,
    Set<String> ownPermissions = const {},
    String? ownRoleCode,
  }) async {
    final response = await _client.get('/organization/options');
    if (response.statusCode == 200 && response.data is Map) {
      return OrganizationOptions.fromJson(requireMap(response));
    }
    final roles = requireList(await _client.get('/roles')).whereType<Map>();
    return OrganizationOptions.fromJson({
      'companies': const [],
      'departments': const [],
      'membershipCompanyIds': const [],
      'roles': [
        for (final role in roles)
          if (ownRoleCode == 'TENANT_ADMIN' ||
              (role['permissionCodes'] as List? ?? const []).every(
                (code) =>
                    assignmentCeilingExempt.contains(code) ||
                    ownPermissions.contains(code),
              ))
            {
              ...Map<String, dynamic>.from(role),
              'assignableCompanyIds': [?activeCompanyId],
            },
      ],
    });
  }

  /// Creates a user with [password], or updates [user]. The role is the
  /// membership role in the active company. Cost centres are kept as they are
  /// unless [costCenterIds] is given.
  Future<AppUserRecord> save({
    AppUserRecord? user,
    required String code,
    required String name,
    required String username,
    required String roleId,
    required bool active,
    String? password,
    List<String>? costCenterIds,
  }) async {
    final body = {
      'code': code.trim(),
      'name': name.trim(),
      'username': username.trim(),
      'roleId': roleId,
      'active': active,
      'costCenterIds': costCenterIds ?? user?.costCenterIds ?? const [],
      'version': user?.version,
      if (user == null) 'password': password,
    };
    return AppUserRecord.fromJson(
      requireMap(
        user == null
            ? await _client.postJson('/users', body)
            : await _client.putJson('/users/${user.id}', body),
      ),
    );
  }

  /// Saves only the user's cost centres, keeping every other field.
  Future<AppUserRecord> saveCostCenters(
    AppUserRecord user,
    List<String> costCenterIds,
  ) => save(
    user: user,
    code: user.code,
    name: user.name,
    username: user.username,
    roleId: user.roleId!,
    active: user.active,
    costCenterIds: costCenterIds,
  );

  Future<void> resetPassword(AppUserRecord user, String password) async {
    final response = await _client.postJson('/users/${user.id}/password', {
      'password': password,
      'version': user.version,
    });
    if (response.statusCode != 204) throw ApiError.fromResponse(response);
  }

  Future<void> logoutEverywhere(String userId) async {
    final response = await _client.postJson('/users/$userId/logout-all', {});
    if (response.statusCode != 204) throw ApiError.fromResponse(response);
  }

  Future<void> saveMembership({
    required String userId,
    UserMembership? membership,
    required String companyId,
    required String departmentId,
    required String roleId,
    required bool active,
  }) async {
    final body = {
      'userId': userId,
      'companyId': companyId,
      'departmentId': departmentId,
      'roleId': roleId,
      'active': active,
      'version': membership?.version,
    };
    final response = membership == null
        ? await _client.postJson('/organization/memberships', body)
        : await _client.putJson(
            '/organization/memberships/${membership.id}',
            body,
          );
    if ((response.statusCode ?? 500) >= 300) {
      throw ApiError.fromResponse(response);
    }
  }

  /// Every cost centre of the active company, active or not; the endpoint
  /// answers in pages of at most 100.
  Future<List<ReferenceRecord>> allCostCenters() async {
    final centers = <ReferenceRecord>[];
    for (var page = 0; ; page++) {
      final result = ReferencePage.fromJson(
        requireMap(
          await _client.get('/settings/cost-centers?page=$page&size=100'),
        ),
      );
      centers.addAll(result.items);
      if (result.items.isEmpty || centers.length >= result.total) {
        return centers;
      }
    }
  }
}
