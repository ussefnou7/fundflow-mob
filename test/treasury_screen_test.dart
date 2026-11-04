import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';
import 'package:fundflow_mob/features/custody/data/custody_repository.dart';
import 'package:fundflow_mob/features/custody/domain/custody_models.dart';
import 'package:fundflow_mob/features/treasury/data/treasury_repository.dart';
import 'package:fundflow_mob/features/treasury/domain/treasury_models.dart';
import 'package:fundflow_mob/features/treasury/presentation/treasury_screen.dart';

void main() {
  setUpAll(_loadFonts);

  testWidgets('treasury movement type changes its conditional fields', (
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
            body: TreasuryScreen(
              repository: _FakeTreasuryRepository(),
              custody: _FakeCustodyRepository(),
              permissions: const {
                'TREASURY_VIEW',
                'TREASURY_OPERATE',
                'TREASURY_APPROVE',
                'INTERCOMPANY_VIEW',
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('الرصيد المعتمد'), findsOneWidget);
    expect(find.text('EGP'), findsOneWidget);
    expect(find.text('حركات الخزنة'), findsOneWidget);
    expect(find.text('كشف الحساب'), findsOneWidget);
    expect(find.text('سلف'), findsOneWidget);
    expect(find.text('مساهمات'), findsOneWidget);
    expect(tester.getTopLeft(find.text('مساهمات')).dx, greaterThanOrEqualTo(0));
    expect(tester.getTopRight(find.text('مساهمات')).dx, lessThanOrEqualTo(390));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/treasury_390x844.png'),
    );

    await tester.tap(find.text('كشف الحساب'));
    await tester.pumpAndSettle();
    expect(find.text('الرصيد الافتتاحي'), findsOneWidget);
    expect(find.text('الوارد'), findsOneWidget);
    expect(find.text('الرصيد الختامي'), findsOneWidget);
    expect(find.text('50,000.00 EGP'), findsWidgets);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/treasury_ledger_390x844.png'),
    );

    await tester.tap(find.text('حركات الخزنة'));
    await tester.pumpAndSettle();

    // Movements open in a sheet where managers approve with an optional note.
    await tester.tap(find.text('إيداع بالخزنة').last);
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل حركة الخزنة'), findsOneWidget);
    expect(find.text('اعتماد الحركة'), findsOneWidget);
    expect(find.text('ملاحظة اختيارية'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/treasury_detail_390x844.png'),
    );
    await tester.tap(find.text('رفض'));
    await tester.pumpAndSettle();
    expect(find.text('سبب الرفض *'), findsOneWidget);
    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('حركة جديدة'));
    await tester.pumpAndSettle();
    expect(find.text('مركز التكلفة (اختياري)'), findsOneWidget);
    expect(find.text('نوع الإيداع (اختياري)'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/treasury_movement_390x844.png'),
    );

    await tester.tap(find.text('صرف مباشر').last);
    await tester.pumpAndSettle();
    expect(find.text('بند الصرف'), findsOneWidget);
    expect(find.text('نوع المستند'), findsOneWidget);

    await tester.tap(find.text('تحويل بين الخزن'));
    await tester.pumpAndSettle();
    expect(find.text('الخزنة المستقبلة'), findsOneWidget);
    expect(find.text('بند الصرف'), findsNothing);

    await tester.tap(find.text('تحويل إلى عهدة').last);
    await tester.pumpAndSettle();
    expect(find.text('صاحب العهدة'), findsOneWidget);

    await tester.tap(find.text('رد إلى الخزنة').last);
    await tester.pumpAndSettle();
    expect(find.text('طريقة الاستلام'), findsOneWidget);

    await tester.tap(find.text('تصحيح رصيد').last);
    await tester.pumpAndSettle();
    expect(find.text('طريقة الدفع'), findsNothing);
    expect(find.text('طريقة الاستلام'), findsNothing);
  });

  testWidgets('quick actions and intercompany content use mobile cards', (
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
            body: TreasuryScreen(
              repository: _FakeTreasuryRepository(),
              custody: _FakeCustodyRepository(),
              permissions: const {
                'TREASURY_VIEW',
                'TREASURY_OPERATE',
                'TREASURY_APPROVE',
                'INTERCOMPANY_VIEW',
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('إجراءات سريعة'));
    await tester.pumpAndSettle();
    expect(find.text('إضافة صرف مباشر'), findsOneWidget);
    expect(find.text('رد إلى الخزنة'), findsOneWidget);
    expect(find.text('تحويل إلى عهدة'), findsOneWidget);
    expect(find.text('إيداع بالخزنة'), findsWidgets);
    expect(find.text('تصحيح رصيد'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/treasury_quick_actions_390x844.png'),
    );
    await tester.tap(find.text('إخفاء الإجراءات'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('سلف'));
    await tester.pumpAndSettle();
    expect(find.text('سلفة جديدة'), findsOneWidget);
    expect(find.text('الإدارة المالية'), findsOneWidget);
    expect(find.text('من سكاي هاوس'), findsOneWidget);
    expect(find.text('تسجيل دفعة'), findsOneWidget);
    expect(find.text('المتبقي'), findsOneWidget);

    await tester.tap(find.text('مساهمات'));
    await tester.pumpAndSettle();
    expect(find.text('مساهمة جديدة'), findsOneWidget);
    expect(find.text('مساهمة'), findsOneWidget);
    expect(find.textContaining('مستحقات الإدارة المالية'), findsOneWidget);
    expect(find.text('عكس الحركة'), findsOneWidget);

    await tester.ensureVisible(find.text('عكس الحركة'));
    await tester.tap(find.text('عكس الحركة'));
    await tester.pumpAndSettle();
    expect(find.text('عكس التحويل'), findsOneWidget);
    expect(find.text('التاريخ *'), findsOneWidget);
    expect(find.text('السبب *'), findsOneWidget);
    expect(find.text('تأكيد العكس'), findsOneWidget);
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

class _FakeTreasuryRepository extends TreasuryRepository {
  _FakeTreasuryRepository()
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  @override
  Future<List<TreasuryAccount>> list() async => const [
    TreasuryAccount(
      id: 'treasury-1',
      code: 'TR-001',
      name: 'سكاى هاوس',
      currencyCode: 'EGP',
      defaultTreasury: true,
      active: true,
      balance: '50000.00',
      version: 1,
    ),
    TreasuryAccount(
      id: 'treasury-2',
      code: 'TR-002',
      name: 'خزنة الموقع',
      currencyCode: 'EGP',
      defaultTreasury: false,
      active: true,
      balance: '10000.00',
      version: 1,
    ),
  ];

  @override
  Future<TreasuryMovementPage> movements({
    required String treasuryId,
    String status = '',
    int page = 0,
    int size = 20,
  }) async => TreasuryMovementPage(
    items: const [
      TreasuryMovement(
        id: 'movement-1',
        treasuryId: 'treasury-1',
        treasuryName: 'سكاى هاوس',
        type: 'DEPOSIT',
        status: 'PENDING',
        method: 'CASH',
        amount: '5000.00',
        entryDate: '2026-10-26',
        description: 'إيداع نقدي بالخزنة',
        recipientName: 'أحمد محمد',
        creatorName: 'Nou7',
        version: 1,
      ),
    ],
    total: 1,
    page: page,
    size: size,
  );

  @override
  Future<DirectExpenseOptions> expenseOptions() async =>
      const DirectExpenseOptions(
        centers: [
          ExpenseReference(id: 'center-1', name: 'مشروع العاصمة', code: 'CC-1'),
        ],
        categories: [
          ExpenseReference(
            id: 'category-1',
            name: 'توريدات كهرباء',
            code: 'EXP-1',
          ),
        ],
        contractors: [
          ExpenseReference(id: 'contractor-1', name: 'بيومي', code: 'CON-1'),
        ],
        today: '2026-10-26',
      );

  @override
  Future<TreasuryLedgerPage> ledger({
    required String treasuryId,
    String direction = '',
    int page = 0,
    int size = 20,
  }) async => TreasuryLedgerPage(
    items: const [
      TreasuryLedgerEntry(
        operationId: 'operation-1',
        referenceNo: 'TRX-001',
        type: 'DEPOSIT',
        status: 'POSTED',
        direction: 'IN',
        amount: '5000.00',
        currencyCode: 'EGP',
        balanceAfter: '50000.00',
        entryDate: '2026-10-26',
        description: 'إيداع نقدي',
      ),
    ],
    total: 1,
    page: page,
    size: size,
  );

  @override
  Future<TreasuryLedgerSummary> ledgerSummary({
    required String treasuryId,
  }) async => const TreasuryLedgerSummary(
    currencyCode: 'EGP',
    openingBalance: '45000.00',
    inflows: '5000.00',
    outflows: '0',
    closingBalance: '50000.00',
  );

  @override
  Future<IntercompanyOptions> intercompanyOptions() async =>
      const IntercompanyOptions(
        activeCompanyId: 'company-1',
        today: '2026-10-31',
        companies: [
          IntercompanyCompanyOption(
            id: 'company-1',
            code: 'SKY',
            name: 'سكاي هاوس',
            canApprove: true,
            canRequest: true,
            treasuries: [
              IntercompanyTreasuryOption(
                id: 'treasury-1',
                code: 'TR-001',
                name: 'الخزنة الرئيسية',
                currencyCode: 'EGP',
              ),
            ],
          ),
          IntercompanyCompanyOption(
            id: 'company-2',
            code: 'FIN',
            name: 'الإدارة المالية',
            canApprove: true,
            canRequest: true,
            treasuries: [
              IntercompanyTreasuryOption(
                id: 'treasury-3',
                code: 'TR-003',
                name: 'خزنة المالية',
                currencyCode: 'EGP',
              ),
            ],
          ),
        ],
      );

  @override
  Future<IntercompanyLoanPage> loans({int page = 0, int size = 20}) async =>
      IntercompanyLoanPage(
        items: const [
          IntercompanyLoan(
            id: 'loan-1',
            lenderCompanyId: 'company-1',
            lenderCompanyName: 'سكاي هاوس',
            borrowerCompanyId: 'company-2',
            borrowerCompanyName: 'الإدارة المالية',
            currencyCode: 'EGP',
            principalAmount: '71024.00',
            principalOutstanding: '51024.00',
            status: 'PARTIALLY_REPAID',
            purpose: 'تمويل تشغيل',
            disbursedOn: '2026-09-13',
          ),
        ],
        total: 1,
        page: page,
        size: size,
      );

  @override
  Future<IntercompanyTransferPage> contributions({
    int page = 0,
    int size = 20,
  }) async => IntercompanyTransferPage(
    items: const [
      IntercompanyTransfer(
        id: 'transfer-1',
        from: IntercompanySide(
          companyId: 'company-1',
          companyName: 'سكاي هاوس',
          treasuryId: 'treasury-1',
          treasuryName: 'الخزنة الرئيسية',
          amount: '3000.00',
          currencyCode: 'EGP',
        ),
        to: IntercompanySide(
          companyId: 'company-2',
          companyName: 'الإدارة المالية',
          treasuryId: 'treasury-3',
          treasuryName: 'خزنة المالية',
          amount: '3000.00',
          currencyCode: 'EGP',
        ),
        purpose: 'CONTRIBUTION',
        status: 'EXECUTED',
        entryDate: '2026-10-16',
        description: 'مستحقات الإدارة المالية',
      ),
    ],
    total: 1,
    page: page,
    size: size,
  );
}

class _FakeCustodyRepository extends CustodyRepository {
  _FakeCustodyRepository()
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  @override
  Future<ExpenseOptions> expenseOptions({String? ownerId}) async =>
      const ExpenseOptions(
        centers: [],
        categories: [],
        contractors: [],
        people: [
          CustodyPerson(
            id: 'user-1',
            name: 'أحمد محمد',
            code: 'EMP-1',
            active: true,
            custodyId: 'custody-1',
          ),
        ],
        subCategories: [],
        costDetailsEnabled: true,
        today: '2026-10-26',
        custodyId: null,
      );
}
