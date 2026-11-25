import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';
import 'package:fundflow_mob/features/crm/data/crm_repository.dart';
import 'package:fundflow_mob/features/crm/domain/crm_models.dart';
import 'package:fundflow_mob/features/crm/presentation/inspection_dashboard_screen.dart';

void main() {
  setUpAll(() async {
    final cairo = FontLoader('Cairo')
      ..addFont(rootBundle.load('assets/fonts/Cairo.ttf'));
    final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
    await Future.wait([cairo.load(), lucide.load()]);
  });

  testWidgets('inspection dashboard is compact and mobile first', (
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
            body: InspectionDashboardScreen(
              repository: _DashboardRepository(),
              permissions: const {'CRM_INSPECTION_DASHBOARD'},
              onOpenAll: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('متابعة المعاينات'), findsOneWidget);
    expect(find.text('جدول اليوم'), findsOneWidget);
    expect(find.text('شركة النور للتجارة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/crm_inspection_dashboard_390x844.png'),
    );
  });
}

class _DashboardRepository extends CrmRepository {
  _DashboardRepository() : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  @override
  Future<CrmInspectionDashboard> inspectionDashboard(
    CrmDashboardPeriod period,
  ) async => CrmInspectionDashboard(
    period: period,
    from: '2026-11-25T00:00:00+02:00',
    to: '2026-11-26T00:00:00+02:00',
    kpis: const CrmDashboardKpis(
      total: 12,
      done: 7,
      overdue: 3,
      rescheduled: 2,
      collected: '61000',
    ),
    today: const [
      CrmDashboardSchedule(
        id: 'inspection-1',
        scheduledAt: '2026-11-25T09:30:00+02:00',
        leadId: 'lead-1',
        leadName: 'شركة النور للتجارة',
        area: 'التجمع الخامس',
        inspectionType: 'معاينة موقع',
        engineer: 'أحمد سمير',
        agreedPrice: '1500',
      ),
      CrmDashboardSchedule(
        id: 'inspection-2',
        scheduledAt: '2026-11-25T11:00:00+02:00',
        leadId: 'lead-2',
        leadName: 'محمد عبد الرحمن',
        area: 'مدينة نصر',
        inspectionType: 'معاينة موقع',
        engineer: 'سارة علي',
        agreedPrice: '1200',
      ),
      CrmDashboardSchedule(
        id: 'inspection-3',
        scheduledAt: '2026-11-25T13:30:00+02:00',
        leadId: 'lead-3',
        leadName: 'مؤسسة الأمان',
        area: 'المعادي',
        inspectionType: 'معاينة موقع',
        engineer: 'كريم حسن',
        agreedPrice: '1750',
      ),
    ],
    statuses: const [
      CrmDashboardStatus(status: 'BOOKED', count: 4),
      CrmDashboardStatus(status: 'DONE', count: 7),
      CrmDashboardStatus(status: 'RESCHEDULED', count: 1),
    ],
    engineers: const [
      CrmEngineerPerformance(
        engineerId: 'engineer-1',
        engineer: 'أحمد سمير',
        inspections: 18,
        done: 15,
        cancelledOrNoShow: 1,
        agreed: '22500',
        collected: '18000',
      ),
      CrmEngineerPerformance(
        engineerId: 'engineer-2',
        engineer: 'سارة علي',
        inspections: 14,
        done: 11,
        cancelledOrNoShow: 1,
        agreed: '17000',
        collected: '14500',
      ),
    ],
    financial: const CrmDashboardFinancial(
      agreed: '82000',
      collected: '61000',
      expenses: '7500',
      net: '53500',
    ),
  );
}
