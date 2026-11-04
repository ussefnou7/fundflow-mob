import '../../../core/theme/app_theme.dart';

class WorkspaceContext {
  const WorkspaceContext({
    required this.theme,
    required this.companyName,
    required this.permissions,
    this.activeCompanyId,
    this.memberships = const [],
    this.platformAdmin = false,
    this.tenantName = 'Monetizer',
    this.hasTenantLogo = false,
  });

  factory WorkspaceContext.fromJson(Map<String, dynamic> json) {
    final activeCompanyId = json['activeCompanyId']?.toString();
    final memberships = json['memberships'] as List? ?? const [];
    Map<String, dynamic>? active;
    for (final item in memberships) {
      final membership = Map<String, dynamic>.from(item as Map);
      if (membership['companyId']?.toString() == activeCompanyId) {
        active = membership;
        break;
      }
    }
    final tenant = json['tenant'] is Map
        ? Map<String, dynamic>.from(json['tenant'] as Map)
        : const <String, dynamic>{};
    final parsedMemberships = memberships
        .whereType<Map>()
        .map(
          (item) =>
              WorkspaceMembership.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
    return WorkspaceContext(
      theme: FundFlowBrand.fromApi(tenant['theme']?.toString()),
      companyName:
          active?['companyName']?.toString() ??
          tenant['name']?.toString() ??
          'Monetizer',
      permissions: Set<String>.from(
        active?['permissionCodes'] as List? ?? const [],
      ),
      activeCompanyId: activeCompanyId,
      memberships: parsedMemberships,
      platformAdmin: json['platformAdmin'] as bool? ?? false,
      tenantName: tenant['name']?.toString() ?? 'Monetizer',
      hasTenantLogo: tenant['hasLogo'] == true,
    );
  }

  final FundFlowBrand theme;
  final String companyName;
  final Set<String> permissions;
  final String? activeCompanyId;
  final List<WorkspaceMembership> memberships;
  final bool platformAdmin;
  final String tenantName;
  final bool hasTenantLogo;

  WorkspaceMembership? get activeMembership {
    for (final membership in memberships) {
      if (membership.companyId == activeCompanyId) return membership;
    }
    return memberships.isEmpty ? null : memberships.first;
  }
}

class WorkspaceMembership {
  const WorkspaceMembership({
    required this.companyId,
    required this.companyName,
    required this.permissionCodes,
    this.holdingName,
    this.departmentName,
    this.roleId,
    this.roleCode,
    this.roleName,
  });

  factory WorkspaceMembership.fromJson(Map<String, dynamic> json) {
    return WorkspaceMembership(
      companyId: json['companyId'].toString(),
      companyName: json['companyName']?.toString() ?? 'شركة',
      holdingName: json['holdingName']?.toString(),
      departmentName: json['departmentName']?.toString(),
      roleId: json['roleId']?.toString(),
      roleCode: json['roleCode']?.toString(),
      roleName: json['roleName']?.toString(),
      permissionCodes: Set<String>.from(
        json['permissionCodes'] as List? ?? const [],
      ),
    );
  }

  final String companyId;
  final String companyName;
  final String? holdingName;
  final String? departmentName;
  final String? roleId;
  final String? roleCode;
  final String? roleName;
  final Set<String> permissionCodes;

  String? get subtitle {
    final department = departmentName?.trim();
    if (department != null && department.isNotEmpty) return department;
    final holding = holdingName?.trim();
    if (holding != null &&
        holding.isNotEmpty &&
        holding != companyName.trim()) {
      return holding;
    }
    return null;
  }
}
