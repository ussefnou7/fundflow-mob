List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const [])
    .whereType<Map>()
    .map((item) => Map<String, dynamic>.from(item))
    .toList(growable: false);

List<String> _ids(Object? value) => (value as List? ?? const [])
    .map((item) => item.toString())
    .toList(growable: false);

/// A user as the active company sees it: [roleId] is the user's role in the
/// active company, null when not a member of it.
class AppUserRecord {
  const AppUserRecord({
    required this.id,
    required this.code,
    required this.name,
    required this.username,
    required this.active,
    required this.version,
    required this.costCenterIds,
    required this.costDetailsEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.roleId,
    this.roleCode,
    this.roleName,
  });

  factory AppUserRecord.fromJson(Map<String, dynamic> json) => AppUserRecord(
    id: json['id']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    username: json['username']?.toString() ?? '',
    active: json['active'] == true,
    version: (json['version'] as num?)?.toInt() ?? 0,
    roleId: json['roleId']?.toString(),
    roleCode: json['roleCode']?.toString(),
    roleName: json['roleName']?.toString(),
    costCenterIds: _ids(json['costCenterIds']),
    costDetailsEnabled: json['costDetailsEnabled'] == true,
    createdAt: json['createdAt']?.toString() ?? '',
    updatedAt: json['updatedAt']?.toString() ?? '',
  );

  final String id, code, name, username, createdAt, updatedAt;
  final bool active, costDetailsEnabled;
  final int version;
  final String? roleId, roleCode, roleName;
  final List<String> costCenterIds;

  bool get tenantAdmin => roleCode == 'TENANT_ADMIN';
}

class UsersPage {
  const UsersPage({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });

  factory UsersPage.fromJson(Map<String, dynamic> json) => UsersPage(
    items: _maps(
      json['items'],
    ).map(AppUserRecord.fromJson).toList(growable: false),
    total: (json['total'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 0,
    size: (json['size'] as num?)?.toInt() ?? 10,
  );

  final List<AppUserRecord> items;
  final int total, page, size;
}

class UserMembership {
  const UserMembership({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.departmentId,
    required this.departmentName,
    required this.roleId,
    required this.roleName,
    required this.active,
    required this.version,
  });

  factory UserMembership.fromJson(Map<String, dynamic> json) => UserMembership(
    id: json['id']?.toString() ?? '',
    companyId: json['companyId']?.toString() ?? '',
    companyName: json['companyName']?.toString() ?? '—',
    departmentId: json['departmentId']?.toString() ?? '',
    departmentName: json['departmentName']?.toString() ?? '—',
    roleId: json['roleId']?.toString() ?? '',
    roleName: json['roleName']?.toString() ?? '—',
    active: json['active'] == true,
    version: (json['version'] as num?)?.toInt() ?? 0,
  );

  final String id,
      companyId,
      companyName,
      departmentId,
      departmentName,
      roleId,
      roleName;
  final bool active;
  final int version;
}

class UserCustody {
  const UserCustody({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.currencyCode,
    required this.balance,
    required this.active,
    this.lastSettledAt,
  });

  factory UserCustody.fromJson(Map<String, dynamic> json) => UserCustody(
    id: json['id']?.toString() ?? '',
    companyId: json['companyId']?.toString() ?? '',
    companyName: json['companyName']?.toString() ?? '—',
    currencyCode: json['currencyCode']?.toString() ?? '',
    balance: json['balance']?.toString() ?? '0',
    active: json['active'] == true,
    lastSettledAt: json['lastSettledAt']?.toString(),
  );

  final String id, companyId, companyName, currencyCode, balance;
  final bool active;
  final String? lastSettledAt;
}

class UserCostCenter {
  const UserCostCenter({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.active,
  });

  factory UserCostCenter.fromJson(Map<String, dynamic> json) => UserCostCenter(
    id: json['id']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    type: json['type']?.toString() ?? 'PROJECT',
    active: json['active'] == true,
  );

  final String id, code, name, type;
  final bool active;
}

class UserProfile {
  const UserProfile({
    required this.user,
    required this.memberships,
    required this.custodies,
    required this.costCenters,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    user: AppUserRecord.fromJson(
      Map<String, dynamic>.from(json['user'] as Map? ?? const {}),
    ),
    memberships: _maps(
      json['memberships'],
    ).map(UserMembership.fromJson).toList(growable: false),
    custodies: _maps(
      json['custodies'],
    ).map(UserCustody.fromJson).toList(growable: false),
    costCenters: _maps(
      json['costCenters'],
    ).map(UserCostCenter.fromJson).toList(growable: false),
  );

  final AppUserRecord user;
  final List<UserMembership> memberships;
  final List<UserCustody> custodies;
  final List<UserCostCenter> costCenters;
}

typedef OrgRef = ({String id, String name});

/// What the signed-in user may hand out: companies they manage memberships
/// in, and per role the companies the server lets them assign it in.
class OrganizationOptions {
  const OrganizationOptions({
    required this.companies,
    required this.departments,
    required this.roles,
    required this.membershipCompanyIds,
  });

  factory OrganizationOptions.fromJson(Map<String, dynamic> json) =>
      OrganizationOptions(
        companies: [
          for (final item in _maps(json['companies']))
            (id: item['id']?.toString() ?? '', name: '${item['name'] ?? '—'}'),
        ],
        departments: [
          for (final item in _maps(json['departments']))
            (
              id: item['id']?.toString() ?? '',
              name: '${item['name'] ?? '—'}',
              companyId: item['companyId']?.toString() ?? '',
              active: item['active'] != false,
            ),
        ],
        roles: [
          for (final item in _maps(json['roles']))
            (
              id: item['id']?.toString() ?? '',
              code: item['code']?.toString() ?? '',
              name: '${item['name'] ?? '—'}',
              active: item['active'] != false,
              assignableCompanyIds: _ids(item['assignableCompanyIds']),
            ),
        ],
        membershipCompanyIds: _ids(json['membershipCompanyIds']).toSet(),
      );

  final List<OrgRef> companies;
  final List<({String id, String name, String companyId, bool active})>
  departments;
  final List<
    ({
      String id,
      String code,
      String name,
      bool active,
      List<String> assignableCompanyIds,
    })
  >
  roles;
  final Set<String> membershipCompanyIds;

  /// Active roles the signed-in user may assign in [companyId]. Tenant admins
  /// are appointed from the platform panel only.
  List<OrgRef> rolesFor(String? companyId) => [
    for (final role in roles)
      if (role.active &&
          role.code != 'TENANT_ADMIN' &&
          role.assignableCompanyIds.contains(companyId))
        (id: role.id, name: role.name),
  ];
}
