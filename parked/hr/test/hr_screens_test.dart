import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fundflow_mob/core/network/api_client.dart';
import 'package:fundflow_mob/core/theme/app_theme.dart';
import 'package:fundflow_mob/core/time/server_clock.dart';
import 'package:fundflow_mob/features/hr/application/face_liveness.dart';
import 'package:fundflow_mob/features/hr/application/punch_sensors.dart';
import 'package:fundflow_mob/features/hr/data/hr_repository.dart';
import 'package:fundflow_mob/features/hr/domain/hr_models.dart';
import 'package:fundflow_mob/features/hr/presentation/attendance_log_screen.dart';
import 'package:fundflow_mob/features/hr/presentation/attendance_punch_screen.dart';
import 'package:fundflow_mob/features/hr/presentation/employee_profile_screen.dart';
import 'package:fundflow_mob/features/hr/presentation/hr_approvals_screen.dart';
import 'package:fundflow_mob/features/hr/presentation/hr_dashboard_screen.dart';
import 'package:fundflow_mob/features/hr/presentation/hr_requests_screen.dart';

final _now = DateTime(2026, 10, 28, 9, 41);

void main() {
  setUpAll(_loadFonts);

  test('server times keep the server\'s wall clock in any phone zone', () {
    final wall = serverWallTime('2026-10-28T08:04:30+03:00')!;
    expect([wall.hour, wall.minute, wall.second], [8, 4, 30]);
    expect(serverWallTime('2026-10-28T05:04:30Z')!.hour, 5);
    final clock = ServerClock();
    expect(clock.now(), isNull);
    clock.syncFromHeader('Wed, 28 Oct 2026 06:00:00 GMT');
    clock.sync('2026-10-28T09:41:00+03:00');
    expect(clock.now()!.hour, 9);
    // A header never overrides a server timestamp.
    clock.syncFromHeader('Wed, 28 Oct 2026 01:00:00 GMT');
    expect(clock.now()!.hour, 9);
  });

  testWidgets('punch screen shows the day and punches out', (tester) async {
    _setPhone(tester);
    final repository = _FakeHrRepository();
    final sensors = _FakeSensors(
      const PunchFix(lat: 30.0001, lng: 31.0001, accuracyM: 8),
    );
    await tester.pumpWidget(
      _app(AttendancePunchScreen(repository: repository, sensors: sensors)),
    );
    await tester.pumpAndSettle();
    expect(find.text('الحضور والانصراف'), findsOneWidget);
    expect(find.text('تسجيل الانصراف'), findsOneWidget);
    expect(find.text('داخل النطاق'), findsOneWidget);
    expect(find.text('موقع كمبوند النخيل'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/hr_punch_390x844.png'),
    );

    // A quick tap does nothing; the print has to fill.
    await tester.tap(find.text('تسجيل الانصراف'));
    await tester.pumpAndSettle();
    expect(repository.punched, isNull);

    await _holdToPunch(tester, find.text('تسجيل الانصراف'));
    expect(repository.punched?.punchType, 'OUT');
    expect(repository.punched?.installationId, 'install-1');
    // The screen tells the server which phone asks.
    expect(repository.askedFrom, 'install-1');
    expect(repository.punched?.mockLocation, isFalse);
  });

  testWidgets('out of range asks to confirm and sends a note', (tester) async {
    _setPhone(tester);
    final repository = _FakeHrRepository(punches: const []);
    final sensors = _FakeSensors(
      const PunchFix(lat: 30.02, lng: 31.02, accuracyM: 12),
    );
    await tester.pumpWidget(
      _app(AttendancePunchScreen(repository: repository, sensors: sensors)),
    );
    await tester.pumpAndSettle();
    expect(find.text('خارج النطاق'), findsOneWidget);
    await _holdToPunch(tester, find.text('تسجيل الحضور'));
    expect(find.text('تأكيد تسجيل الحضور'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/hr_punch_confirm_390x844.png'),
    );
    await tester.enterText(find.byType(TextField), 'في موقع العميل');
    await tester.tap(find.text('تسجيل البصمة'));
    await tester.pumpAndSettle();
    expect(repository.punched?.punchType, 'IN');
    expect(repository.punched?.note, 'في موقع العميل');
    expect(repository.punched?.lat, 30.02);
  });

  testWidgets('a phone waiting to be bound still punches and says so', (
    tester,
  ) async {
    _setPhone(tester);
    await tester.pumpWidget(
      _app(
        AttendancePunchScreen(
          repository: _FakeHrRepository(
            onBoundPhone: false,
            bindingRequested: true,
          ),
          sensors: _FakeSensors(const PunchFix(lat: 30.0001, lng: 31.0001)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('طلب ربط هذا الجهاز بانتظار موافقة مديرك'),
      findsOneWidget,
    );
    expect(find.text('معلّقة للمراجعة'), findsOneWidget);
  });

  testWidgets('another phone punches for the manager to approve', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = _FakeHrRepository(onBoundPhone: false);
    await tester.pumpWidget(
      _app(
        AttendancePunchScreen(
          repository: repository,
          sensors: _FakeSensors(const PunchFix(lat: 30.0001, lng: 31.0001)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('هذا الجهاز غير مربوط بحسابك'), findsOneWidget);
    // The day expects a punch out; the employee punches in again instead.
    await tester.tap(find.text('حضور').first);
    await tester.pumpAndSettle();
    await _holdToPunch(tester, find.text('تسجيل الحضور'));
    expect(repository.punched?.punchType, 'IN');
  });

  testWidgets('the bound phone HR revoked cannot punch', (tester) async {
    _setPhone(tester);
    final repository = _FakeHrRepository(deviceStatus: 'REVOKED');
    await tester.pumpWidget(
      _app(
        AttendancePunchScreen(
          repository: repository,
          sensors: _FakeSensors(const PunchFix(lat: 30.0001, lng: 31.0001)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تم إلغاء اعتماد هذا الجهاز'), findsOneWidget);
    expect(find.text('غير متاح'), findsOneWidget);
    await _holdToPunch(tester, find.text('تسجيل الانصراف'));
    expect(repository.punched, isNull);
  });

  testWidgets('the manager approves a phone and a punch from another phone', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = _FakeHrRepository();
    var changed = 0;
    await tester.pumpWidget(
      _app(
        HrApprovalsScreen(repository: repository, onChanged: () => changed++),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('موافقات الحضور'), findsOneWidget);
    expect(find.text('مربوط بحساب آخر'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/hr_approvals_390x844.png'),
    );

    await tester.tap(find.text('موافقة'));
    await tester.pumpAndSettle();
    expect(find.text('الموافقة على ربط الجهاز'), findsOneWidget);
    expect(
      find.textContaining('يُلغى ربط الجهاز بالحساب الآخر'),
      findsOneWidget,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/hr_approvals_device_sheet_390x844.png'),
    );
    await tester.tap(find.text('تأكيد الموافقة'));
    await tester.pumpAndSettle();
    expect(repository.decidedDevice, ('r1', true));
    expect(changed, 1);

    // The phone is done, so the screen moves on to the held punch.
    expect(find.text('محمود سعيد'), findsOneWidget);
    await tester.tap(find.text('رفض'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      'ليس جهازك',
    );
    await tester.tap(find.text('تأكيد الرفض'));
    await tester.pumpAndSettle();
    expect(repository.decidedPunch, ('p7', false, 'ليس جهازك'));
  });

  testWidgets('a face punch shows the server\'s action and sends both photos', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = _FakeHrRepository(
      faceAvailable: true,
      selfieRequired: true,
      faceEnrolled: true,
    );
    final sensors = _FakeSensors(
      const PunchFix(lat: 30.0001, lng: 31.0001),
      face: const FaceCapture(
        paths: ['/tmp/turned.jpg', '/tmp/selfie.jpg'],
        livenessOk: true,
        poses: [FacePose.left, FacePose.front],
      ),
    );
    await tester.pumpWidget(
      _app(AttendancePunchScreen(repository: repository, sensors: sensors)),
    );
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الوجه'), findsNothing);
    await _holdToPunch(tester, find.text('تسجيل الانصراف'));
    expect(sensors.asked, [false]);
    // The camera was asked for the action the server drew.
    expect(sensors.actions, ['TURN_LEFT']);
    expect(repository.punched?.selfiePath, '/tmp/selfie.jpg');
    expect(repository.punched?.actionPath, '/tmp/turned.jpg');
    expect(repository.punched?.challengeId, 'c1');
    expect(repository.punched?.livenessOk, isTrue);
  });

  testWidgets('closing the camera cancels the punch', (tester) async {
    _setPhone(tester);
    final repository = _FakeHrRepository(
      faceAvailable: true,
      selfieRequired: true,
      faceEnrolled: true,
    );
    final sensors = _FakeSensors(const PunchFix(lat: 30.0001, lng: 31.0001));
    await tester.pumpWidget(
      _app(AttendancePunchScreen(repository: repository, sensors: sensors)),
    );
    await tester.pumpAndSettle();
    await _holdToPunch(tester, find.text('تسجيل الانصراف'));
    expect(sensors.asked, [false]);
    expect(repository.punched, isNull);
  });

  testWidgets('a face-required shift cannot submit without a camera', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = _FakeHrRepository(
      faceAvailable: true,
      selfieRequired: true,
      faceEnrolled: true,
    );
    final sensors = _FakeSensors(
      const PunchFix(lat: 30.0001, lng: 31.0001),
      face: const FaceCapture.unavailable('لم يُسمح للتطبيق باستخدام الكاميرا'),
    );
    await tester.pumpWidget(
      _app(AttendancePunchScreen(repository: repository, sensors: sensors)),
    );
    await tester.pumpAndSettle();
    await _holdToPunch(tester, find.text('تسجيل الانصراف'));
    expect(repository.punched, isNull);
  });

  testWidgets(
    'without face service on the server the employee is told plainly',
    (tester) async {
      _setPhone(tester);
      final repository = _FakeHrRepository(
        faceAvailable: false,
        selfieRequired: true,
        faceEnrolled: false,
      );
      final sensors = _FakeSensors(const PunchFix(lat: 30.0001, lng: 31.0001));
      await tester.pumpWidget(
        _app(AttendancePunchScreen(repository: repository, sensors: sensors)),
      );
      await tester.pumpAndSettle();
      await _holdToPunch(tester, find.text('تسجيل الانصراف'));
      expect(repository.punched, isNull);
      expect(
        find.text('خدمة بصمة الوجه غير متاحة حاليًا؛ تواصل مع الموارد البشرية'),
        findsOneWidget,
      );
      expect(find.textContaining('Bad state'), findsNothing);
    },
  );

  for (final enrolled in [false, true]) {
    testWidgets(
      'location-only shift never requests a face (enrolled: $enrolled)',
      (tester) async {
        _setPhone(tester);
        final repository = _FakeHrRepository(
          faceAvailable: true,
          faceEnrolled: enrolled,
        );
        final sensors = _FakeSensors(
          const PunchFix(lat: 30.0001, lng: 31.0001),
        );
        await tester.pumpWidget(
          _app(AttendancePunchScreen(repository: repository, sensors: sensors)),
        );
        await tester.pumpAndSettle();
        expect(find.text('تسجيل الوجه'), findsNothing);
        await _holdToPunch(tester, find.text('تسجيل الانصراف'));
        expect(sensors.asked, isEmpty);
        expect(repository.enrolled, isNull);
        expect(repository.punched?.punchType, 'OUT');
        expect(repository.punched?.selfiePath, isNull);
      },
    );
  }

  testWidgets('no selfie is taken while face punch is off', (tester) async {
    _setPhone(tester);
    final repository = _FakeHrRepository();
    final sensors = _FakeSensors(const PunchFix(lat: 30.0001, lng: 31.0001));
    await tester.pumpWidget(
      _app(AttendancePunchScreen(repository: repository, sensors: sensors)),
    );
    await tester.pumpAndSettle();
    await _holdToPunch(tester, find.text('تسجيل الانصراف'));
    expect(sensors.asked, isEmpty);
    expect(repository.punched?.selfiePath, isNull);
  });

  testWidgets(
    'first punch enrols the face then verifies and submits the punch',
    (tester) async {
      _setPhone(tester);
      final repository = _FakeHrRepository(
        faceAvailable: true,
        selfieRequired: true,
      );
      final sensors = _FakeSensors(
        const PunchFix(lat: 30.0001, lng: 31.0001),
        face: const FaceCapture(
          paths: ['/tmp/a.jpg', '/tmp/b.jpg', '/tmp/c.jpg'],
          livenessOk: true,
        ),
      );
      await tester.pumpWidget(
        _app(AttendancePunchScreen(repository: repository, sensors: sensors)),
      );
      await tester.pumpAndSettle();
      await _holdToPunch(tester, find.text('تسجيل الانصراف'));
      expect(sensors.asked, [true, false]);
      expect(repository.enrolled, isNotNull);
      expect(repository.punched?.punchType, 'OUT');
      expect(repository.punched?.selfiePath, '/tmp/a.jpg');
    },
  );

  testWidgets('cancelling first face enrolment does not submit a punch', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = _FakeHrRepository(
      faceAvailable: true,
      selfieRequired: true,
    );
    final sensors = _FakeSensors(const PunchFix(lat: 30.0001, lng: 31.0001));
    await tester.pumpWidget(
      _app(AttendancePunchScreen(repository: repository, sensors: sensors)),
    );
    await tester.pumpAndSettle();
    await _holdToPunch(tester, find.text('تسجيل الانصراف'));
    expect(sensors.asked, [true]);
    expect(repository.enrolled, isNull);
    expect(repository.punched, isNull);
  });

  testWidgets('failed camera during first enrolment does not submit a punch', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = _FakeHrRepository(
      faceAvailable: true,
      selfieRequired: true,
    );
    final sensors = _FakeSensors(
      const PunchFix(lat: 30.0001, lng: 31.0001),
      face: const FaceCapture.unavailable('تعذر تشغيل الكاميرا'),
    );
    await tester.pumpWidget(
      _app(AttendancePunchScreen(repository: repository, sensors: sensors)),
    );
    await tester.pumpAndSettle();
    await _holdToPunch(tester, find.text('تسجيل الانصراف'));
    expect(repository.enrolled, isNull);
    expect(repository.punched, isNull);
    expect(find.textContaining('تعذر تشغيل الكاميرا'), findsOneWidget);
  });

  testWidgets('the employee enrols their face from the approved phone', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = _FakeHrRepository(
      faceAvailable: true,
      selfieRequired: true,
    );
    final sensors = _FakeSensors(
      const PunchFix(lat: 30.0001, lng: 31.0001),
      face: const FaceCapture(
        paths: ['/tmp/a.jpg', '/tmp/b.jpg', '/tmp/c.jpg'],
        livenessOk: true,
      ),
    );
    await tester.pumpWidget(
      _app(AttendancePunchScreen(repository: repository, sensors: sensors)),
    );
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الوجه'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/hr_punch_face_enrol_390x844.png'),
    );
    await tester.tap(find.text('تسجيل'));
    await tester.pumpAndSettle();
    expect(sensors.asked, [true]);
    final (photos, installation, live) = repository.enrolled!;
    expect(photos, ['/tmp/a.jpg', '/tmp/b.jpg', '/tmp/c.jpg']);
    expect(installation, 'install-1');
    expect(live, isTrue);
    // Enrolled now: the card is gone.
    expect(find.text('تسجيل الوجه'), findsNothing);
  });

  testWidgets('another phone is not offered face enrolment', (tester) async {
    _setPhone(tester);
    await tester.pumpWidget(
      _app(
        AttendancePunchScreen(
          repository: _FakeHrRepository(
            faceAvailable: true,
            selfieRequired: true,
            onBoundPhone: false,
          ),
          sensors: _FakeSensors(const PunchFix(lat: 30.0001, lng: 31.0001)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الوجه'), findsNothing);
  });

  testWidgets('the clock is the server\'s, not the phone\'s', (tester) async {
    _setPhone(tester);
    await tester.pumpWidget(
      _app(
        AttendancePunchScreen(
          repository: _FakeHrRepository(),
          sensors: _FakeSensors(const PunchFix(lat: 30.0001, lng: 31.0001)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('09:41'), findsOneWidget);
    expect(find.text('الأربعاء 28 أكتوبر 2026'), findsOneWidget);
  });

  testWidgets('attendance log summarises the month and opens a day', (
    tester,
  ) async {
    _setPhone(tester);
    await tester.pumpWidget(
      _app(AttendanceLogScreen(repository: _FakeHrRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('سجل الحضور'), findsOneWidget);
    expect(find.text('أكتوبر 2026'), findsOneWidget);
    expect(find.text('غياب'), findsOneWidget);
    expect(find.text('بصمة ناقصة'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/hr_attendance_log_390x844.png'),
    );

    await tester.tap(find.text('الثلاثاء 27/10'));
    await tester.pumpAndSettle();
    expect(find.text('التأثير على المرتب'), findsOneWidget);
    expect(find.text('طلب تصحيح حضور'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/hr_attendance_day_390x844.png'),
    );
  });

  testWidgets('requests show balances and the form follows the type', (
    tester,
  ) async {
    _setPhone(tester);
    await tester.pumpWidget(
      _app(HrRequestsScreen(repository: _FakeHrRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('الطلبات'), findsOneWidget);
    expect(find.text('الأرصدة'), findsOneWidget);
    expect(find.text('إجازة اعتيادية'), findsWidgets);
    expect(find.text('مرفوض'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/hr_requests_390x844.png'),
    );

    await tester.tap(find.text('طلب جديد'));
    await tester.pumpAndSettle();
    expect(find.text('نوع الإجازة *'), findsOneWidget);
    expect(find.text('إلى تاريخ *'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/hr_request_form_390x844.png'),
    );
    await tester.tap(
      find.descendant(of: find.byType(BottomSheet), matching: find.text('إذن')),
    );
    await tester.pumpAndSettle();
    expect(find.text('من الساعة *'), findsOneWidget);
    expect(find.text('نوع الإجازة *'), findsNothing);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('تصحيح حضور'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('وقت البصمة *'), findsOneWidget);
    expect(find.text('السبب *'), findsOneWidget);
  });

  testWidgets('employee file is read only', (tester) async {
    _setPhone(tester);
    await tester.pumpWidget(
      _app(EmployeeProfileScreen(repository: _FakeHrRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.text('ملف الموظف'), findsOneWidget);
    expect(find.text('أحمد محمد علي'), findsOneWidget);
    expect(find.text('البيانات الوظيفية'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/hr_profile_390x844.png'),
    );
  });

  testWidgets('the manager resets a report\'s face after confirming', (
    tester,
  ) async {
    _setPhone(tester);
    final repository = _DashboardRepository();
    await tester.pumpWidget(
      _app(
        HrDashboardScreen(
          repository: repository,
          companyWideAttendance: false,
          companyWideRequests: false,
          canViewPayroll: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('بصمات وجه الفريق'), findsOneWidget);
    expect(find.text('مسجلة'), findsOneWidget);
    expect(find.text('غير مسجلة'), findsOneWidget);
    // Only an enrolled face can be reset.
    expect(find.text('إعادة ضبط'), findsOneWidget);

    await tester.ensureVisible(find.text('إعادة ضبط'));
    await tester.tap(find.text('إعادة ضبط'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(repository.reset, isNull);

    await tester.tap(find.text('إعادة ضبط'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إعادة الضبط'));
    await tester.pumpAndSettle();
    expect(repository.reset, 'e2');
    expect(find.text('مسجلة'), findsNothing);
    expect(find.text('غير مسجلة'), findsNWidgets(2));
    expect(find.text('تمت إعادة ضبط بصمة وجه كريم عادل'), findsOneWidget);
  });
}

class _DashboardRepository extends _FakeHrRepository {
  String? reset;

  @override
  Future<List<HrTimesheetDay>> teamTimesheet({
    required DateTime from,
    required DateTime to,
    bool companyWide = false,
  }) async => const [];

  @override
  Future<List<HrRequest>> teamRequests({bool companyWide = false}) async =>
      const [];

  @override
  Future<HrApprovalSummary> approvalSummary() async =>
      const HrApprovalSummary(decides: true);

  @override
  Future<List<HrTeamFace>> teamFaces() async => [
    HrTeamFace(
      employee: const HrRef(id: 'e2', code: 'EMP-021', name: 'كريم عادل'),
      enrolled: reset != 'e2',
      enrolledAt: reset == 'e2' ? null : DateTime(2026, 10, 20, 9),
    ),
    const HrTeamFace(
      employee: HrRef(id: 'e3', code: 'EMP-033', name: 'محمود سعيد'),
      enrolled: false,
    ),
  ];

  @override
  Future<void> resetFace(String employeeId) async => reset = employeeId;
}

Widget _app(Widget screen) => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('ar'),
  builder: (context, child) =>
      Directionality(textDirection: TextDirection.rtl, child: child!),
  theme: AppTheme.light(),
  home: Scaffold(body: screen),
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

class _FakeSensors implements PunchSensors {
  _FakeSensors(this.fix, {this.face});
  final PunchFix fix;
  final FaceCapture? face;
  final asked = <bool>[];
  final actions = <String?>[];

  @override
  String get installationId => 'install-1';

  @override
  Future<PunchFix> locate() async => fix;

  @override
  Future<FaceCapture?> captureFace(
    BuildContext context, {
    bool enrol = false,
    String? action,
  }) async {
    asked.add(enrol);
    if (!enrol) actions.add(action);
    return face;
  }
}

class _FakeHrRepository extends HrRepository {
  _FakeHrRepository({
    this.deviceStatus = 'ACTIVE',
    this.onBoundPhone = true,
    this.bindingRequested = false,
    this.faceAvailable = false,
    this.selfieRequired = false,
    this.faceEnrolled = false,
    List<HrPunch>? punches,
  }) : _punches =
           punches ??
           [
             HrPunch(
               id: 'p1',
               punchType: 'IN',
               punchedAt: DateTime(2026, 10, 28, 8, 4),
               dateTrx: '2026-10-28',
               status: bindingRequested ? 'PENDING' : 'ACCEPTED',
               location: const HrRef(
                 id: 'l1',
                 code: 'L1',
                 name: 'موقع كمبوند النخيل',
               ),
               distanceM: 18,
               gpsAccuracyM: 9,
             ),
           ],
       super(
         ApiClient(dio: Dio(), cookieJar: CookieJar()),
         clock: ServerClock()..sync('2026-10-28T09:41:00+03:00'),
       );

  final String? deviceStatus;
  final bool onBoundPhone;
  final bool bindingRequested;
  final bool faceAvailable;
  final bool selfieRequired;
  bool faceEnrolled;
  (List<String>, String, bool)? enrolled;
  String? askedFrom;
  (String, bool)? decidedDevice;
  (String, bool, String?)? decidedPunch;
  bool _deviceDecided = false;
  bool _punchDecided = false;

  @override
  Future<List<HrDeviceRequest>> deviceRequests() async => _deviceDecided
      ? const []
      : [
          HrDeviceRequest(
            id: 'r1',
            employee: const HrRef(id: 'e2', code: 'EMP-021', name: 'كريم عادل'),
            platform: 'ANDROID',
            deviceName: 'Android',
            model: 'Galaxy A54',
            appVersion: '1.4.0',
            takenByOther: true,
            replacesPhone: 'Redmi Note 12',
            requestedAt: DateTime(2026, 10, 28, 8, 12),
            version: 0,
          ),
        ];

  @override
  Future<List<HrPunch>> heldPunches() async => _punchDecided
      ? const []
      : [
          HrPunch(
            id: 'p7',
            punchType: 'IN',
            punchedAt: DateTime(2026, 10, 28, 8, 26),
            dateTrx: '2026-10-28',
            status: 'PENDING',
            employee: const HrRef(
              id: 'e3',
              code: 'EMP-033',
              name: 'محمود سعيد',
            ),
            location: const HrRef(
              id: 'l1',
              code: 'L1',
              name: 'موقع كمبوند النخيل',
            ),
            distanceM: 22,
            trustFlags: const ['OTHER_DEVICE'],
            note: 'الموبايل فصل شحن',
          ),
        ];

  @override
  Future<void> decideDeviceRequest(
    HrDeviceRequest request, {
    required bool approve,
    String? note,
  }) async {
    decidedDevice = (request.id, approve);
    _deviceDecided = true;
  }

  @override
  Future<void> decidePunch(
    HrPunch punch, {
    required bool approve,
    String? note,
  }) async {
    decidedPunch = (punch.id, approve, note);
    _punchDecided = true;
  }

  final List<HrPunch> _punches;
  PunchInput? punched;

  @override
  Future<HrToday> today({String? installationId}) async {
    askedFrom = installationId;
    return _today;
  }

  HrToday get _today => HrToday(
    employee: const HrRef(id: 'e1', code: 'EMP-014', name: 'أحمد محمد علي'),
    status: 'ACTIVE',
    deviceStatus: deviceStatus,
    onBoundPhone: onBoundPhone,
    bindingRequested: bindingRequested,
    faceAvailable: faceAvailable,
    selfieRequired: selfieRequired,
    faceEnrolled: faceEnrolled,
    dateTrx: '2026-10-28',
    shift: HrShiftDay(
      code: 'S1',
      name: 'الوردية الصباحية',
      startTime: '08:00:00',
      endTime: '16:00:00',
      overnight: false,
      punchFrom: DateTime(2026, 10, 28, 6),
      punchTo: DateTime(2026, 10, 28, 20),
    ),
    attendanceType: 'SINGLE',
    places: const [
      HrPlace(
        id: 'l1',
        name: 'موقع كمبوند النخيل',
        lat: 30,
        lng: 31,
        radiusM: 150,
      ),
    ],
    punches: _punches,
    firstIn: _punches.isEmpty ? null : _punches.first.punchedAt,
    elapsedMinutes: _punches.isEmpty ? null : 97,
  );

  @override
  Future<HrFaceChallenge> faceChallenge() async =>
      const HrFaceChallenge(id: 'c1', action: 'TURN_LEFT');

  @override
  Future<HrPunch> punch(PunchInput input) async {
    punched = input;
    return HrPunch(
      id: 'p2',
      punchType: input.punchType,
      punchedAt: _now,
      dateTrx: '2026-10-28',
      status: 'ACCEPTED',
    );
  }

  @override
  Future<HrFaceStatus> enrolFace({
    required List<String> photoPaths,
    required String installationId,
    required bool livenessOk,
  }) async {
    enrolled = (photoPaths, installationId, livenessOk);
    faceEnrolled = true;
    return HrFaceStatus(
      available: true,
      enrolled: true,
      photos: photoPaths.length,
    );
  }

  @override
  Future<List<HrPunch>> punches({DateTime? from, DateTime? to}) async => [
    HrPunch(
      id: 'p9',
      punchType: 'IN',
      punchedAt: DateTime(2026, 10, 27, 8, 47),
      dateTrx: '2026-10-27',
      status: 'ACCEPTED',
      location: const HrRef(id: 'l1', code: 'L1', name: 'موقع كمبوند النخيل'),
    ),
  ];

  HrTimesheetDay _day(
    String date,
    String status, {
    int late = 0,
    int overtime = 0,
    int worked = 480,
    bool missing = false,
    DateTime? checkIn,
    DateTime? checkOut,
    List<HrTimesheetLine> lines = const [],
  }) => HrTimesheetDay(
    workDate: date,
    shift: const HrRef(id: 's1', code: 'S1', name: 'الوردية الصباحية'),
    shiftStart: DateTime.parse('${date}T08:00:00'),
    shiftEnd: DateTime.parse('${date}T16:00:00'),
    dayType: 'WORKDAY',
    status: status,
    checkIn: checkIn,
    checkOut: checkOut,
    plannedMinutes: 480,
    workedMinutes: status == 'ABSENT' ? 0 : worked,
    lateMinutes: late,
    earlyLeaveMinutes: 0,
    permissionMinutes: 0,
    overtimeMinutes: overtime,
    approvedOvertimeMinutes: 0,
    missingPunch: missing,
    locked: false,
    lines: lines,
  );

  @override
  Future<List<HrTimesheetDay>> timesheet({DateTime? from, DateTime? to}) async {
    // The punch screen asks for today alone.
    if (from != null && from == to) {
      final ins = _punches.where(
        (p) => p.punchType == 'IN' && p.status == 'ACCEPTED',
      );
      return [
        if (ins.isNotEmpty)
          _day(
            '2026-10-28',
            'PRESENT',
            worked: 0,
            checkIn: ins.first.punchedAt,
          ),
      ];
    }
    return _month;
  }

  List<HrTimesheetDay> get _month => [
    _day(
      '2026-10-27',
      'PRESENT',
      late: 32,
      worked: 448,
      checkIn: DateTime(2026, 10, 27, 8, 47),
      checkOut: DateTime(2026, 10, 27, 16, 15),
      lines: const [
        HrTimesheetLine(
          lineType: 'LATE',
          status: 'APPLIED',
          minutes: 32,
          occurrence: 2,
        ),
      ],
    ),
    _day(
      '2026-10-26',
      'PRESENT',
      overtime: 90,
      worked: 570,
      checkIn: DateTime(2026, 10, 26, 7, 58),
      checkOut: DateTime(2026, 10, 26, 17, 30),
    ),
    _day('2026-10-25', 'ABSENT'),
    _day(
      '2026-10-23',
      'PRESENT',
      missing: true,
      checkIn: DateTime(2026, 10, 23, 8, 1),
    ),
    _day('2026-10-22', 'LEAVE', worked: 0),
  ];

  @override
  Future<HrRequestOptions> requestOptions() async => const HrRequestOptions(
    leaveTypes: [
      HrLeaveType(
        id: 'lt1',
        code: 'ANN',
        name: 'إجازة اعتيادية',
        paid: true,
        attachmentRequired: false,
        active: true,
      ),
      HrLeaveType(
        id: 'lt2',
        code: 'SICK',
        name: 'إجازة مرضية',
        paid: true,
        attachmentRequired: true,
        active: true,
      ),
    ],
    balances: [
      HrBalance(
        leaveType: HrRef(id: 'lt1', code: 'ANN', name: 'إجازة اعتيادية'),
        year: 2026,
        entitledDays: '21',
        carriedDays: '3',
        usedDays: '7',
        pendingDays: '2',
        remainingDays: '17',
        availableDays: '15',
      ),
      HrBalance(
        leaveType: HrRef(id: 'lt2', code: 'SICK', name: 'إجازة مرضية'),
        year: 2026,
        entitledDays: '15',
        carriedDays: '0',
        usedDays: '1',
        pendingDays: '0',
        remainingDays: '14',
        availableDays: '14',
      ),
    ],
    permissions: HrPermissionUsage(
      fromDate: '2026-10-01',
      toDate: '2026-10-31',
      usedMinutes: 90,
      usedCount: 2,
      maxMinutes: 240,
      maxCount: 4,
    ),
  );

  @override
  Future<List<HrRequest>> requests({DateTime? from, DateTime? to}) async => [
    HrRequest(
      id: 'r1',
      requestType: 'LEAVE',
      leaveType: const HrRef(id: 'lt1', code: 'ANN', name: 'إجازة اعتيادية'),
      fromDate: '2026-11-02',
      toDate: '2026-11-04',
      days: '3',
      reason: 'ظرف عائلي',
      status: 'PENDING',
      createdAt: DateTime(2026, 10, 27, 10),
      attachmentRequired: false,
      cancellable: true,
      version: 0,
    ),
    HrRequest(
      id: 'r2',
      requestType: 'PERMISSION',
      fromDate: '2026-10-20',
      fromTime: '09:00:00',
      toTime: '11:00:00',
      minutes: 120,
      status: 'APPROVED',
      createdAt: DateTime(2026, 10, 19, 15),
      reviewedBy: 'م. خالد سمير',
      attachmentRequired: false,
      cancellable: false,
      version: 1,
    ),
    HrRequest(
      id: 'r3',
      requestType: 'ATTENDANCE_CORRECTION',
      fromDate: '2026-10-15',
      fromTime: '08:05:00',
      punchType: 'IN',
      reason: 'نسيت البصمة',
      status: 'REJECTED',
      reviewNote: 'لا يوجد ما يثبت الحضور في هذا الوقت.',
      createdAt: DateTime(2026, 10, 15, 18),
      attachmentRequired: false,
      cancellable: false,
      version: 1,
    ),
  ];

  @override
  Future<HrEmployeeProfile> profile() async => const HrEmployeeProfile(
    code: 'EMP-014',
    fullName: 'أحمد محمد علي',
    status: 'ACTIVE',
    contractType: 'PERMANENT',
    attendanceType: 'SINGLE',
    department: HrRef(id: 'd1', code: 'D1', name: 'إدارة المشروعات'),
    manager: HrRef(id: 'm1', code: 'EMP-003', name: 'م. خالد سمير'),
    jobTitle: 'مهندس موقع',
    nationalId: '29001011234567',
    phone: '01001234567',
    email: 'ahmed@bonyan.eg',
    birthDate: '1990-01-01',
    hireDate: '2022-03-15',
    shift: HrRef(id: 's1', code: 'S1', name: 'الوردية الصباحية'),
    location: HrRef(id: 'l1', code: 'L1', name: 'موقع كمبوند النخيل'),
    costCenter: HrRef(id: 'c1', code: 'PRJ-021', name: 'كمبوند النخيل'),
    username: 'ahmed',
  );
}

/// Presses the fingerprint until it fills and punches.
Future<void> _holdToPunch(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(target));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 900));
  await gesture.up();
  await tester.pumpAndSettle();
}
