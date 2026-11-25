import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';
import 'package:fundflow_mob/features/dashboard/data/dashboard_repository.dart';
import 'package:fundflow_mob/features/dashboard/domain/dashboard_models.dart';
import 'package:fundflow_mob/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  setUpAll(_loadFonts);

  testWidgets('follow-up board draws the sections the API returns', (
    tester,
  ) async {
    _setPhone(tester);
    final opened = <String>[];
    final repository = _FakeDashboardRepository(_sample);
    await tester.pumpWidget(_app(repository, opened.add));
    await tester.pumpAndSettle();

    expect(find.text('لوحة المتابعة'), findsOneWidget);
    expect(find.text('السيولة المتاحة في الخزائن'), findsOneWidget);
    expect(find.text('4,860,250'), findsOneWidget);
    expect(find.text('اعتمادات معلقة'), findsOneWidget);
    // A count of zero is not drawn, except approvals.
    expect(find.text('معاينات اليوم'), findsNothing);
    expect(find.text('حصر بانتظار الاعتماد'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/follow_up_board_390x844.png'),
    );

    await tester.tap(find.text('اعتمادات معلقة'));
    expect(opened, [BoardTargets.approvals]);

    await tester.scrollUntilVisible(
      find.text('متابعة متأخرة'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('مصروفات العهد — آخر 6 شهور'), findsOneWidget);
    expect(find.text('متوسط الشهور المكتملة'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/follow_up_board_lower_390x844.png'),
    );
    await tester.tap(find.text('متابعة متأخرة'));
    expect(opened.last, BoardTargets.followUps);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a viewer without company money sees only their actions', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = _FakeDashboardRepository({
      'today': '2026-11-25',
      'inbox': [
        {'kind': 'APPROVALS', 'count': 0},
        {'kind': 'FOLLOW_UPS_DUE', 'count': 2},
      ],
      'alerts': <Object>[],
    });
    await tester.pumpWidget(_app(repository, (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('السيولة المتاحة في الخزائن'), findsNothing);
    expect(find.text('أرصدة الخزائن'), findsNothing);
    expect(find.text('المستحقات'), findsNothing);
    expect(find.text('متابعات مستحقة'), findsOneWidget);
    expect(find.text('2 بندًا'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(DashboardRepository repository, ValueChanged<String> onOpen) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      theme: AppTheme.light(),
      home: Scaffold(
        body: DashboardScreen(repository: repository, onOpen: onOpen),
      ),
    );

const _money = [
  {'currencyCode': 'EGP', 'currencyCodeAr': 'ج.م', 'amount': '4860250.00'},
  {'currencyCode': 'SAR', 'currencyCodeAr': 'ر.س', 'amount': '312400.00'},
];

Map<String, Object?> _month(int month, String amount) => {
  'year': 2026,
  'month': month,
  'totals': [
    {'currencyCode': 'EGP', 'currencyCodeAr': 'ج.م', 'amount': amount},
  ],
};

final _sample = <String, Object?>{
  'today': '2026-11-25',
  'inbox': [
    {'kind': 'APPROVALS', 'count': 7},
    {'kind': 'MEASUREMENTS_PENDING', 'count': 3},
    {'kind': 'CUSTODY_REQUESTS_UNPAID', 'count': 4, 'amount': '38500.00'},
    {'kind': 'PURCHASE_REQUESTS_WITHOUT_ORDER', 'count': 5},
    {'kind': 'ORDERS_AWAITING_RECEIPT', 'count': 2},
    {'kind': 'FOLLOW_UPS_DUE', 'count': 6},
    {'kind': 'INSPECTIONS_TODAY', 'count': 0},
    {'kind': 'MEETINGS_TODAY', 'count': 0},
  ],
  'liquidity': {
    'treasuries': [
      {
        'id': 't1',
        'name': 'الخزينة الرئيسية',
        'currencyCode': 'EGP',
        'currencyCodeAr': 'ج.م',
        'balance': '2140000.00',
      },
      {
        'id': 't2',
        'name': 'بنك مصر — جاري',
        'currencyCode': 'EGP',
        'currencyCodeAr': 'ج.م',
        'balance': '2315250.00',
      },
      {
        'id': 't3',
        'name': 'خزينة الموقع',
        'currencyCode': 'EGP',
        'currencyCodeAr': 'ج.م',
        'balance': '405000.00',
      },
      {
        'id': 't4',
        'name': 'الراجحي — جاري',
        'currencyCode': 'SAR',
        'currencyCodeAr': 'ر.س',
        'balance': '312400.00',
      },
    ],
    'treasuryTotals': _money,
    'custody': {
      'holders': 18,
      'balances': [
        {'currencyCode': 'EGP', 'currencyCodeAr': 'ج.م', 'amount': '726900.00'},
      ],
    },
    'monthCustodyExpenses': [
      {'currencyCode': 'EGP', 'currencyCodeAr': 'ج.م', 'amount': '936000.00'},
    ],
    'previousMonthCustodyExpenses': [
      {'currencyCode': 'EGP', 'currencyCodeAr': 'ج.م', 'amount': '3785000.00'},
    ],
  },
  'alerts': [
    {
      'kind': 'STALE_CUSTODY',
      'level': 'DANGER',
      'count': 5,
      'subject': 'محمود سعيد',
      'days': 19,
    },
    {
      'kind': 'OVERDUE_EXTRACTS',
      'level': 'DANGER',
      'count': 6,
      'days': 30,
      'amount': '542500.00',
    },
  ],
  'payables': {
    'total': '1284600.00',
    'extracts': 14,
    'contractors': 9,
    'aging': [
      {'range': 'UNDER_30', 'extracts': 8, 'amount': '742100.00'},
      {'range': 'FROM_30_TO_60', 'extracts': 4, 'amount': '398500.00'},
      {'range': 'OVER_60', 'extracts': 2, 'amount': '144000.00'},
    ],
  },
  'purchasing': {
    'openOrders': 12,
    'ordersAwaitingApproval': 3,
    'monthCashPurchases': '214300.00',
  },
  'crm': {
    'newLeadsThisWeek': 23,
    'upcomingInspections': 8,
    'overdueFollowUps': 14,
  },
  'custodyExpenseTrend': [
    _month(6, '1409000.00'),
    _month(7, '2432000.00'),
    _month(8, '2685000.00'),
    _month(9, '3069000.00'),
    _month(10, '3785000.00'),
    _month(11, '936000.00'),
  ],
  'hr': {'ready': false},
  'projects': {'ready': false},
};

class _FakeDashboardRepository extends DashboardRepository {
  _FakeDashboardRepository(this.json)
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));
  final Map<String, Object?> json;

  @override
  Future<FollowUpBoard> load() async =>
      FollowUpBoard.fromJson(Map<String, dynamic>.from(json));
}

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
