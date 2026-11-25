import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';
import 'package:fundflow_mob/features/settings/domain/settings_models.dart';
import 'package:fundflow_mob/features/users/data/users_repository.dart';
import 'package:fundflow_mob/features/users/domain/user_models.dart';
import 'package:fundflow_mob/features/users/presentation/users_screen.dart';

void main() {
  setUpAll(_loadFonts);

  test(
    'without ORGANIZATION_VIEW, roles come from /roles under the ceiling',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              options.uri.path == '/api/organization/options'
                  ? Response<dynamic>(
                      requestOptions: options,
                      statusCode: 403,
                      data: const {'message': 'forbidden'},
                    )
                  : Response<dynamic>(
                      requestOptions: options,
                      statusCode: 200,
                      data: const [
                        {
                          'id': 'role-employee',
                          'code': 'EMPLOYEE',
                          'name': 'موظف',
                          'active': true,
                          'permissionCodes': ['CUSTODY_SELF_VIEW'],
                        },
                        {
                          'id': 'role-finance',
                          'code': 'FINANCE',
                          'name': 'مالية',
                          'active': true,
                          'permissionCodes': ['TREASURY_APPROVE'],
                        },
                        {
                          'id': 'role-admin',
                          'code': 'TENANT_ADMIN',
                          'name': 'مدير',
                          'active': true,
                          'permissionCodes': [],
                        },
                      ],
                    ),
            );
          },
        ),
      );
      final options =
          await UsersRepository(
            ApiClient(dio: dio, cookieJar: CookieJar()),
          ).options(
            activeCompanyId: 'company-1',
            ownPermissions: const {'USERS_MANAGE'},
            ownRoleCode: 'HR',
          );

      expect(options.rolesFor('company-1').map((role) => role.id), [
        'role-employee',
      ]);
      expect(options.membershipCompanyIds, isEmpty);
    },
  );

  Future<_FakeUsersRepository> pumpUsers(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = _FakeUsersRepository();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: UsersScreen(
              repository: repository,
              currentUserId: 'me',
              currentRoleCode: 'TENANT_ADMIN',
              activeCompanyId: 'company-1',
              canManage: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('users list opens the user file with its tabs and actions', (
    tester,
  ) async {
    await pumpUsers(tester);
    expect(find.text('المستخدمون'), findsOneWidget);
    expect(find.text('مستخدم جديد'), findsOneWidget);
    expect(find.text('سارة علي'), findsOneWidget);
    expect(find.text('\u2066@sara\u2069 · EMP-014'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/users_list_390x844.png'),
    );

    await tester.tap(find.text('سارة علي'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('تعديل البيانات'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
    expect(find.text('خروج من كل الأجهزة'), findsOneWidget);
    expect(find.text('إضافة عضوية'), findsOneWidget);
    expect(find.text('الشركة الأم'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/user_file_390x844.png'),
    );
  });

  testWidgets('edit, reset password and cost centres open sheets and save', (
    tester,
  ) async {
    final repository = await pumpUsers(tester);
    await tester.tap(find.text('سارة علي'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('تعديل البيانات'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('تعديل المستخدم'), findsOneWidget);
    await tester.tap(find.text('حفظ التعديلات'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(repository.saves, 1);

    await tester.tap(find.byKey(const ValueKey('reset-password-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'short');
    await tester.tap(find.text('حفظ كلمة المرور'));
    await tester.pumpAndSettle();
    expect(find.text('كلمة المرور ثمانية أحرف على الأقل'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'NewPass2026');
    await tester.enterText(find.byType(TextFormField).at(1), 'NewPass2026');
    await tester.tap(find.text('حفظ كلمة المرور'));
    await tester.pumpAndSettle();
    expect(repository.passwordResets, 1);

    await tester.tap(find.text('مراكز التكلفة'));
    await tester.pumpAndSettle();
    expect(find.text('مشروع العاصمة'), findsOneWidget);
    await tester.tap(find.text('إدارة مراكز التكلفة'));
    await tester.pumpAndSettle();
    expect(find.text('1 محدد'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/user_cost_centers_sheet_390x844.png'),
    );
    await tester.tap(find.text('مكتب الإدارة'));
    await tester.pumpAndSettle();
    expect(find.text('2 محدد'), findsOneWidget);
    await tester.tap(find.text('حفظ التعيينات'));
    await tester.pumpAndSettle();
    expect(repository.savedCostCenters, ['center-1', 'center-2']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('turning off a user who is owed custody asks first', (
    tester,
  ) async {
    final repository = await pumpUsers(tester);
    await tester.tap(find.text('سارة علي'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('تعديل البيانات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('المستخدم نشط'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ التعديلات'));
    await tester.pumpAndSettle();
    expect(find.text('عهدته بالسالب'), findsOneWidget);
    await tester.tap(find.text('إلغاء').last);
    await tester.pumpAndSettle();
    expect(repository.saves, 0);
  });
}

Future<void> _loadFonts() async {
  final cairo = FontLoader('Cairo')
    ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
  final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(
      rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
    );
  await Future.wait([cairo.load(), lucide.load()]);
}

const _sara = AppUserRecord(
  id: 'user-1',
  code: 'EMP-014',
  name: 'سارة علي',
  username: 'sara',
  active: true,
  version: 3,
  roleId: 'role-accountant',
  roleCode: 'ACCOUNTANT',
  roleName: 'محاسب',
  costCenterIds: ['center-1'],
  costDetailsEnabled: true,
  createdAt: '2026-09-01T10:00:00+02:00',
  updatedAt: '2026-11-20T10:00:00+02:00',
);

class _FakeUsersRepository extends UsersRepository {
  _FakeUsersRepository() : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  int saves = 0;
  int passwordResets = 0;
  List<String>? savedCostCenters;

  @override
  Future<UsersPage> list({
    String query = '',
    bool? active,
    String? roleId,
    int page = 0,
    int size = 10,
  }) async => const UsersPage(
    items: [
      _sara,
      AppUserRecord(
        id: 'user-2',
        code: 'EMP-020',
        name: 'محمود حسن',
        username: 'mahmoud',
        active: false,
        version: 1,
        roleName: 'مهندس موقع',
        costCenterIds: [],
        costDetailsEnabled: false,
        createdAt: '2026-10-01T10:00:00+02:00',
        updatedAt: '2026-10-01T10:00:00+02:00',
      ),
    ],
    total: 2,
    page: 0,
    size: 10,
  );

  @override
  Future<OrganizationOptions> options({
    String? activeCompanyId,
    Set<String> ownPermissions = const {},
    String? ownRoleCode,
  }) async => OrganizationOptions.fromJson({
    'companies': [
      {'id': 'company-1', 'name': 'الشركة الأم'},
    ],
    'departments': [
      {'id': 'dept-1', 'name': 'الحسابات', 'companyId': 'company-1'},
    ],
    'roles': [
      {
        'id': 'role-accountant',
        'code': 'ACCOUNTANT',
        'name': 'محاسب',
        'active': true,
        'assignableCompanyIds': ['company-1'],
      },
    ],
    'membershipCompanyIds': ['company-1'],
  });

  @override
  Future<UserProfile> profile(String id) async => const UserProfile(
    user: _sara,
    memberships: [
      UserMembership(
        id: 'membership-1',
        companyId: 'company-1',
        companyName: 'الشركة الأم',
        departmentId: 'dept-1',
        departmentName: 'الحسابات',
        roleId: 'role-accountant',
        roleName: 'محاسب',
        active: true,
        version: 1,
      ),
    ],
    custodies: [
      UserCustody(
        id: 'custody-1',
        companyId: 'company-1',
        companyName: 'الشركة الأم',
        currencyCode: 'EGP',
        balance: '-1250.00',
        active: true,
      ),
    ],
    costCenters: [
      UserCostCenter(
        id: 'center-1',
        code: 'CC-001',
        name: 'مشروع العاصمة',
        type: 'PROJECT',
        active: true,
      ),
    ],
  );

  @override
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
    saves++;
    savedCostCenters = costCenterIds;
    return user ?? _sara;
  }

  @override
  Future<void> resetPassword(AppUserRecord user, String password) async {
    passwordResets++;
  }

  @override
  Future<List<ReferenceRecord>> allCostCenters() async => const [
    ReferenceRecord(
      id: 'center-1',
      code: 'CC-001',
      name: 'مشروع العاصمة',
      active: true,
      version: 1,
      createdAt: '',
      updatedAt: '',
      type: 'PROJECT',
    ),
    ReferenceRecord(
      id: 'center-2',
      code: 'OF-001',
      name: 'مكتب الإدارة',
      active: true,
      version: 1,
      createdAt: '',
      updatedAt: '',
      type: 'OFFICE',
    ),
  ];
}
