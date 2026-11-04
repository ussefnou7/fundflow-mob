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

  testWidgets('contractor extracts follow the mobile web design', (
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
            body: SafeArea(
              child: ContractorExtractScreen(
                repository: _FakeExtractRepository(),
                permissions: const {
                  'CONTRACTOR_EXTRACT_VIEW',
                  'CONTRACTOR_EXTRACT_CREATE',
                  'CONTRACTOR_EXTRACT_APPROVE',
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مستخلصات المقاولين'), findsOneWidget);
    expect(find.text('مستخلص جديد'), findsOneWidget);
    expect(find.text('بانتظار التسعير والاعتماد'), findsWidgets);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/extracts_390x844.png'),
    );

    await tester.tap(find.text('مستخلص جديد'));
    await tester.pumpAndSettle();
    expect(
      find.text('سجّل الكميات ووحدات القياس فقط — التسعير والاعتماد للمدير'),
      findsOneWidget,
    );
    expect(find.text('إضافة بند'), findsOneWidget);
    Navigator.of(tester.element(find.text('إلغاء').last)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('المقاول أحمد').first);
    await tester.pumpAndSettle();
    expect(find.text('تسعير واعتماد'), findsOneWidget);
    expect(find.text('رفض'), findsOneWidget);
    expect(find.text('البند'), findsOneWidget);
    expect(find.text('الكمية'), findsOneWidget);
    expect(find.text('الوحدة'), findsOneWidget);
    expect(find.text('سعر الوحدة'), findsOneWidget);
    expect(find.text('الإجمالي'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/extracts_expanded_390x844.png'),
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

class _FakeExtractRepository extends ExtractRepository {
  _FakeExtractRepository()
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

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
  }) async => const [
    ContractorExtract(
      id: 'extract-1',
      contractorId: 'contractor-1',
      contractorName: 'المقاول أحمد',
      centerId: 'center-1',
      centerName: 'مشروع العاصمة',
      extractNo: 7,
      extractDate: '2026-10-26',
      status: 'PENDING',
      version: 2,
      financialsVisible: true,
      items: [
        ExtractItem(
          id: 'item-1',
          kind: 'WORK',
          lineNo: 1,
          description: 'أعمال المحارة الداخلية',
          unitId: 'unit-1',
          unitName: 'متر مربع',
          quantity: '120',
        ),
      ],
    ),
  ];
}
