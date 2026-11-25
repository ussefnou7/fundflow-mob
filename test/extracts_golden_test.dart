import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';
import 'package:fundflow_mob/features/extracts/data/extract_repository.dart';
import 'package:fundflow_mob/features/extracts/domain/extract_models.dart';
import 'package:fundflow_mob/features/extracts/presentation/contractor_extract_screen.dart';
import 'package:fundflow_mob/features/settings/domain/settings_models.dart';

void main() {
  setUpAll(_loadFonts);

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Set<String> permissions,
    required bool financialsVisible,
  }) async {
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
            body: SafeArea(
              child: ContractorExtractScreen(
                repository: _FakeExtractRepository(financialsVisible),
                permissions: permissions,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('المقاول أحمد').first);
    await tester.pumpAndSettle();
  }

  testWidgets('manager sees pending measurement and added line', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      financialsVisible: true,
      permissions: const {
        'CONTRACTOR_EXTRACT_VIEW',
        'CONTRACTOR_EXTRACT_CREATE',
        'CONTRACTOR_EXTRACT_APPROVE',
        'CONTRACTOR_EXTRACT_PRICES',
        'CONTRACTOR_EXTRACT_CLIENT_PRICE',
      },
    );

    expect(find.text('مستخلصات المقاولين'), findsOneWidget);
    expect(find.text('مستخلص جديد'), findsOneWidget);
    expect(find.text('بانتظار الاعتماد (2)'), findsOneWidget);
    expect(find.text('← 80% معلّق'), findsOneWidget);
    expect(find.text('بند مضاف'), findsOneWidget);
    expect(find.text('سعر الوحدة'), findsOneWidget);
    expect(find.text('تعديل المستخلص'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('extract-items-horizontal-scrollbar')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('extract-items-scroll-content')))
          .width,
      840,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/extracts_manager_390x844.png'),
    );

    await tester.ensureVisible(find.text('تعديل المستخلص'));
    await tester.tap(find.text('تعديل المستخلص'));
    await tester.pumpAndSettle();
    expect(find.text('حفظ التعديلات'), findsOneWidget);
    final quantity = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'الكمية *').first,
    );
    final rate = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'سعر المقاول *').first,
    );
    expect(quantity.controller?.text, '120');
    expect(rate.controller?.text, '10');
  });

  testWidgets('engineer sees completion without money', (tester) async {
    await pumpScreen(
      tester,
      financialsVisible: false,
      permissions: const {
        'CONTRACTOR_EXTRACT_VIEW',
        'CONTRACTOR_EXTRACT_MEASURE',
      },
    );

    expect(find.text('مستخلصات المقاولين'), findsOneWidget);
    expect(find.text('مستخلص جديد'), findsNothing);
    expect(find.text('الإنجاز'), findsOneWidget);
    expect(find.text('سعر الوحدة'), findsNothing);
    expect(find.text('الإجمالي'), findsNothing);
    expect(find.text('متابعة التنفيذ والحصر'), findsOneWidget);
    expect(find.text('رفع حصر جديد'), findsOneWidget);
    expect(find.text('إضافة بند'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('extract-items-scroll-content')))
          .width,
      520,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/extracts_engineer_390x844.png'),
    );

    await tester.tap(find.text('رفع حصر جديد'));
    await tester.pumpAndSettle();
    expect(find.text('نفس النسبة لكل البنود'), findsOneWidget);
    expect(find.text('حفظ الحصر (0 بنود)'), findsOneWidget);
  });

  testWidgets('engineer add item form accepts quantity and rate', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      financialsVisible: false,
      permissions: const {
        'CONTRACTOR_EXTRACT_VIEW',
        'CONTRACTOR_EXTRACT_MEASURE',
      },
    );

    await tester.ensureVisible(find.text('إضافة بند'));
    await tester.tap(find.text('إضافة بند'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'الكمية *'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'سعر الوحدة *'), findsOneWidget);
    expect(find.text('سيبقى البند بانتظار اعتماد المدير'), findsOneWidget);
  });

  testWidgets('create action uses create permission independently', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      financialsVisible: true,
      permissions: const {
        'CONTRACTOR_EXTRACT_VIEW',
        'CONTRACTOR_EXTRACT_CREATE',
        'CONTRACTOR_EXTRACT_PRICES',
      },
    );

    expect(find.text('مستخلص جديد'), findsOneWidget);
    expect(find.text('تعديل المستخلص'), findsOneWidget);
    expect(find.text('إضافة بند'), findsNothing);
  });

  testWidgets('approval permission alone cannot create or edit an extract', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      financialsVisible: true,
      permissions: const {
        'CONTRACTOR_EXTRACT_VIEW',
        'CONTRACTOR_EXTRACT_APPROVE',
        'CONTRACTOR_EXTRACT_PRICES',
      },
    );

    expect(find.text('مستخلص جديد'), findsNothing);
    expect(find.text('تعديل المستخلص'), findsNothing);
    expect(find.text('تسجيل حصر'), findsOneWidget);
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

class _FakeExtractRepository extends ExtractRepository {
  _FakeExtractRepository(this.financialsVisible)
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  final bool financialsVisible;

  static const contractor = ReferenceRecord(
    id: 'contractor-1',
    code: 'CON-001',
    name: 'المقاول أحمد',
    active: true,
    version: 1,
    createdAt: '',
    updatedAt: '',
  );
  static const center = ReferenceRecord(
    id: 'center-1',
    code: 'CC-001',
    name: 'مشروع العاصمة',
    active: true,
    version: 1,
    createdAt: '',
    updatedAt: '',
  );
  static const unit = ReferenceRecord(
    id: 'unit-1',
    code: 'M2',
    name: 'متر مربع',
    active: true,
    version: 1,
    createdAt: '',
    updatedAt: '',
  );

  @override
  Future<ExtractOptions> options() async => const ExtractOptions(
    contractors: [contractor],
    centers: [center],
    units: [unit],
  );

  @override
  Future<List<ContractorExtract>> list({
    String? contractorId,
    String? centerId,
  }) async => [
    ContractorExtract(
      id: 'extract-1',
      contractorId: 'contractor-1',
      contractorName: 'المقاول أحمد',
      centerId: 'center-1',
      centerName: 'مشروع العاصمة',
      extractNo: 7,
      extractDate: '2026-10-26',
      status: 'APPROVED',
      version: 2,
      financialsVisible: financialsVisible,
      net: financialsVisible ? '720.00' : null,
      outstanding: financialsVisible ? '320.00' : null,
      items: const [
        ExtractItem(
          id: 'item-1',
          kind: 'WORK',
          lineNo: 1,
          description: 'أعمال المحارة الداخلية',
          unitId: 'unit-1',
          unitName: 'متر مربع',
          quantity: '120',
          rate: '10',
          percentage: '0.60',
          amount: '720',
          pendingPercentage: '0.80',
          pendingMeasurementId: 'measurement-1',
        ),
        ExtractItem(
          id: 'item-2',
          kind: 'WORK',
          lineNo: 2,
          description: 'أعمال معالجة إضافية',
          unitId: 'unit-1',
          unitName: 'متر مربع',
          quantity: '20',
          rate: '12',
          percentage: '0',
          amount: '0',
          status: 'PENDING',
        ),
        ExtractItem(
          id: 'item-3',
          kind: 'WORK',
          lineNo: 3,
          description: 'أعمال الدهانات',
          unitId: 'unit-1',
          unitName: 'متر مربع',
          quantity: '50',
          rate: '8',
          percentage: '0.25',
          amount: '100',
        ),
      ],
    ),
  ];
}
