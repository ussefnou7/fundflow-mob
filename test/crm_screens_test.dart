import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';
import 'package:fundflow_mob/features/crm/data/crm_repository.dart';
import 'package:fundflow_mob/features/crm/domain/crm_models.dart';
import 'package:fundflow_mob/features/crm/presentation/lead_file_screen.dart';
import 'package:fundflow_mob/features/meetings/data/meetings_repository.dart';
import 'package:fundflow_mob/features/meetings/domain/meeting_models.dart';

void main() {
  setUpAll(_loadFonts);

  testWidgets('lead file lists each sub-tab as a table and adds in a sheet', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final crm = _FakeCrmRepository();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: LeadFileScreen(
              repository: crm,
              meetings: _FakeMeetingsRepository(),
              id: 'lead-1',
              embedded: true,
              permissions: const {'CRM_LEAD_MANAGE', 'CRM_INSPECTION_MANAGE'},
              onEdit: (_) async => false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Inspections: a table, the add button above it.
    await tester.scrollUntilVisible(
      find.text('م. كريم'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('حجز معاينة'), findsOneWidget);
    expect(find.text('المهندس'), findsOneWidget);
    expect(find.text('م. كريم'), findsOneWidget);
    expect(find.text('محجوزة'), findsOneWidget);

    // Follow-ups: labels, not codes.
    await tester.tap(find.text('المتابعة'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('أرسلت عرض السعر'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('النتيجة'), findsOneWidget);
    expect(find.text('واتساب'), findsOneWidget);
    expect(find.text('لم يرد'), findsWidgets);
    expect(find.text('WHATSAPP'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/crm_lead_follow_ups_390x844.png'),
    );

    // A new follow-up opens a bottom sheet, not an inline form.
    await tester.tap(find.text('حجز متابعة'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('حفظ المتابعة'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/crm_follow_up_sheet_390x844.png'),
    );
    await tester.tap(find.text('حفظ المتابعة'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(crm.followUpsAdded, 1);

    // Meetings: a table with Arabic type and status.
    await tester.tap(find.text('الاجتماعات'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('حضوري'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('مجدول'), findsOneWidget);
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

const _lead = CrmLeadDetail(
  id: 'lead-1',
  name: 'أحمد سمير',
  mobile: '01001234567',
  status: 'INSPECTION_BOOKED',
  version: 1,
  area: 'التجمع الخامس',
  address: 'فيلا 12، الحي الثالث',
  behaviour: CrmBehaviour(
    inspections: 1,
    clientCancellations: 0,
    clientReschedules: 0,
    companyCancellations: 0,
    noShows: 0,
    noAnswers: 1,
  ),
);

class _FakeCrmRepository extends CrmRepository {
  _FakeCrmRepository() : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  int followUpsAdded = 0;

  @override
  Future<CrmLeadDetail> lead(String id) async => _lead;

  @override
  Future<List<CrmRef>> organizationUsers() async => const [
    CrmRef(id: 'user-1', name: 'م. كريم'),
  ];

  @override
  Future<CrmPage<CrmInspection>> inspections({
    String? from,
    String? to,
    String? status,
    String? engineerId,
    String? leadId,
    int page = 0,
    int size = 20,
  }) async => const CrmPage(
    items: [
      CrmInspection(
        id: 'inspection-1',
        lead: _lead,
        scheduledAt: '2026-11-25T10:30:00+02:00',
        engineer: CrmRef(id: 'user-1', name: 'م. كريم'),
        agreedPrice: '1500',
        status: 'BOOKED',
        expensesTotal: '0',
        version: 1,
        address: 'فيلا 12، الحي الثالث',
      ),
    ],
    total: 1,
    page: 0,
    size: 100,
  );

  @override
  Future<List<CrmFollowUp>> followUps(String leadId) async => const [
    CrmFollowUp(
      id: 'follow-1',
      channel: 'WHATSAPP',
      occurredAt: '2026-11-23T12:00:00+02:00',
      actor: CrmRef(id: 'user-2', name: 'منى'),
      outcome: 'NO_ANSWER',
      note: 'أرسلت عرض السعر',
      nextFollowUpAt: '2026-11-26T11:00:00+02:00',
    ),
  ];

  @override
  Future<CrmFollowUp> addFollowUp(
    String leadId, {
    required String channel,
    required String outcome,
    String? note,
    String? nextFollowUpAt,
  }) async {
    followUpsAdded++;
    return CrmFollowUp(
      id: 'follow-2',
      channel: channel,
      occurredAt: '2026-11-24T12:00:00+02:00',
      actor: const CrmRef(id: 'user-2', name: 'منى'),
      outcome: outcome,
    );
  }
}

class _FakeMeetingsRepository extends MeetingsRepository {
  _FakeMeetingsRepository()
    : super(ApiClient(dio: Dio(), cookieJar: CookieJar()));

  @override
  Future<List<Meeting>> forOwner(String ownerType, String ownerId) async =>
      const [
        Meeting(
          id: 'meeting-1',
          ownerType: 'CRM_LEAD',
          ownerId: 'lead-1',
          ownerLabel: 'أحمد سمير',
          title: 'اجتماع مع أحمد سمير',
          meetingType: 'IN_PERSON',
          startAt: '2026-11-27T13:00:00+02:00',
          organizer: CrmRef(id: 'user-2', name: 'منى'),
          status: 'SCHEDULED',
          remindBeforeMinutes: 60,
          attendees: [],
          version: 1,
          location: 'مقر الشركة',
        ),
      ];
}
