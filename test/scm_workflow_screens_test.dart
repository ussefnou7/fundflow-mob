import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';
import 'package:fundflow_mob/features/scm/data/scm_repository.dart';
import 'package:fundflow_mob/features/scm/domain/scm_models.dart';
import 'package:fundflow_mob/features/scm/presentation/scm_screens.dart';
import 'package:fundflow_mob/features/scm/presentation/scm_materials_screen.dart';
import 'package:fundflow_mob/features/workflow/data/workflow_repository.dart';
import 'package:fundflow_mob/features/workflow/domain/workflow_models.dart';
import 'package:fundflow_mob/features/workflow/presentation/approvals_screen.dart';
import 'package:fundflow_mob/features/workflow/presentation/workflow_panel.dart';

void main() {
  test('units for the material sheets are read from every page', () async {
    final requested = <Uri>[];
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requested.add(options.uri);
          final page = int.parse(options.uri.queryParameters['page']!);
          // The server answers in pages, never a bare list: 100 + 1 units.
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'items': [
                  for (var i = 0; i < (page == 0 ? 100 : 1); i++)
                    {'id': 'unit-$page-$i', 'code': 'U$i', 'name': 'وحدة $i'},
                ],
                'total': 101,
                'page': page,
                'size': 100,
              },
            ),
          );
        },
      ),
    );
    final units = await ScmRepository(
      ApiClient(dio: dio, cookieJar: CookieJar()),
    ).units();

    expect(units, hasLength(101));
    expect(requested.map((uri) => uri.path).toSet(), {'/api/settings/units'});
    expect(requested.first.queryParameters['active'], 'true');
    expect(requested.map((uri) => uri.queryParameters['page']), ['0', '1']);
  });

  setUpAll(_loadFonts);

  Future<void> pump(WidgetTester tester, Widget child) async {
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
          child: Scaffold(body: SafeArea(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('manager sees unified approval inbox and server actions', (
    tester,
  ) async {
    final repository = _FakeWorkflowRepository();
    await pump(
      tester,
      ApprovalsScreen(
        repository: repository,
        permissions: const {'WORKFLOW_VIEW_ALL'},
        scm: _FakeScmRepository(),
      ),
    );

    expect(find.text('طلبات الموافقة'), findsOneWidget);
    expect(find.textContaining('موافقتي'), findsNothing);
    expect(find.textContaining('التنفيذ'), findsNothing);
    expect(find.text('الجارية'), findsNothing);
    expect(find.text('طلب شراء PR-104'), findsOneWidget);
    expect(find.text('مراجعة مدير المشروع'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/approvals_390x844.png'),
    );

    await tester.tap(find.text('طلب شراء PR-104'));
    await tester.pumpAndSettle();
    expect(find.text('مسار الموافقة'), findsOneWidget);
    expect(find.text('أسمنت بورتلاندي'), findsWidgets);
    expect(find.text('موافقة'), findsOneWidget);
    expect(find.text('سحب الطلب'), findsOneWidget);
    expect(find.text('إجمالي الفاتورة'), findsOneWidget);
    expect(find.text('تكلفة النقل'), findsOneWidget);
    expect(find.text('سعر الوحدة'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/scm_document_workflow_390x844.png'),
    );
    await tester.tap(find.text('موافقة'));
    await tester.pumpAndSettle();
    expect(find.text('تأكيد موافقة'), findsOneWidget);
  });

  testWidgets('workflow panel can be attached to any document screen', (
    tester,
  ) async {
    final repository = _FakeWorkflowRepository();
    var changed = false;
    await pump(
      tester,
      ListView(
        padding: const EdgeInsets.all(16),
        children: [
          WorkflowPanel(
            repository: repository,
            docType: 'PURCHASE_ORDER',
            docId: 'order-1',
            onChanged: () => changed = true,
          ),
        ],
      ),
    );

    expect(find.text('مسار الموافقة'), findsOneWidget);
    expect(find.text('مراجعة مدير المشروع'), findsWidgets);
    expect(find.text('بانتظار: المدير الحالي'), findsOneWidget);
    await tester.tap(find.text('موافقة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد موافقة'));
    await tester.pumpAndSettle();
    expect(repository.actionCount, 1);
    expect(changed, isTrue);
  });

  testWidgets('site engineer can open purchase request creation', (
    tester,
  ) async {
    await pump(
      tester,
      ScmDocumentsScreen(
        repository: _FakeScmRepository(),
        kind: ScmDocumentKind.requests,
        permissions: const {'SCM_REQUESTS_CREATE'},
      ),
    );

    expect(find.text('طلبات الشراء'), findsOneWidget);
    expect(find.text('طلب جديد'), findsOneWidget);
    expect(find.text('PR-104'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/scm_requests_390x844.png'),
    );

    await tester.tap(find.text('طلب جديد'));
    await tester.pumpAndSettle();
    expect(find.text('طلب شراء جديد'), findsOneWidget);
    expect(find.text('بيانات الطلب'), findsOneWidget);
    expect(find.text('إضافة بند'), findsOneWidget);
    await tester.ensureVisible(find.text('إضافة بند'));
    await tester.tap(find.text('إضافة بند'));
    await tester.pumpAndSettle();
    expect(find.text('النموذج'), findsOneWidget);
    expect(find.text('الكمية *'), findsOneWidget);
    expect(find.text('حفظ الطلب'), findsOneWidget);
  });

  testWidgets('draft SCM request opens a populated edit form', (tester) async {
    await pump(
      tester,
      ScmDocumentsScreen(
        repository: _FakeScmRepository(draft: true),
        kind: ScmDocumentKind.requests,
        permissions: const {'SCM_REQUESTS_CREATE'},
      ),
    );

    await tester.tap(find.text('PR-104'));
    await tester.pumpAndSettle();
    expect(find.text('تعديل'), findsOneWidget);
    await tester.tap(find.text('تعديل'));
    await tester.pumpAndSettle();
    expect(find.text('تعديل طلب الشراء'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'ملاحظات'), findsOneWidget);
    expect(find.text('أسمنت بورتلاندي'), findsWidgets);
  });

  testWidgets('stock balances are readable on mobile cards', (tester) async {
    await pump(tester, ScmStockScreen(repository: _FakeScmRepository()));

    expect(find.text('أرصدة المخازن'), findsOneWidget);
    expect(find.text('أسمنت بورتلاندي'), findsOneWidget);
    expect(find.text('1250 طن'), findsOneWidget);
  });

  testWidgets('purchasing manager can open a complete purchase order form', (
    tester,
  ) async {
    await pump(
      tester,
      ScmDocumentsScreen(
        repository: _FakeScmRepository(),
        kind: ScmDocumentKind.orders,
        permissions: const {'SCM_ORDERS_MANAGE'},
      ),
    );

    expect(find.text('أمر جديد'), findsOneWidget);
    await tester.tap(find.text('أمر جديد'));
    await tester.pumpAndSettle();
    expect(find.text('أمر شراء جديد'), findsOneWidget);
    expect(find.text('بيانات أمر الشراء'), findsOneWidget);
    expect(find.text('المورد'), findsOneWidget);
    expect(find.text('المستلم'), findsOneWidget);
    expect(find.text('مصاريف النقل'), findsOneWidget);
    await tester.ensureVisible(find.text('إضافة بند'));
    await tester.tap(find.text('إضافة بند'));
    await tester.pumpAndSettle();
    expect(find.text('سعر الوحدة *'), findsOneWidget);
    expect(find.text('حفظ الأمر'), findsOneWidget);
  });

  testWidgets('cash buyer can open invoice form with attachments', (
    tester,
  ) async {
    await pump(
      tester,
      ScmDocumentsScreen(
        repository: _FakeScmRepository(),
        kind: ScmDocumentKind.cashPurchases,
        permissions: const {
          'SCM_CASH_PURCHASES_CREATE',
          'CUSTODY_EXPENSE_CREATE',
        },
      ),
    );

    expect(find.text('فاتورة جديدة'), findsOneWidget);
    await tester.tap(find.text('فاتورة جديدة'));
    await tester.pumpAndSettle();
    expect(find.text('فاتورة شراء نقدي جديدة'), findsOneWidget);
    expect(find.text('بند الصرف *'), findsOneWidget);
    expect(find.text('رقم الفاتورة'), findsOneWidget);
    expect(find.text('مصاريف النقل'), findsOneWidget);
    expect(find.text('إرفاق صور الفاتورة'), findsOneWidget);
    expect(find.text('حفظ الفاتورة'), findsOneWidget);
  });

  testWidgets('materials screen opens complete add material form', (
    tester,
  ) async {
    await pump(
      tester,
      ScmMaterialsScreen(
        repository: _FakeScmRepository(),
        canManage: true,
        catalogAccess: true,
      ),
    );

    expect(find.text('الخامات'), findsOneWidget);
    expect(find.text('أسمنت بورتلاندي'), findsOneWidget);
    expect(find.text('خامة جديدة'), findsOneWidget);
    await tester.tap(find.text('خامة جديدة'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة خامة'), findsOneWidget);
    expect(find.text('كود الخامة *'), findsOneWidget);
    expect(find.text('اسم الخامة *'), findsOneWidget);
    expect(find.text('الوحدة الأساسية *'), findsOneWidget);
    expect(find.text('الخامة نشطة'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/scm_add_material_390x844.png'),
    );
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

ApiClient _client() => ApiClient(dio: Dio(), cookieJar: CookieJar());

class _FakeWorkflowRepository extends WorkflowRepository {
  _FakeWorkflowRepository() : super(_client());

  int actionCount = 0;

  static const row = WorkflowInboxRow(
    docType: 'PURCHASE_REQUEST',
    docTypeName: 'طلب شراء',
    docId: 'request-1',
    number: 'PR-104',
    title: 'خامات مشروع العاصمة',
    amount: '125000',
    step: 'مراجعة مدير المشروع',
    submittedBy: WorkflowPerson(id: 'user-1', name: 'م. أحمد حسن'),
    submittedAt: '2026-11-21T09:00:00Z',
    waitingSince: '2026-11-21T09:00:00Z',
  );

  @override
  Future<WorkflowInbox> inbox({
    String stage = 'APPROVAL',
    bool all = false,
    int page = 0,
    int size = 20,
  }) async => WorkflowInbox(
    items: stage == 'APPROVAL' ? const [row] : const [],
    total: stage == 'APPROVAL' ? 1 : 0,
    page: page,
    size: size,
  );

  @override
  Future<WorkflowInboxCount> count() async =>
      const WorkflowInboxCount(count: 1, awaitingCompletion: 2);

  @override
  Future<WorkflowState> state(
    String docType,
    String docId,
  ) async => const WorkflowState(
    status: 'PENDING',
    currentStep: 'مراجعة مدير المشروع',
    actions: [
      WorkflowAction(code: 'APPROVE', label: 'موافقة', commentRequired: false),
      WorkflowAction(code: 'REJECT', label: 'رفض', commentRequired: true),
      WorkflowAction(
        code: 'WITHDRAW',
        label: 'سحب الطلب',
        commentRequired: false,
      ),
    ],
    steps: [
      WorkflowStep(
        name: 'مراجعة مدير المشروع',
        status: 'CURRENT',
        approvers: ['دور: مدير المشروع'],
        waitingFor: [WorkflowPerson(id: 'manager-1', name: 'المدير الحالي')],
      ),
      WorkflowStep(
        name: 'اعتماد المشتريات',
        status: 'WAITING',
        approvers: ['دور: مدير المشتريات'],
        waitingFor: [],
      ),
    ],
    history: [],
  );

  @override
  Future<WorkflowState> act({
    required String docType,
    required String docId,
    required String action,
    String? comment,
  }) async {
    actionCount++;
    return state(docType, docId);
  }
}

class _FakeScmRepository extends ScmRepository {
  _FakeScmRepository({this.draft = false}) : super(_client());

  final bool draft;

  static const warehouse = ScmRef(
    id: 'warehouse-1',
    code: 'WH-01',
    name: 'مخزن مشروع العاصمة',
  );

  @override
  Future<ScmPage<ScmDocumentSummary>> documents(
    ScmDocumentKind kind, {
    int page = 0,
    int size = 20,
  }) async => ScmPage(
    items: [
      ScmDocumentSummary(
        id: 'request-1',
        documentNo: 'PR-104',
        date: '2026-11-21',
        status: draft ? 'DRAFT' : 'SUBMITTED',
        warehouse: warehouse,
        party: 'م. أحمد حسن',
        lineCount: 3,
      ),
    ],
    total: 1,
    page: page,
    size: size,
  );

  @override
  Future<ScmDocumentDetail> document(ScmDocumentKind kind, String id) async =>
      ScmDocumentDetail(
        id: id,
        documentNo: 'PR-104',
        date: '2026-11-21',
        status: draft ? 'DRAFT' : 'SUBMITTED',
        warehouse: warehouse,
        party: 'م. أحمد حسن',
        notes: 'توريد عاجل',
        total: '5100.00',
        transportCost: '100.00',
        currency: 'EGP',
        pricesVisible: true,
        needDate: '2026-11-28',
        lines: const [
          ScmDocumentLine(
            id: 'line-1',
            material: ScmRef(
              id: 'material-1',
              code: 'MAT-01',
              name: 'أسمنت بورتلاندي',
            ),
            unitRef: ScmRef(id: 'unit-1', code: 'TON', name: 'طن'),
            description: 'أسمنت بورتلاندي',
            unit: 'طن',
            quantity: '10',
            unitPrice: '500.00',
            total: '5000.00',
          ),
        ],
        version: 2,
      );

  @override
  Future<ScmOptions> options() async => const ScmOptions(
    warehouses: [warehouse],
    members: [ScmRef(id: 'member-1', name: 'م. أحمد حسن')],
    suppliers: [ScmRef(id: 'supplier-1', name: 'شركة النيل للتوريدات')],
    expenseCategories: [ScmRef(id: 'category-1', name: 'خامات')],
    materials: [
      ScmMaterial(
        id: 'material-1',
        code: 'MAT-01',
        name: 'أسمنت بورتلاندي',
        units: [ScmMaterialUnit(id: 'unit-1', code: 'TON', name: 'طن')],
      ),
    ],
  );

  @override
  Future<List<ScmStockBalance>> stock() async => const [
    ScmStockBalance(
      warehouse: warehouse,
      material: ScmRef(id: 'material-1', name: 'أسمنت بورتلاندي'),
      unit: ScmRef(id: 'unit-1', name: 'طن'),
      quantity: '1250',
    ),
  ];

  @override
  Future<List<ScmCatalogMaterial>> materials({
    required bool catalogAccess,
  }) async => const [
    ScmCatalogMaterial(
      id: 'material-1',
      code: 'CEM-001',
      name: 'أسمنت بورتلاندي',
      baseUnit: ScmRef(id: 'unit-1', code: 'KG', name: 'كيلوجرام'),
      description: 'أسمنت للاستخدامات الخرسانية وأعمال المباني',
      active: true,
      conversions: [
        ScmMaterialConversion(
          id: 'conversion-1',
          unit: ScmRef(id: 'unit-1', code: 'KG', name: 'كيلوجرام'),
          conversionToBase: '1',
          version: 1,
        ),
        ScmMaterialConversion(
          id: 'conversion-2',
          unit: ScmRef(id: 'unit-2', code: 'BAG', name: 'شيكارة'),
          conversionToBase: '50',
          purchaseIncrement: '1',
          version: 1,
        ),
      ],
      version: 2,
    ),
  ];

  @override
  Future<List<ScmRef>> units() async => const [
    ScmRef(id: 'unit-1', code: 'KG', name: 'كيلوجرام'),
    ScmRef(id: 'unit-2', code: 'BAG', name: 'شيكارة'),
    ScmRef(id: 'unit-3', code: 'TON', name: 'طن'),
  ];
}
