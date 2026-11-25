import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/app/app.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';
import 'package:fundflow_mob/features/auth/application/auth_controller.dart';
import 'package:fundflow_mob/features/auth/domain/auth_gateway.dart';
import 'package:fundflow_mob/features/auth/domain/auth_user.dart';
import 'package:fundflow_mob/features/custody/data/custody_repository.dart';
import 'package:fundflow_mob/features/custody/domain/custody_models.dart';
import 'package:fundflow_mob/features/crm/data/crm_repository.dart';
import 'package:fundflow_mob/features/dashboard/data/dashboard_repository.dart';
import 'package:fundflow_mob/features/dashboard/domain/dashboard_models.dart';
import 'package:fundflow_mob/features/settings/data/settings_repository.dart';
import 'package:fundflow_mob/features/treasury/data/treasury_repository.dart';
import 'package:fundflow_mob/features/workspace/application/workspace_controller.dart';
import 'package:fundflow_mob/features/workspace/domain/workspace_context.dart';

void main() {
  setUpAll(_loadFonts);

  testWidgets('workspace uses an RTL sidebar with company switching', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final auth = AuthController(_LoggedInGateway());
    await auth.initialize();
    final workspace = WorkspaceController.seeded(
      custody: _FakeCustodyRepository(),
      settings: _FakeSettingsRepository(),
      treasury: _FakeTreasuryRepository(),
      dashboard: _FakeDashboardRepository(),
      crm: _FakeCrmRepository(),
      context: const WorkspaceContext(
        theme: FundFlowBrand.evergreen,
        companyName: 'شركة العاصمة',
        activeCompanyId: 'company-1',
        permissions: {
          'DASHBOARD_VIEW',
          'CUSTODY_SELF_VIEW',
          'CUSTODY_COMPANY_VIEW',
          'CUSTODY_TRANSFER',
          'CUSTODY_REQUEST_CREATE',
          'CUSTODY_REQUEST_VIEW',
          'CUSTODY_REQUEST_APPROVE',
          'SETTINGS_VIEW',
          'SETTINGS_MANAGE',
          'TREASURY_VIEW',
          'CRM_INSPECTION_DASHBOARD',
        },
        memberships: [
          WorkspaceMembership(
            companyId: 'company-1',
            companyName: 'شركة العاصمة',
            departmentName: 'إدارة المشروعات',
            roleName: 'مدير مشروع',
            permissionCodes: {'DASHBOARD_VIEW'},
          ),
          WorkspaceMembership(
            companyId: 'company-2',
            companyName: 'شركة النيل',
            departmentName: 'الحسابات',
            roleName: 'محاسب',
            permissionCodes: {'CUSTODY_SELF_VIEW'},
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      FundFlowApp(authController: auth, workspaceController: workspace),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('فتح القائمة'), findsOneWidget);
    expect(find.byTooltip('الإشعارات'), findsOneWidget);
    expect(find.byKey(const ValueKey('company-header-icon')), findsOneWidget);
    final companyHeader = find.textContaining(
      'شركة العاصمة',
      findRichText: true,
    );
    expect(companyHeader, findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/workspace_header_390x844.png'),
    );
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();

    final appLogo = find.byKey(const ValueKey('sidebar-app-logo'));
    expect(appLogo, findsOneWidget);
    // Asset images decode off the test clock; wait so the wordmark is drawn.
    await tester.runAsync(() async {
      final image = tester.widget<Image>(appLogo).image;
      await precacheImage(image, tester.element(appLogo));
    });
    await tester.pumpAndSettle();
    // Groups start collapsed; open the custody group to see its pages.
    await tester.tap(find.text('إدارة العهد'));
    await tester.pumpAndSettle();
    expect(find.text('مجمع العهد'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('العهد'), findsOneWidget);
    expect(find.text('المالية'), findsOneWidget);
    expect(find.text('العملاء'), findsOneWidget);
    expect(find.text('العهدة'), findsOneWidget);
    expect(find.text('وحدات القياس'), findsNothing);
    expect(find.text('الخزن'), findsNothing);
    expect(find.text('تسجيل الخروج'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/workspace_sidebar_390x844.png'),
    );

    await tester.tap(find.text('الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.text('وحدات القياس'), findsOneWidget);
    expect(find.text('العهدة'), findsNothing);
    expect(find.text('الخزن'), findsNothing);

    await tester.tap(find.text('المالية'));
    await tester.pumpAndSettle();
    expect(find.text('الخزن'), findsOneWidget);
    expect(find.text('وحدات القياس'), findsNothing);
    expect(find.text('العهدة'), findsNothing);

    await tester.tap(find.text('العملاء'));
    await tester.pumpAndSettle();
    expect(find.text('لوحة المعاينات'), findsOneWidget);
    expect(find.text('الخزن'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/workspace_crm_menu_390x844.png'),
    );

    Navigator.of(tester.element(find.byType(Drawer))).pop();
    await tester.pumpAndSettle();
    await tester.tap(companyHeader);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('شركة النيل'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/company_dropdown_390x844.png'),
    );

    // Close the company picker, open another top-level destination, then
    // exercise the platform back dispatch used by Android's back button.
    await tester.tapAt(const Offset(8, 800));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('فتح القائمة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إدارة العهد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العهدة'));
    await tester.pumpAndSettle();
    expect(find.text('لوحة المتابعة'), findsNothing);
    expect(find.byTooltip('رجوع'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('لوحة المتابعة'), findsOneWidget);
    expect(find.byTooltip('رجوع'), findsNothing);
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

class _LoggedInGateway implements AuthGateway {
  @override
  String get savedTenant => 'SHG';

  @override
  Future<AuthUser?> currentUser() async => const AuthUser(
    id: 'user-1',
    name: 'أحمد محمد',
    username: 'ahmed',
    platformAdmin: false,
  );

  @override
  Future<AuthUser> login({
    required String tenant,
    required String username,
    required String password,
    String? code,
  }) async => (await currentUser())!;

  @override
  Future<void> logout() async {}
}

class _FakeCustodyRepository extends CustodyRepository {
  _FakeCustodyRepository()
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  @override
  Future<DashboardData> dashboard() async => const DashboardData(
    memberCount: 48,
    custodyOwnerCount: 12,
    totalFunding: '425000.00',
    approvedAmount: '286450.50',
    remaining: '138549.50',
    unpaidRequestCount: 3,
    unpaidRequestAmount: '45000.00',
    companyCash: [CompanyCash('EGP', 'ج.م', '720000.00')],
    owners: [],
  );
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository()
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));
}

class _FakeTreasuryRepository extends TreasuryRepository {
  _FakeTreasuryRepository()
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));
}

class _FakeDashboardRepository extends DashboardRepository {
  _FakeDashboardRepository()
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  @override
  Future<FollowUpBoard> load() async => FollowUpBoard.fromJson({
    'today': '2026-11-25',
    'inbox': [
      {'kind': 'APPROVALS', 'count': 3},
    ],
    'alerts': <Object>[],
  });
}

class _FakeCrmRepository extends CrmRepository {
  _FakeCrmRepository() : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));
}
