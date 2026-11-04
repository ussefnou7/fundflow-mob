import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/features/custody/data/custody_repository.dart';
import 'package:fundflow_mob/features/workspace/application/workspace_controller.dart';
import 'package:fundflow_mob/features/workspace/data/workspace_repository.dart';
import 'package:fundflow_mob/features/workspace/domain/workspace_context.dart';

void main() {
  test('parses memberships and identifies the active company', () {
    final context = WorkspaceContext.fromJson(_contextJson('company-2'));

    expect(context.memberships, hasLength(2));
    expect(context.activeCompanyId, 'company-2');
    expect(context.companyName, 'شركة النيل');
    expect(context.activeMembership?.roleName, 'مدير مشروع');
    expect(context.permissions, contains('CUSTODY_COMPANY_VIEW'));
  });

  test(
    'switches the backend company context and publishes the new workspace',
    () async {
      final client = ApiClient(dio: Dio(), cookieJar: CookieJar());
      final repository = _FakeWorkspaceRepository(
        client,
        initial: WorkspaceContext.fromJson(_contextJson('company-1')),
        switched: WorkspaceContext.fromJson(_contextJson('company-2')),
      );
      final controller = WorkspaceController(
        repository: repository,
        custody: CustodyRepository(client),
      );

      await controller.initialize();
      final changed = await controller.selectCompany('company-2');

      expect(changed, isTrue);
      expect(repository.selectedCompanyId, 'company-2');
      expect(controller.context?.activeCompanyId, 'company-2');
      expect(controller.context?.companyName, 'شركة النيل');
      expect(controller.switchingCompany, isFalse);
    },
  );
}

Map<String, dynamic> _contextJson(String activeCompanyId) => {
  'tenant': {'name': 'مجموعة الاختبار', 'theme': 'EVERGREEN'},
  'activeCompanyId': activeCompanyId,
  'platformAdmin': false,
  'memberships': [
    {
      'companyId': 'company-1',
      'companyName': 'شركة العاصمة',
      'holdingName': 'المجموعة',
      'departmentName': 'الحسابات',
      'roleId': 'role-1',
      'roleCode': 'ACCOUNTANT',
      'roleName': 'محاسب',
      'permissionCodes': ['DASHBOARD_VIEW'],
    },
    {
      'companyId': 'company-2',
      'companyName': 'شركة النيل',
      'holdingName': 'المجموعة',
      'departmentName': 'المشروعات',
      'roleId': 'role-2',
      'roleCode': 'PROJECT_MANAGER',
      'roleName': 'مدير مشروع',
      'permissionCodes': ['DASHBOARD_VIEW', 'CUSTODY_COMPANY_VIEW'],
    },
  ],
};

class _FakeWorkspaceRepository extends WorkspaceRepository {
  _FakeWorkspaceRepository(
    super.client, {
    required this.initial,
    required this.switched,
  });

  final WorkspaceContext initial;
  final WorkspaceContext switched;
  String? selectedCompanyId;

  @override
  Future<WorkspaceContext> load() async => initial;

  @override
  Future<WorkspaceContext> selectCompany(String companyId) async {
    selectedCompanyId = companyId;
    return switched;
  }
}
