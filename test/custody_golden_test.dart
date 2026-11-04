import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';
import 'package:fundflow_mob/core/widgets/app_pagination.dart';
import 'package:fundflow_mob/core/widgets/app_refresh_page.dart';
import 'package:fundflow_mob/features/custody/data/custody_repository.dart';
import 'package:fundflow_mob/features/custody/domain/custody_models.dart';
import 'package:fundflow_mob/features/custody/presentation/custody_screen.dart';
import 'package:fundflow_mob/features/custody/presentation/custody_request_screen.dart';
import 'package:fundflow_mob/features/custody/presentation/aggregate_custody_screen.dart';
import 'package:fundflow_mob/features/custody/presentation/dashboard_screen.dart';
import 'package:fundflow_mob/features/treasury/data/treasury_repository.dart';
import 'package:fundflow_mob/features/treasury/domain/treasury_models.dart';

void main() {
  setUpAll(_loadFonts);

  testWidgets('pagination numbers pages and jumps across gaps', (tester) async {
    _setPhone(tester);
    var selected = -1;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        builder: _rtlBuilder,
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: AppPagination(
              page: 0,
              size: 20,
              total: 148,
              onChanged: (page) => selected = page,
            ),
          ),
        ),
      ),
    );
    expect(find.text('1–20 من 148 · صفحة 1 من 8'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('5'), findsNothing);
    await tester.tap(find.text('2'));
    expect(selected, 1);
    await tester.tap(find.text('…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '6');
    await tester.tap(find.text('انتقال'));
    await tester.pumpAndSettle();
    expect(selected, 5);
  });

  testWidgets('landscape pages keep scroll space above the keyboard', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        builder: _rtlBuilder,
        theme: AppTheme.light(),
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: AppRefreshPage(
            onRefresh: () async {},
            children: const [
              SizedBox(height: 420),
              TextField(decoration: InputDecoration(labelText: 'البيان')),
            ],
          ),
        ),
      ),
    );

    final list = tester.widget<ListView>(find.byType(ListView));
    final padding = list.padding!.resolve(TextDirection.rtl);
    expect(padding.bottom, 196);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard mobile visual', (tester) async {
    _setPhone(tester);
    final repository = _FakeCustodyRepository();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        builder: _rtlBuilder,
        theme: AppTheme.light(),
        home: Scaffold(
          body: DashboardScreen(
            repository: repository,
            onOpenAggregate: () {},
            onOpenCustody: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('تحديث'), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(
      tester.widget<ListView>(find.byType(ListView)).physics,
      isA<AlwaysScrollableScrollPhysics>(),
    );
    expect(repository.dashboardCalls, 1);
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(repository.dashboardCalls, 2);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/dashboard_390x844.png'),
    );
  });

  testWidgets('custody screen shows balance, actions and the ledger table', (
    tester,
  ) async {
    _setPhone(tester);
    await tester.pumpWidget(_app(_custody()));
    await tester.pumpAndSettle();
    expect(find.text('العهدة'), findsOneWidget);
    expect(find.text('الرصيد الحالي'), findsOneWidget);
    expect(find.text('إضافة بند'), findsOneWidget);
    expect(find.text('طلب عهدة'), findsOneWidget);
    expect(find.text('تحويل'), findsOneWidget);
    expect(find.text('الحركات'), findsOneWidget);
    expect(find.text('التحويلات'), findsOneWidget);
    // Snag is for managers only and never reaches the employee's screen.
    expect(find.byIcon(LucideIcons.flag), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
      findsOneWidget,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/custody_390x844.png'),
    );

    await tester.tap(find.text('الفلاتر'));
    await tester.pumpAndSettle();
    expect(find.text('عدد الصفوف'), findsOneWidget);
    expect(find.text('عرض النتائج'), findsOneWidget);
    expect(find.text('المقاول'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/custody_filters_390x844.png'),
    );
  });

  testWidgets('own custody details are read-only', (tester) async {
    _setPhone(tester);
    await tester.pumpWidget(_app(_custody()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('شراء مستلزمات للموقع'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل بند العهدة'), findsOneWidget);
    expect(find.text('الاعتماد والتصفية'), findsOneWidget);
    expect(find.text('إجراءات المراجعة'), findsNothing);
    expect(find.text('رفض البند'), findsNothing);
  });

  testWidgets('transfers are received from the transfers tab', (tester) async {
    _setPhone(tester);
    await tester.pumpWidget(_app(_custody()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التحويلات'));
    await tester.pumpAndSettle();
    expect(find.text('وارد من محمد علي'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'استلام'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/custody_transfers_390x844.png'),
    );
    await tester.tap(find.text('تحويل'));
    await tester.pumpAndSettle();
    expect(find.text('إرسال التحويل'), findsOneWidget);
    expect(find.text('صورة التحويل *'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/custody_transfer_390x844.png'),
    );
  });

  testWidgets('aggregate marks Snag and rejected rows and opens actions', (
    tester,
  ) async {
    _setPhone(tester);
    await tester.pumpWidget(
      _app(
        AggregateCustodyScreen(
          repository: _FakeCustodyRepository(),
          currentUserId: 'manager-1',
          permissions: const {
            'CUSTODY_COMPANY_VIEW',
            'CUSTODY_EXPENSE_REVIEW',
            'CUSTODY_CORRECT',
            'CUSTODY_EXPENSE_ON_BEHALF',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('مجمع العهد'), findsOneWidget);
    expect(find.text('صرف باسم موظف'), findsOneWidget);
    expect(find.byIcon(LucideIcons.flag), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/aggregate_390x844.png'),
    );

    await tester.tap(find.text('شراء مستلزمات للموقع'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل بند العهدة'), findsOneWidget);
    expect(find.text('إجراءات المراجعة'), findsOneWidget);
    expect(find.text('تعديل البند'), findsOneWidget);
    expect(find.text('تعليم Snag'), findsOneWidget);
    expect(find.text('رفض البند'), findsOneWidget);
    expect(find.text('تصحيح إداري'), findsOneWidget);
    await tester.drag(find.text('الاعتماد والتصفية'), const Offset(0, -400));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/custody_details_390x844.png'),
    );

    await tester.tap(find.text('تصحيح إداري'));
    await tester.pumpAndSettle();
    expect(find.text('المبلغ الصحيح *'), findsOneWidget);
    expect(find.text('التاريخ الصحيح *'), findsOneWidget);
    expect(find.text('سبب التصحيح *'), findsOneWidget);
    expect(find.text('حفظ التصحيح'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/custody_correction_390x844.png'),
    );
  });

  testWidgets('aggregate filters include the manager-only fields', (
    tester,
  ) async {
    _setPhone(tester);
    await tester.pumpWidget(
      _app(
        AggregateCustodyScreen(
          repository: _FakeCustodyRepository(),
          currentUserId: 'manager-1',
          permissions: const {'CUSTODY_COMPANY_VIEW', 'CUSTODY_EXPENSE_REVIEW'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('الفلاتر'));
    await tester.pumpAndSettle();
    for (final label in ['الموظف', 'المقاول', 'التصفية', 'علامة Snag']) {
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    await tester.tap(find.text('كل الموظفين'));
    await tester.pumpAndSettle();
    expect(find.text('ابحث بالاسم أو الكود…'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'يوسف');
    await tester.pumpAndSettle();
    expect(find.text('موظف رقم 8 يوسف'), findsOneWidget);
    expect(find.text('موظف رقم 0 أحمد'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/aggregate_filters_390x844.png'),
    );
  });

  testWidgets('managers review and fund requests from cards', (tester) async {
    _setPhone(tester);
    await tester.pumpWidget(
      _app(
        CustodyRequestScreen(
          repository: _FakeCustodyRepository(),
          treasury: _FakeTreasuryRepository(),
          permissions: const {
            'CUSTODY_REQUEST_VIEW',
            'CUSTODY_REQUEST_APPROVE',
            'TREASURY_OPERATE',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('طلبات العهدة'), findsOneWidget);
    expect(find.text('موافقة'), findsOneWidget);
    expect(find.text('صرف من الخزنة'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/custody_request_390x844.png'),
    );

    await tester.tap(find.text('صرف من الخزنة'));
    await tester.pumpAndSettle();
    expect(find.text('صرف طلب العهدة'), findsOneWidget);
    expect(find.text('الخزينة الرئيسية'), findsOneWidget);
    expect(find.text('تسجيل الصرف'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/custody_fund_390x844.png'),
    );
  });

  testWidgets('employees request custody from the custody screen', (
    tester,
  ) async {
    _setPhone(tester);
    await tester.pumpWidget(_app(_custody()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('طلب عهدة'));
    await tester.pumpAndSettle();
    expect(find.text('إرسال الطلب'), findsOneWidget);
    expect(find.text('الموقع *'), findsOneWidget);
  });
}

Widget _custody() => CustodyScreen(
  repository: _FakeCustodyRepository(),
  ownerId: 'user-1',
  currentUserId: 'user-1',
  permissions: const {
    'CUSTODY_SELF_VIEW',
    'CUSTODY_EXPENSE_CREATE',
    'CUSTODY_REQUEST_CREATE',
    'CUSTODY_TRANSFER',
  },
);

Widget _app(Widget screen) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('ar'),
  builder: _rtlBuilder,
  theme: AppTheme.light(),
  home: Scaffold(body: screen),
);

Widget _rtlBuilder(BuildContext context, Widget? child) => Directionality(
  textDirection: TextDirection.rtl,
  child: child ?? const SizedBox.shrink(),
);

void _setPhone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
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

class _FakeCustodyRepository extends CustodyRepository {
  _FakeCustodyRepository()
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  int dashboardCalls = 0;

  @override
  Future<DashboardData> dashboard() async {
    dashboardCalls++;
    return const DashboardData(
      memberCount: 48,
      custodyOwnerCount: 12,
      totalFunding: '425000.00',
      approvedAmount: '286450.50',
      remaining: '138549.50',
      unpaidRequestCount: 3,
      unpaidRequestAmount: '45000.00',
      companyCash: [CompanyCash('EGP', 'ج.م', '720000.00')],
      owners: [
        CustodyOwner(
          id: 'user-1',
          custodyId: 'custody-1',
          name: 'أحمد محمد',
          code: 'EMP-014',
          active: true,
          lastSettledAt: '2026-10-20T12:00:00Z',
          totalFunding: '50000.00',
          approved: '32500.00',
          remaining: '17500.00',
        ),
        CustodyOwner(
          id: 'user-2',
          custodyId: 'custody-2',
          name: 'محمد علي',
          code: 'EMP-021',
          active: true,
          lastSettledAt: null,
          totalFunding: '40000.00',
          approved: '22150.00',
          remaining: '17850.00',
        ),
      ],
    );
  }

  @override
  Future<CustodyBalance> balance([String? ownerId]) async =>
      const CustodyBalance(
        remaining: '17500.00',
        pendingIncoming: '2500.00',
        pendingOutgoing: '1200.00',
      );

  @override
  Future<PageData<LedgerItem>> ledger({
    String? ownerId,
    bool aggregate = false,
    int page = 0,
    int size = 20,
    ExpenseFilterState filters = const ExpenseFilterState(),
  }) async => const PageData([
    LedgerItem(
      id: '1',
      ownerName: 'أحمد محمد',
      entryDate: '2026-10-24',
      amount: '1450.00',
      description: 'شراء مستلزمات للموقع',
      center: 'مشروع العاصمة',
      category: 'خامات / مستلزمات',
      contractor: 'فاتورة',
      approval: 'اعتماد تلقائي',
      settlement: 'غير مصفّى',
      kind: LedgerKind.expense,
    ),
    LedgerItem(
      id: '2',
      ownerName: 'أحمد محمد',
      entryDate: '2026-10-22',
      amount: '+5000.00',
      description: 'تمويل عهدة',
      center: '—',
      category: '—',
      contractor: '—',
      approval: '—',
      settlement: '—',
      kind: LedgerKind.funding,
    ),
    LedgerItem(
      id: '3',
      ownerName: 'كريم يوسف',
      entryDate: '2026-10-21',
      amount: '4500.00',
      description: 'مصنعية تركيب شدات خشبية',
      center: 'برج الياسمين',
      category: 'مصنعيات / نجارة',
      contractor: 'النور للنجارة',
      approval: 'مرفوض',
      settlement: 'غير مصفّى',
      kind: LedgerKind.expense,
      status: 'REJECTED',
    ),
    LedgerItem(
      id: '4',
      ownerName: 'سامح رضا',
      entryDate: '2026-10-20',
      amount: '640.00',
      description: 'وجبات عمال الوردية الليلية',
      center: 'برج الياسمين',
      category: 'إعاشة',
      contractor: 'فاتورة',
      approval: 'م. خالد سمير',
      settlement: 'غير مصفّى',
      kind: LedgerKind.expense,
      isSnag: true,
    ),
    LedgerItem(
      id: '5',
      ownerName: 'محمد علي ← أحمد محمد',
      entryDate: '2026-10-19',
      amount: '3500.00',
      description: 'تحويل عهدة',
      center: '—',
      category: 'تحويل عهدة',
      contractor: '—',
      approval: 'بانتظار الاستلام',
      settlement: '—',
      kind: LedgerKind.transfer,
      senderId: 'user-2',
      recipientId: 'user-1',
    ),
  ], 148);

  @override
  Future<ExpenseFilters> expenseFilters({String? ownerId}) async =>
      ExpenseFilters(
        people: [
          for (final (i, name) in const [
            'أحمد',
            'محمود',
            'سامح',
            'كريم',
            'هشام',
            'خالد',
            'عمرو',
            'طارق',
            'يوسف',
            'مصطفى',
            'علي',
            'حسن',
          ].indexed)
            ExpenseFilterOption(
              id: 'user-$i',
              name: 'موظف رقم $i $name',
              active: true,
            ),
        ],
        centers: [
          ExpenseFilterOption(
            id: 'site-1',
            name: 'مشروع العاصمة',
            active: true,
          ),
        ],
        categories: [
          ExpenseFilterOption(id: 'category-1', name: 'خامات', active: true),
        ],
        contractors: const [
          ExpenseFilterOption(
            id: 'contractor-1',
            name: 'مؤسسة الفتح للمقاولات',
            active: true,
          ),
        ],
        today: '2026-10-25',
      );

  @override
  Future<LedgerItem> expense(String id) async => const LedgerItem(
    id: '1',
    ownerId: 'user-1',
    ownerName: 'أحمد محمد',
    centerId: 'site-1',
    center: 'مشروع العاصمة',
    categoryId: 'category-1',
    category: 'خامات',
    entryDate: '2026-10-24',
    amount: '1450.00',
    description: 'شراء مستلزمات للموقع',
    contractor: 'فاتورة',
    approval: 'اعتماد تلقائي',
    settlement: 'غير مصفّى',
    kind: LedgerKind.expense,
    status: 'APPROVED',
    evidenceType: 'INVOICE',
    approvedAt: '2026-10-24T10:00:00Z',
    createdAt: '2026-10-24T10:00:00Z',
    updatedAt: '2026-10-24T10:00:00Z',
    version: 1,
  );

  @override
  Future<List<NamedOption>> requestSites() async => const [
    NamedOption(id: 'site-1', name: 'مشروع العاصمة', code: 'PRJ-01'),
  ];

  @override
  Future<PageData<CustodyRequestItem>> requests({
    int page = 0,
    int size = 20,
    bool unpaid = false,
    bool mine = false,
  }) async => const PageData([
    CustodyRequestItem(
      id: 'request-1',
      requesterName: 'أحمد محمد',
      centerName: 'مشروع العاصمة',
      amount: '12000.00',
      description: 'احتياجات تشغيل الموقع',
      createdAt: '2026-10-24T10:00:00Z',
      status: 'PENDING',
      reviewerName: null,
      reviewedAt: null,
      reviewReason: null,
    ),
    CustodyRequestItem(
      id: 'request-2',
      requesterId: 'user-2',
      requesterName: 'محمود عادل',
      centerName: 'برج الياسمين',
      amount: '20000.00',
      description: 'تمويل أعمال الخرسانة للدور الخامس',
      createdAt: '2026-10-23T09:00:00Z',
      status: 'APPROVED',
      reviewerName: 'م. خالد سمير',
      reviewedAt: '2026-10-23T15:20:00Z',
      reviewReason: null,
    ),
    CustodyRequestItem(
      id: 'request-3',
      requesterName: 'سامح رضا',
      centerName: 'المكتب الرئيسي',
      amount: '3000.00',
      description: 'مصاريف إدارية',
      createdAt: '2026-10-15T09:00:00Z',
      status: 'REJECTED',
      reviewerName: 'أ. هشام فؤاد',
      reviewedAt: '2026-10-16T09:40:00Z',
      reviewReason: 'يتم الصرف من خزينة المكتب مباشرة.',
    ),
  ], 3);

  @override
  Future<List<NamedOption>> transferRecipients() async => const [
    NamedOption(id: 'user-2', name: 'محمد علي', code: 'EMP-021'),
  ];

  @override
  Future<PageData<CustodyTransferItem>> transfers({
    int page = 0,
    int size = 20,
    bool pendingOnly = false,
  }) async => const PageData([
    CustodyTransferItem(
      id: 'transfer-1',
      senderId: 'user-2',
      senderName: 'محمد علي',
      recipientId: 'user-1',
      recipientName: 'أحمد محمد',
      amount: '3500.00',
      description: 'تحويل لتغطية مصروفات الموقع',
      createdAt: '2026-10-24T10:00:00Z',
      receivedAt: null,
    ),
  ], 1);
}

class _FakeTreasuryRepository extends TreasuryRepository {
  _FakeTreasuryRepository()
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  @override
  Future<List<TreasuryAccount>> list() async => const [
    TreasuryAccount(
      id: 'treasury-1',
      code: 'TR-01',
      name: 'الخزينة الرئيسية',
      currencyCode: 'EGP',
      defaultTreasury: true,
      active: true,
      balance: '720000.00',
      version: 1,
    ),
  ];
}
