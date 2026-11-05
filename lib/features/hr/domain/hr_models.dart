/// Self-service HR: what the signed-in employee sees about their own
/// attendance, requests and file. Mirrors the backend's HR DTOs.
library;

import '../../../core/time/server_clock.dart';

/// Times read as the server's wall clock, never converted to the phone's zone.
DateTime? _time(Object? value) => serverWallTime(value);
String? _text(Object? value) => value?.toString();
int _int(Object? value) => (value as num?)?.toInt() ?? 0;
int? _intOrNull(Object? value) => (value as num?)?.toInt();
String _decimal(Object? value) => value?.toString() ?? '0';
List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const [])
    .whereType<Map>()
    .map((item) => Map<String, dynamic>.from(item))
    .toList(growable: false);

class HrRef {
  const HrRef({required this.id, required this.code, required this.name});

  static HrRef? from(Object? json) {
    if (json is! Map) return null;
    return HrRef(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  final String id;
  final String code;
  final String name;
}

class HrPlace {
  const HrPlace({
    this.id = '',
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusM,
  });

  factory HrPlace.fromJson(Map<String, dynamic> json) => HrPlace(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    lat: double.tryParse(json['lat'].toString()) ?? 0,
    lng: double.tryParse(json['lng'].toString()) ?? 0,
    radiusM: _int(json['radiusM']),
  );

  final String id;
  final String name;
  final double lat;
  final double lng;
  final int radiusM;
}

class HrPunch {
  const HrPunch({
    required this.id,
    required this.punchType,
    required this.punchedAt,
    required this.dateTrx,
    required this.status,
    this.location,
    this.distanceM,
    this.gpsAccuracyM,
    this.trustFlags = const [],
    this.employee,
    this.note,
    this.version = 0,
    this.selfie = false,
    this.faceScore,
  });

  factory HrPunch.fromJson(Map<String, dynamic> json) => HrPunch(
    id: json['id'].toString(),
    punchType: json['punchType']?.toString() ?? 'IN',
    punchedAt: _time(json['punchedAt']) ?? DateTime.now(),
    dateTrx: json['dateTrx']?.toString() ?? '',
    status: json['status']?.toString() ?? 'ACCEPTED',
    location: HrRef.from(json['location']),
    distanceM: _intOrNull(json['distanceM']),
    gpsAccuracyM: _intOrNull(json['gpsAccuracyM']),
    trustFlags: (json['trustFlags'] as List? ?? const [])
        .map((flag) => flag.toString())
        .toList(growable: false),
    employee: HrRef.from(json['employee']),
    note: _text(json['note']),
    version: _int(json['version']),
    selfie: json['selfie'] == true,
    faceScore: _text(json['faceScore']),
  );

  /// IN or OUT.
  final String punchType;
  final String id;
  final DateTime punchedAt;
  final String dateTrx;

  /// ACCEPTED, PENDING (from a phone not bound to the account, until the
  /// manager decides), REVIEW or REJECTED.
  final String status;
  final HrRef? location;
  final int? distanceM;
  final int? gpsAccuracyM;
  final List<String> trustFlags;
  final HrRef? employee;

  /// What the employee wrote with the punch.
  final String? note;
  final int version;

  /// A photo came with the punch; [faceScore] is its match, null unmatched.
  final bool selfie;
  final String? faceScore;
}

/// The employee's own face enrolment. [available] is false when face punch
/// is off on the server.
class HrFaceStatus {
  const HrFaceStatus({
    required this.available,
    required this.enrolled,
    this.photos = 0,
  });

  factory HrFaceStatus.fromJson(Map<String, dynamic> json) => HrFaceStatus(
    available: json['available'] == true,
    enrolled: json['enrolled'] == true,
    photos: _int(json['photos']),
  );

  final bool available;
  final bool enrolled;
  final int photos;
}

/// The action the server asks of the next face punch; its id goes back with
/// the punch.
class HrFaceChallenge {
  const HrFaceChallenge({required this.id, required this.action});

  factory HrFaceChallenge.fromJson(Map<String, dynamic> json) =>
      HrFaceChallenge(
        id: json['id']?.toString() ?? '',
        action: json['action']?.toString() ?? '',
      );

  final String id;

  /// `TURN_RIGHT` or `TURN_LEFT`.
  final String action;
}

/// A direct report's face as their manager sees it: enrolled or not.
class HrTeamFace {
  const HrTeamFace({
    required this.employee,
    required this.enrolled,
    this.enrolledAt,
  });

  factory HrTeamFace.fromJson(Map<String, dynamic> json) => HrTeamFace(
    employee:
        HrRef.from(json['employee']) ?? const HrRef(id: '', code: '', name: ''),
    enrolled: json['enrolled'] == true,
    enrolledAt: _time(json['enrolledAt']),
  );

  final HrRef employee;
  final bool enrolled;
  final DateTime? enrolledAt;
}

/// An employee asking to bind a phone, for their direct manager (or HR).
class HrDeviceRequest {
  const HrDeviceRequest({
    required this.id,
    required this.employee,
    required this.platform,
    required this.deviceName,
    required this.requestedAt,
    this.version = 0,
    this.model,
    this.appVersion,
    this.takenByOther = false,
    this.replacesPhone,
  });

  factory HrDeviceRequest.fromJson(Map<String, dynamic> json) =>
      HrDeviceRequest(
        id: json['id'].toString(),
        employee:
            HrRef.from(json['employee']) ??
            const HrRef(id: '', code: '', name: ''),
        platform: json['platform']?.toString() ?? '',
        deviceName: json['deviceName']?.toString() ?? '',
        model: _text(json['model']),
        appVersion: _text(json['appVersion']),
        takenByOther: json['takenByOther'] == true,
        replacesPhone: _text(json['replacesPhone']),
        requestedAt: _time(json['requestedAt']),
        version: _int(json['version']),
      );

  final String id;
  final HrRef employee;
  final String platform;
  final String deviceName;
  final String? model;
  final String? appVersion;

  /// The phone is bound to another account now; approving moves it.
  final bool takenByOther;

  /// The employee's current phone, which approving replaces.
  final String? replacesPhone;
  final DateTime? requestedAt;
  final int version;
}

/// Whether the user decides on anyone's phones or punches, and what waits.
class HrApprovalSummary {
  const HrApprovalSummary({
    this.decides = false,
    this.deviceRequests = 0,
    this.heldPunches = 0,
  });

  factory HrApprovalSummary.fromJson(Map<String, dynamic> json) =>
      HrApprovalSummary(
        decides: json['decides'] == true,
        deviceRequests: _int(json['deviceRequests']),
        heldPunches: _int(json['heldPunches']),
      );

  final bool decides;
  final int deviceRequests;
  final int heldPunches;
  int get waiting => deviceRequests + heldPunches;
}

class HrShiftDay {
  const HrShiftDay({
    required this.code,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.overnight,
    this.punchFrom,
    this.punchTo,
  });

  factory HrShiftDay.fromJson(Map<String, dynamic> json) => HrShiftDay(
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    startTime: json['startTime']?.toString() ?? '',
    endTime: json['endTime']?.toString() ?? '',
    overnight: json['overnight'] == true,
    punchFrom: _time(json['punchFrom']),
    punchTo: _time(json['punchTo']),
  );

  final String code;
  final String name;
  final String startTime;
  final String endTime;
  final bool overnight;
  final DateTime? punchFrom;
  final DateTime? punchTo;
}

/// The employee's working day: where they may punch and what they punched.
class HrToday {
  const HrToday({
    required this.employee,
    required this.status,
    required this.deviceStatus,
    required this.dateTrx,
    required this.attendanceType,
    required this.places,
    required this.punches,
    this.shift,
    this.firstIn,
    this.lastOut,
    this.elapsedMinutes,
    this.serverTime,
    this.onBoundPhone,
    this.bindingRequested = false,
    this.selfieRequired = false,
    this.faceAvailable = false,
    this.faceEnrolled = false,
  });

  factory HrToday.fromJson(Map<String, dynamic> json) => HrToday(
    employee: HrRef.from(json['employee']),
    status: json['status']?.toString() ?? 'ACTIVE',
    deviceStatus: _text(json['deviceStatus']),
    dateTrx: json['dateTrx']?.toString() ?? '',
    shift: json['shift'] is Map
        ? HrShiftDay.fromJson(Map<String, dynamic>.from(json['shift'] as Map))
        : null,
    attendanceType: json['attendanceType']?.toString() ?? 'FREE',
    places: _maps(json['places']).map(HrPlace.fromJson).toList(),
    punches: _maps(json['punches']).map(HrPunch.fromJson).toList(),
    firstIn: _time(json['firstIn']),
    lastOut: _time(json['lastOut']),
    elapsedMinutes: _intOrNull(json['elapsedMinutes']),
    serverTime: _text(json['serverTime']),
    onBoundPhone: json['onBoundPhone'] as bool?,
    bindingRequested: json['bindingRequested'] == true,
    selfieRequired: json['selfieRequired'] == true,
    faceAvailable: json['faceAvailable'] == true,
    faceEnrolled: json['faceEnrolled'] == true,
  );

  final HrRef? employee;
  final String status;

  /// The account's bound phone: ACTIVE, REVOKED, PENDING (bound before
  /// approvals existed), or null when it has none.
  final String? deviceStatus;

  /// Whether the asking phone is the account's bound one; null when unknown.
  final bool? onBoundPhone;

  /// The account asked to bind the asking phone and the manager has not
  /// decided yet.
  final bool bindingRequested;
  final String dateTrx;
  final HrShiftDay? shift;

  /// SINGLE or MULTI must punch at a place; FREE may punch anywhere.
  final String attendanceType;
  final List<HrPlace> places;
  final List<HrPunch> punches;
  final DateTime? firstIn;
  final DateTime? lastOut;
  final int? elapsedMinutes;

  /// The server's clock when it answered, as sent, to sync [ServerClock].
  final String? serverTime;

  /// The shift asks for a selfie with every punch.
  final bool selfieRequired;

  /// Face punch is on at the server, and whether the employee enrolled.
  final bool faceAvailable;
  final bool faceEnrolled;

  /// Only the shift decides whether this punch requires a face.
  bool get takesSelfie => selfieRequired;

  /// Enrolment is open only from the account's approved phone.
  bool get mayEnrolFace =>
      selfieRequired &&
      faceAvailable &&
      !faceEnrolled &&
      onBoundPhone == true &&
      deviceStatus == 'ACTIVE';

  /// The next punch the employee is expected to make.
  String get nextPunch =>
      punches.isEmpty || punches.last.punchType == 'OUT' ? 'IN' : 'OUT';
  bool get stillIn => punches.isNotEmpty && punches.last.punchType == 'IN';
  bool get needsPlace => attendanceType != 'FREE';
}

class HrTimesheetLine {
  const HrTimesheetLine({
    this.id = '',
    required this.lineType,
    required this.status,
    this.version = 0,
    this.minutes,
    this.occurrence,
    this.penaltyType,
    this.penaltyValue,
    this.multiplier,
    this.payItem,
  });

  factory HrTimesheetLine.fromJson(Map<String, dynamic> json) =>
      HrTimesheetLine(
        id: json['id']?.toString() ?? '',
        lineType: json['lineType']?.toString() ?? '',
        status: json['status']?.toString() ?? 'APPLIED',
        version: _int(json['version']),
        minutes: _intOrNull(json['minutes']),
        occurrence: _intOrNull(json['occurrence']),
        penaltyType: _text(json['penaltyType']),
        penaltyValue: _text(json['penaltyValue']),
        multiplier: _text(json['multiplier']),
        payItem: HrRef.from(json['payItem']),
      );

  final String id;

  /// LATE, EARLY_LEAVE, ABSENCE, MISSING_PUNCH or OVERTIME.
  final String lineType;

  /// APPLIED, DRAFT or REJECTED.
  final String status;
  final int version;
  final int? minutes;
  final int? occurrence;
  final String? penaltyType;
  final String? penaltyValue;
  final String? multiplier;
  final HrRef? payItem;
}

class HrTimesheetDay {
  const HrTimesheetDay({
    this.id = '',
    required this.workDate,
    required this.dayType,
    required this.status,
    required this.plannedMinutes,
    required this.workedMinutes,
    required this.lateMinutes,
    required this.earlyLeaveMinutes,
    required this.permissionMinutes,
    required this.overtimeMinutes,
    required this.approvedOvertimeMinutes,
    required this.missingPunch,
    required this.locked,
    required this.lines,
    this.version = 0,
    this.employee,
    this.shift,
    this.shiftStart,
    this.shiftEnd,
    this.checkIn,
    this.checkOut,
  });

  factory HrTimesheetDay.fromJson(Map<String, dynamic> json) => HrTimesheetDay(
    id: json['id']?.toString() ?? '',
    employee: HrRef.from(json['employee']),
    workDate: json['workDate']?.toString() ?? '',
    shift: HrRef.from(json['shift']),
    shiftStart: _time(json['shiftStart']),
    shiftEnd: _time(json['shiftEnd']),
    dayType: json['dayType']?.toString() ?? 'WORKDAY',
    status: json['status']?.toString() ?? 'PRESENT',
    checkIn: _time(json['checkIn']),
    checkOut: _time(json['checkOut']),
    plannedMinutes: _int(json['plannedMinutes']),
    workedMinutes: _int(json['workedMinutes']),
    lateMinutes: _int(json['lateMinutes']),
    earlyLeaveMinutes: _int(json['earlyLeaveMinutes']),
    permissionMinutes: _int(json['permissionMinutes']),
    overtimeMinutes: _int(json['overtimeMinutes']),
    approvedOvertimeMinutes: _int(json['approvedOvertimeMinutes']),
    missingPunch: json['missingPunch'] == true,
    locked: json['locked'] == true,
    lines: _maps(json['lines']).map(HrTimesheetLine.fromJson).toList(),
    version: _int(json['version']),
  );

  final String id;
  final HrRef? employee;
  final String workDate;
  final HrRef? shift;
  final DateTime? shiftStart;
  final DateTime? shiftEnd;

  /// WORKDAY, REST_DAY or HOLIDAY.
  final String dayType;

  /// PRESENT, ABSENT, LEAVE, PERMISSION, HOLIDAY, REST_DAY or MISSION.
  final String status;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int plannedMinutes;
  final int workedMinutes;
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final int permissionMinutes;
  final int overtimeMinutes;
  final int approvedOvertimeMinutes;
  final bool missingPunch;
  final bool locked;
  final List<HrTimesheetLine> lines;
  final int version;
}

class HrLeaveType {
  const HrLeaveType({
    required this.id,
    required this.code,
    required this.name,
    required this.paid,
    required this.attachmentRequired,
    required this.active,
  });

  factory HrLeaveType.fromJson(Map<String, dynamic> json) => HrLeaveType(
    id: json['id'].toString(),
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    paid: json['paid'] == true,
    attachmentRequired: json['attachmentRequired'] == true,
    active: json['active'] != false,
  );

  final String id;
  final String code;
  final String name;
  final bool paid;
  final bool attachmentRequired;
  final bool active;
}

class HrBalance {
  const HrBalance({
    required this.leaveType,
    required this.year,
    required this.entitledDays,
    required this.carriedDays,
    required this.usedDays,
    required this.pendingDays,
    required this.remainingDays,
    required this.availableDays,
  });

  factory HrBalance.fromJson(Map<String, dynamic> json) => HrBalance(
    leaveType: HrRef.from(json['leaveType']),
    year: _int(json['year']),
    entitledDays: _decimal(json['entitledDays']),
    carriedDays: _decimal(json['carriedDays']),
    usedDays: _decimal(json['usedDays']),
    pendingDays: _decimal(json['pendingDays']),
    remainingDays: _decimal(json['remainingDays']),
    availableDays: _decimal(json['availableDays']),
  );

  final HrRef? leaveType;
  final int year;
  final String entitledDays;
  final String carriedDays;
  final String usedDays;
  final String pendingDays;

  /// Entitled + carried − used.
  final String remainingDays;

  /// Remaining, less leave still pending.
  final String availableDays;
}

class HrPermissionUsage {
  const HrPermissionUsage({
    required this.fromDate,
    required this.toDate,
    required this.usedMinutes,
    required this.usedCount,
    this.maxMinutes,
    this.maxCount,
  });

  factory HrPermissionUsage.fromJson(Map<String, dynamic> json) =>
      HrPermissionUsage(
        fromDate: json['fromDate']?.toString() ?? '',
        toDate: json['toDate']?.toString() ?? '',
        usedMinutes: _int(json['usedMinutes']),
        usedCount: _int(json['usedCount']),
        maxMinutes: _intOrNull(json['maxMinutes']),
        maxCount: _intOrNull(json['maxCount']),
      );

  final String fromDate;
  final String toDate;
  final int usedMinutes;
  final int usedCount;
  final int? maxMinutes;
  final int? maxCount;
}

class HrRequestOptions {
  const HrRequestOptions({
    required this.leaveTypes,
    required this.balances,
    this.employee,
    this.permissions,
  });

  factory HrRequestOptions.fromJson(Map<String, dynamic> json) =>
      HrRequestOptions(
        employee: HrRef.from(json['employee']),
        leaveTypes: _maps(
          json['leaveTypes'],
        ).map(HrLeaveType.fromJson).toList(),
        balances: _maps(json['balances']).map(HrBalance.fromJson).toList(),
        permissions: json['permissions'] is Map
            ? HrPermissionUsage.fromJson(
                Map<String, dynamic>.from(json['permissions'] as Map),
              )
            : null,
      );

  final HrRef? employee;
  final List<HrLeaveType> leaveTypes;
  final List<HrBalance> balances;
  final HrPermissionUsage? permissions;
}

class HrRequest {
  const HrRequest({
    required this.id,
    required this.requestType,
    required this.fromDate,
    required this.status,
    required this.attachmentRequired,
    required this.cancellable,
    required this.version,
    this.employee,
    this.leaveType,
    this.toDate,
    this.fromTime,
    this.toTime,
    this.punchType,
    this.days,
    this.minutes,
    this.reason,
    this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote,
    this.attachmentName,
    this.decidable = false,
  });

  factory HrRequest.fromJson(Map<String, dynamic> json) => HrRequest(
    id: json['id'].toString(),
    employee: HrRef.from(json['employee']),
    requestType: json['requestType']?.toString() ?? 'LEAVE',
    leaveType: HrRef.from(json['leaveType']),
    fromDate: json['fromDate']?.toString() ?? '',
    toDate: _text(json['toDate']),
    fromTime: _text(json['fromTime']),
    toTime: _text(json['toTime']),
    punchType: _text(json['punchType']),
    days: _text(json['days']),
    minutes: _intOrNull(json['minutes']),
    reason: _text(json['reason']),
    status: json['status']?.toString() ?? 'PENDING',
    createdAt: _time(json['createdAt']),
    reviewedBy: _text(json['reviewedBy']),
    reviewedAt: _time(json['reviewedAt']),
    reviewNote: _text(json['reviewNote']),
    attachmentName: json['attachment'] is Map
        ? (json['attachment'] as Map)['name']?.toString()
        : null,
    attachmentRequired: json['attachmentRequired'] == true,
    decidable: json['decidable'] == true,
    cancellable: json['cancellable'] == true,
    version: _int(json['version']),
  );

  /// LEAVE, PERMISSION, MISSION or ATTENDANCE_CORRECTION.
  final String requestType;
  final String id;
  final HrRef? employee;
  final HrRef? leaveType;
  final String fromDate;
  final String? toDate;
  final String? fromTime;
  final String? toTime;
  final String? punchType;
  final String? days;
  final int? minutes;
  final String? reason;

  /// PENDING, APPROVED, REJECTED or CANCELLED.
  final String status;
  final DateTime? createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final String? attachmentName;
  final bool attachmentRequired;
  final bool decidable;
  final bool cancellable;
  final int version;
}

class HrMissingBasic {
  const HrMissingBasic({
    required this.employeeId,
    required this.code,
    required this.fullName,
  });

  factory HrMissingBasic.fromJson(Map<String, dynamic> json) => HrMissingBasic(
    employeeId: json['employeeId']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    fullName: json['fullName']?.toString() ?? '',
  );

  final String employeeId;
  final String code;
  final String fullName;
}

class HrMyPayslip {
  const HrMyPayslip({
    required this.id,
    required this.fromDate,
    required this.toDate,
    required this.gross,
    required this.net,
    this.payDate,
  });

  factory HrMyPayslip.fromJson(Map<String, dynamic> json) => HrMyPayslip(
    id: json['id']?.toString() ?? '',
    fromDate: json['fromDate']?.toString() ?? '',
    toDate: json['toDate']?.toString() ?? '',
    payDate: _text(json['payDate']),
    gross: _decimal(json['gross']),
    net: _decimal(json['net']),
  );

  final String id;
  final String fromDate;
  final String toDate;
  final String? payDate;
  final String gross;
  final String net;
}

/// The employee's own file, as HR holds it (no pay data).
class HrEmployeeProfile {
  const HrEmployeeProfile({
    required this.code,
    required this.fullName,
    required this.status,
    required this.contractType,
    required this.attendanceType,
    this.department,
    this.manager,
    this.jobTitle,
    this.nationalId,
    this.phone,
    this.email,
    this.birthDate,
    this.hireDate,
    this.contractEndDate,
    this.terminationDate,
    this.shift,
    this.location,
    this.locationSet,
    this.costCenter,
    this.username,
  });

  factory HrEmployeeProfile.fromJson(Map<String, dynamic> json) =>
      HrEmployeeProfile(
        code: json['code']?.toString() ?? '',
        fullName:
            json['fullName']?.toString() ??
            '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim(),
        status: json['status']?.toString() ?? 'ACTIVE',
        contractType: json['contractType']?.toString() ?? '',
        attendanceType: json['attendanceType']?.toString() ?? 'FREE',
        department: HrRef.from(json['department']),
        manager: HrRef.from(json['manager']),
        jobTitle: _text(json['jobTitle']),
        nationalId: _text(json['nationalid']),
        phone: _text(json['phone']),
        email: _text(json['email']),
        birthDate: _text(json['birthDate']),
        hireDate: _text(json['hireDate']),
        contractEndDate: _text(json['contractEndDate']),
        terminationDate: _text(json['terminationDate']),
        shift: HrRef.from(json['shift']),
        location: HrRef.from(json['location']),
        locationSet: HrRef.from(json['locationSet']),
        costCenter: HrRef.from(json['defaultCostCenter']),
        username: _text(json['username']),
      );

  final String code;
  final String fullName;
  final String status;
  final String contractType;
  final String attendanceType;
  final HrRef? department;
  final HrRef? manager;
  final String? jobTitle;
  final String? nationalId;
  final String? phone;
  final String? email;
  final String? birthDate;
  final String? hireDate;
  final String? contractEndDate;
  final String? terminationDate;
  final HrRef? shift;
  final HrRef? location;
  final HrRef? locationSet;
  final HrRef? costCenter;
  final String? username;
}
