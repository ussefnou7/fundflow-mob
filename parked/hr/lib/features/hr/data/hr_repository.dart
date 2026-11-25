import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/time/server_clock.dart';
import '../domain/hr_models.dart';

/// What the phone reports with a punch. Trust flags are worked out by the
/// server from these values; nothing here blocks a punch on its own.
class PunchInput {
  const PunchInput({
    required this.punchType,
    required this.installationId,
    required this.deviceTime,
    required this.mockLocation,
    this.lat,
    this.lng,
    this.gpsAccuracyM,
    this.note,
    this.selfiePath,
    this.livenessOk,
    this.actionPath,
    this.challengeId,
  });

  final String punchType;
  final String installationId;
  final DateTime deviceTime;
  final bool mockLocation;
  final double? lat;
  final double? lng;
  final int? gpsAccuracyM;
  final String? note;

  /// The photo the camera took after the live check, sent beside the punch.
  final String? selfiePath;

  /// Whether that live check passed; sent only with a photo.
  final bool? livenessOk;

  /// The photo of the server's challenge, and the challenge it answers.
  final String? actionPath;
  final String? challengeId;

  PunchInput withSelfie(
    String? path, {
    required bool livenessOk,
    String? actionPath,
    String? challengeId,
  }) => PunchInput(
    punchType: punchType,
    installationId: installationId,
    deviceTime: deviceTime,
    mockLocation: mockLocation,
    lat: lat,
    lng: lng,
    gpsAccuracyM: gpsAccuracyM,
    note: note,
    selfiePath: path,
    livenessOk: path == null ? null : livenessOk,
    actionPath: path == null ? null : actionPath,
    challengeId: path == null ? null : challengeId,
  );
}

class HrRequestInput {
  const HrRequestInput({
    required this.requestType,
    required this.fromDate,
    this.leaveTypeId,
    this.toDate,
    this.fromTime,
    this.toTime,
    this.punchType,
    this.reason,
  });

  final String requestType;
  final String fromDate;
  final String? leaveTypeId;
  final String? toDate;
  final String? fromTime;
  final String? toTime;
  final String? punchType;
  final String? reason;
}

/// The employee's own HR endpoints; none needs an HR management permission.
/// Every answer keeps [clock] on the server's time.
class HrRepository {
  HrRepository(this._client, {ServerClock? clock})
    : clock = clock ?? ServerClock();
  final ApiClient _client;
  final ServerClock clock;

  Future<Response<dynamic>> _get(String path) async {
    final response = await _client.get(path);
    clock.syncFromHeader(response.headers.value('date'));
    return response;
  }

