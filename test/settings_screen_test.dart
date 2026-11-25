import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';
import 'package:fundflow_mob/features/extracts/domain/extract_models.dart';
import 'package:fundflow_mob/features/settings/data/settings_repository.dart';
import 'package:fundflow_mob/features/settings/domain/cost_center_financial_detail.dart';
import 'package:fundflow_mob/features/settings/domain/contractor_financial_detail.dart';
import 'package:fundflow_mob/features/settings/domain/settings_models.dart';
import 'package:fundflow_mob/features/settings/presentation/reference_settings_screen.dart';

void main() {
  setUpAll(_loadFonts);

  test('loads cost centers from the supported list endpoint', () async {
    Uri? requestedUri;
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requestedUri = options.uri;
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: const {'items': [], 'total': 0, 'page': 0, 'size': 10},
            ),
          );
        },
      ),
    );
    final repository = SettingsRepository(
      ApiClient(dio: dio, cookieJar: CookieJar()),
    );

    await repository.findAll(section: SettingsSection.costCenters);

    expect(requestedUri?.path, '/api/settings/cost-centers');
    expect(requestedUri?.path, isNot(contains('/financials')));
  });

  testWidgets('shows cost-center list and opens its financial detail', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ReferenceSettingsScreen(
              repository: _FakeSettingsRepository(),
              section: SettingsSection.costCenters,
              canManage: true,
              canOpenCenter: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مراكز التكلفة'), findsOneWidget);
    expect(find.text('مركز جديد'), findsOneWidget);
    expect(find.text('مشروع العاصمة'), findsOneWidget);
    expect(find.text('عرض التفاصيل'), findsOneWidget);
    expect(find.text('وارد'), findsNothing);
    expect(find.text('125,000.00'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/cost_centers_web_style_390x844.png'),
    );

    await tester.tap(find.text('مشروع العاصمة'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('العودة لمراكز التكلفة'), findsOneWidget);
    expect(find.byTooltip('تعديل مركز التكلفة'), findsOneWidget);
    // The client statement opens first, behind its summary card.
    expect(find.text('مستحق على العميل'), findsOneWidget);
    expect(find.text('كشف الحركات'), findsOneWidget);
    expect(find.text('مستخلص مقاول'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/cost_center_file_390x844.png'),
    );

    await tester.tap(find.text('مستحق للمقاولين'));
    await tester.pumpAndSettle();
    expect(find.text('المدفوع من الشركة'), findsOneWidget);
    expect(find.text('المقاول أحمد'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('مستخلصات المقاولين'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('مستخلصات المقاولين'));
    await tester.pumpAndSettle();
    expect(find.text('ابحث بالمقاول أو رقم المستخلص…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens contractor account with expandable extracts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ReferenceSettingsScreen(
              repository: _FakeContractorSettingsRepository(),
              section: SettingsSection.contractors,
              canManage: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ملف مقاول'), findsOneWidget);
    expect(find.text('عرض الحساب'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/contractors_premium_390x844.png'),
    );
    await tester.tap(find.text('بيومي'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('العودة للمقاولين'), findsOneWidget);
    expect(find.text('المستحق'), findsWidgets);
    expect(find.text('26,040.00'), findsWidgets);
    await tester.tap(find.text('بيومي').last);
    await tester.pumpAndSettle();
    expect(find.text('فاتورة توريدات كهرباء'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows compact units and edits their input mode', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = _FakeUnitsSettingsRepository();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ReferenceSettingsScreen(
              repository: repository,
              section: SettingsSection.units,
              canManage: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('وحدات القياس'), findsOneWidget);
    expect(find.text('متر مربع'), findsOneWidget);
    expect(find.text('كمية × سعر'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/units_compact_390x844.png'),
    );
    await tester.tap(find.byTooltip('تعديل'));
    await tester.pumpAndSettle();
    expect(find.text('طريقة إدخال الوحدة *'), findsOneWidget);
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(repository.savedInputMode, 'QUANTITY_RATE');
    expect(tester.takeException(), isNull);
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

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository()
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  @override
  Future<ReferencePage> findAll({
    required SettingsSection section,
    String query = '',
    bool? active,
    String? type,
    bool subCategoriesOnly = false,
    int page = 0,
    int size = 10,
  }) async => ReferencePage(
    items: const [
      ReferenceRecord(
        id: 'center-1',
        code: 'CC-001',
        name: 'مشروع العاصمة',
        active: true,
        version: 1,
        createdAt: '2026-01-01T10:00:00+02:00',
        updatedAt: '2026-10-26T10:00:00+02:00',
        type: 'PROJECT',
      ),
    ],
    total: 1,
    page: page,
    size: size,
  );

  @override
  Future<CostCenterFinancialDetail> costCenterFinancial(String id) async =>
      const CostCenterFinancialDetail(
        center: ReferenceRecord(
          id: 'center-1',
          code: 'CC-001',
          name: 'مشروع العاصمة',
          active: true,
          version: 1,
          createdAt: '2026-01-01T10:00:00+02:00',
          updatedAt: '2026-10-26T10:00:00+02:00',
          type: 'PROJECT',
          incoming: '125000.00',
          outgoing: '82500.00',
          debt: '17500.00',
          extractCount: 1,
        ),
        extracts: [
          ContractorExtract(
            id: 'extract-1',
            contractorId: 'contractor-1',
            contractorName: 'المقاول أحمد',
            centerId: 'center-1',
            centerName: 'مشروع العاصمة',
            extractNo: 7,
            extractDate: '2026-10-26',
            status: 'APPROVED',
            version: 1,
            financialsVisible: true,
            net: '17500.00',
            outstanding: '17500.00',
            items: [],
          ),
        ],
        clientOwed: '42000.00',
        client: ClientAccount(
          charged: '67000.00',
          credited: '25000.00',
          balance: '42000.00',
          months: [
            (
              month: '2026-10',
              charged: '67000.00',
              covered: '25000.00',
              remaining: '42000.00',
            ),
          ],
          movements: [
            ClientMovement(
              date: '2026-10-20',
              kind: 'DEPOSIT',
              description: 'دفعة مقدمة',
              charge: '0',
              credit: '25000.00',
              balance: '-25000.00',
            ),
            ClientMovement(
              date: '2026-10-26',
              kind: 'CONTRACTOR_EXTRACT',
              reference: '7',
              party: 'المقاول أحمد',
              description: 'أعمال المحارة',
              charge: '67000.00',
              credit: '0',
              balance: '42000.00',
            ),
          ],
        ),
        profits: (
          fees: '5000.00',
          priceDifference: '3500.00',
          savings: '0',
          total: '8500.00',
        ),
        contractors: (
          due: '17500.00',
          paid: '0',
          debt: '17500.00',
          items: [
            CenterContractorLine(
              contractorId: 'contractor-1',
              contractorName: 'المقاول أحمد',
              due: '17500.00',
              paidByCompany: '0',
              paidByClient: '0',
              debt: '17500.00',
            ),
          ],
        ),
        snag: (total: '0', items: [], unmarked: []),
        administrative: (total: '1200.00', items: []),
        actual: (
          deposits: '25000.00',
          spent: '30500.00',
          difference: '-5500.00',
        ),
      );
}

class _FakeContractorSettingsRepository extends SettingsRepository {
  _FakeContractorSettingsRepository()
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  static const contractor = ReferenceRecord(
    id: 'contractor-1',
    code: 'SIPS',
    name: 'بيومي',
    active: true,
    version: 1,
    createdAt: '',
    updatedAt: '',
  );

  @override
  Future<ReferencePage> findAll({
    required SettingsSection section,
    String query = '',
    bool? active,
    String? type,
    bool subCategoriesOnly = false,
    int page = 0,
    int size = 10,
  }) async => ReferencePage(
    items: const [contractor],
    total: 1,
    page: page,
    size: size,
  );

  @override
  Future<ContractorFinancialDetail> contractorFinancialDetail(
    String id,
  ) async => const ContractorFinancialDetail(
    contractor: contractor,
    due: '26040.00',
    settled: '24063.00',
    debt: '1977.00',
    projectCount: 1,
    extracts: [
      ContractorExtract(
        id: 'extract-1',
        contractorId: 'contractor-1',
        contractorName: 'بيومي',
        centerId: 'center-1',
        centerName: 'مصنع SIPS',
        extractNo: 6,
        extractDate: '2026-10-23',
        status: 'APPROVED',
        version: 1,
        financialsVisible: true,
        net: '26040.00',
        outstanding: '1977.00',
        items: [
          ExtractItem(
            id: 'item-1',
            kind: 'WORK',
            lineNo: 1,
            description: 'فاتورة توريدات كهرباء',
            unitId: 'unit-1',
            unitName: 'مقطوعية',
            quantity: '1',
            rate: '26040.00',
            amount: '26040.00',
          ),
        ],
      ),
    ],
  );
}

class _FakeUnitsSettingsRepository extends SettingsRepository {
  _FakeUnitsSettingsRepository()
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  String? savedInputMode;

  static const unit = ReferenceRecord(
    id: 'unit-1',
    code: 'M2',
    name: 'متر مربع',
    active: true,
    version: 1,
    createdAt: '',
    updatedAt: '',
    inputMode: 'QUANTITY_RATE',
  );

  @override
  Future<ReferencePage> findAll({
    required SettingsSection section,
    String query = '',
    bool? active,
    String? type,
    bool subCategoriesOnly = false,
    int page = 0,
    int size = 10,
  }) async =>
      ReferencePage(items: const [unit], total: 1, page: page, size: size);

  @override
  Future<ReferenceRecord> save({
    required SettingsSection section,
    required String name,
    required String code,
    required bool active,
    ReferenceRecord? current,
    String? type,
    String? parentId,
    String? inputMode,
  }) async {
    savedInputMode = inputMode;
    return unit;
  }
}