  /// The server's now, asking it when nothing has synced the clock yet.
  Future<DateTime> serverNow() async {
    final known = clock.now();
    if (known != null) return known;
    try {
      await today();
    } catch (_) {
      await _get('/hr/employees/me');
    }
    return clock.now() ?? (throw StateError('تعذّر معرفة وقت الخادم'));
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _range(DateTime? from, DateTime? to) {
    final query = Uri(
      queryParameters: {
        if (from != null) 'from': _date(from),
        if (to != null) 'to': _date(to),
      },
    ).query;
    return query.isEmpty ? '' : '?$query';
  }

  /// [installationId] says which phone asks, so the answer tells whether it
  /// is the account's bound phone.
  Future<HrToday> today({String? installationId}) async {
    final query = installationId == null
        ? ''
        : '?installationId=${Uri.encodeQueryComponent(installationId)}';
    final today = HrToday.fromJson(
      requireMap(await _get('/hr/attendance/me/today$query')),
    );
    if (today.serverTime != null) clock.sync(today.serverTime!);
    return today;
  }

  /// JSON alone, or multipart with the photos: a `punch` part holding the
  /// same JSON, a `selfie` part and, answering the server's challenge, an
  /// `action` part.
  Future<HrPunch> punch(PunchInput input) async {
    final body = {
      'punchType': input.punchType,
      'installationId': input.installationId,
      'deviceTime': input.deviceTime.toUtc().toIso8601String(),
      'lat': input.lat?.toStringAsFixed(7),
      'lng': input.lng?.toStringAsFixed(7),
      'gpsAccuracyM': input.gpsAccuracyM,
      'mockLocation': input.mockLocation,
      'note': input.note?.trim().isEmpty == true ? null : input.note?.trim(),
      'livenessOk': input.livenessOk,
      'challengeId': input.challengeId,
    };
    final selfie = input.selfiePath;
    return HrPunch.fromJson(
      requireMap(
        selfie == null
            ? await _client.postJson('/hr/attendance/punch', body)
            : await _client.postMultipartParts(
                '/hr/attendance/punch',
                jsonPartName: 'punch',
                json: body,
                files: {
                  'selfie': selfie,
                  if (input.actionPath != null) 'action': input.actionPath!,
                },
              ),
      ),
    );
  }

  /// The action the next face punch shows, drawn by the server.
  Future<HrFaceChallenge> faceChallenge() async => HrFaceChallenge.fromJson(
    requireMap(await _client.postJson('/hr/face/challenge', const {})),
  );

  /// Enrols the employee's face once, from their approved phone.
  Future<HrFaceStatus> enrolFace({
    required List<String> photoPaths,
    required String installationId,
    required bool livenessOk,
  }) async => HrFaceStatus.fromJson(
    requireMap(
      await _client.postFieldsAndFiles(
        '/hr/face/me',
        fields: {
          'installationId': installationId,
          'livenessOk': livenessOk.toString(),
        },
        filePartName: 'photos',
        filePaths: photoPaths,
      ),
    ),
  );

  Future<List<HrPunch>> punches({DateTime? from, DateTime? to}) async =>
      requireList(await _get('/hr/attendance/me${_range(from, to)}'))
          .whereType<Map>()
          .map((item) => HrPunch.fromJson(Map<String, dynamic>.from(item)))
          .toList();

  Future<List<HrTimesheetDay>> timesheet({
    DateTime? from,
    DateTime? to,
  }) async => requireList(await _get('/hr/timesheets/me${_range(from, to)}'))
      .whereType<Map>()
      .map((item) => HrTimesheetDay.fromJson(Map<String, dynamic>.from(item)))
      .toList();

  Future<List<HrTimesheetDay>> teamTimesheet({
    required DateTime from,
    required DateTime to,
    bool companyWide = false,
  }) async =>
      requireList(
            await _get(
              '${companyWide ? '/hr/timesheets' : '/hr/timesheets/team'}${_range(from, to)}',
            ),
          )
          .whereType<Map>()
          .map(
            (item) => HrTimesheetDay.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();

  Future<HrRequestOptions> requestOptions() async => HrRequestOptions.fromJson(
    requireMap(await _get('/hr/requests/me/options')),
  );

  Future<List<HrRequest>> requests({DateTime? from, DateTime? to}) async =>
      requireList(await _get('/hr/requests/me${_range(from, to)}'))
          .whereType<Map>()
          .map((item) => HrRequest.fromJson(Map<String, dynamic>.from(item)))
          .toList();

  Future<List<HrRequest>> teamRequests({bool companyWide = false}) async =>
      requireList(
            await _get(companyWide ? '/hr/requests' : '/hr/requests/team'),
          )
          .whereType<Map>()
          .map((item) => HrRequest.fromJson(Map<String, dynamic>.from(item)))
          .toList();

  Future<HrRequest> decideRequest(
    HrRequest request, {
    required bool approve,
    String? note,
  }) async => HrRequest.fromJson(
    requireMap(
      await _client.postJson(
        '/hr/requests/${request.id}/${approve ? 'approve' : 'reject'}',
        {'version': request.version, 'note': _note(note)},
      ),
    ),
  );

  Future<HrRequest> createRequest(HrRequestInput input) async =>
      HrRequest.fromJson(
        requireMap(
          await _client.postJson('/hr/requests/me', {
            'requestType': input.requestType,
            'leaveTypeId': input.leaveTypeId,
            'fromDate': input.fromDate,
            'toDate': input.toDate,
            'fromTime': input.fromTime,
            'toTime': input.toTime,
            'punchType': input.punchType,
            'reason': input.reason?.trim().isEmpty == true
                ? null
                : input.reason?.trim(),
          }),
        ),
      );

  Future<HrRequest> attach(HrRequest request, String filePath) async =>
      HrRequest.fromJson(
        requireMap(
          await _client.postMultipart(
            '/hr/requests/${request.id}/attachment',
            jsonPartName: 'request',
            json: {'requestId': request.id},
            filePartName: 'file',
            filePath: filePath,
          ),
        ),
      );

  Future<HrRequest> cancel(HrRequest request, {String? note}) async =>
      HrRequest.fromJson(
        requireMap(
          await _client.postJson('/hr/requests/${request.id}/cancel', {
            'version': request.version,
            'note': note,
          }),
        ),
      );

  // ----- The manager's approvals -----

  Future<HrApprovalSummary> approvalSummary() async =>
      HrApprovalSummary.fromJson(
        requireMap(await _get('/hr/approvals/summary')),
      );

  Future<List<HrDeviceRequest>> deviceRequests() async =>
      requireList(await _get('/hr/device-requests?status=PENDING'))
          .whereType<Map>()
          .map(
            (item) => HrDeviceRequest.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();

  Future<void> decideDeviceRequest(
    HrDeviceRequest request, {
    required bool approve,
    String? note,
  }) async => requireMap(
    await _client.postJson(
      '/hr/device-requests/${request.id}/${approve ? 'approve' : 'reject'}',
      {'version': request.version, 'note': _note(note)},
    ),
  );

  Future<List<HrPunch>> heldPunches() async =>
      requireList(await _get('/hr/attendance/held'))
          .whereType<Map>()
          .map((item) => HrPunch.fromJson(Map<String, dynamic>.from(item)))
          .toList();

  Future<void> decidePunch(
    HrPunch punch, {
    required bool approve,
    String? note,
  }) async => requireMap(
    await _client.postJson(
      '/hr/attendance/${punch.id}/${approve ? 'approve' : 'reject'}',
      {'version': punch.version, 'note': _note(note)},
    ),
  );

  static String? _note(String? note) =>
      note == null || note.trim().isEmpty ? null : note.trim();

  Future<HrEmployeeProfile> profile() async =>
      HrEmployeeProfile.fromJson(requireMap(await _get('/hr/employees/me')));

  Future<List<HrMissingBasic>> missingBasic() async =>
      requireList(await _get('/hr/payfile/missing-basic'))
          .whereType<Map>()
          .map(
            (item) => HrMissingBasic.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();

  /// The user's direct reports and whether each has a face enrolled.
  Future<List<HrTeamFace>> teamFaces() async =>
      requireList(await _get('/hr/face/team'))
          .whereType<Map>()
          .map((item) => HrTeamFace.fromJson(Map<String, dynamic>.from(item)))
          .toList();

  /// Deletes a report's enrolled face; they enrol again before their next face punch.
  Future<void> resetFace(String employeeId) async {
    await _client.postJson('/hr/face/employees/$employeeId/reset', const {});
  }

  Future<List<HrMyPayslip>> payslips() async =>
      requireList(await _get('/hr/payslips/me'))
          .whereType<Map>()
          .map((item) => HrMyPayslip.fromJson(Map<String, dynamic>.from(item)))
          .toList();
}
