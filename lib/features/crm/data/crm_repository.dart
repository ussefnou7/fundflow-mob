import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/crm_models.dart';

class CrmRepository {
  const CrmRepository(this._client);
  final ApiClient _client;
  Future<CrmInspectionDashboard> inspectionDashboard(
    CrmDashboardPeriod period,
  ) async => CrmInspectionDashboard.fromJson(
    requireMap(
      await _client.get('/crm/inspections/dashboard?period=${period.api}'),
    ),
  );

  Future<CrmPage<CrmLeadSummary>> leads({
    String? q,
    String? status,
    int page = 0,
    int size = 20,
  }) async {
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'size': '$size',
        if (q?.isNotEmpty == true) 'q': q,
        if (status?.isNotEmpty == true) 'status': status,
      },
    ).query;
    final json = requireMap(await _client.get('/crm/leads?$query'));
    return CrmPage(
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CrmLeadSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? page,
      size: (json['size'] as num?)?.toInt() ?? size,
    );
  }

  Future<List<CrmLeadSummary>> dueFollowUps() async =>
      requireList(await _client.get('/crm/leads/due-follow-ups'))
          .whereType<Map>()
          .map((e) => CrmLeadSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
  Future<CrmLeadDetail> lead(String id) async =>
      CrmLeadDetail.fromJson(requireMap(await _client.get('/crm/leads/$id')));
  Future<List<CrmRef>> sources() async =>
      requireList(await _client.get('/crm/sources'))
          .whereType<Map>()
          .map((item) => CrmRef.fromJson(item))
          .toList(growable: false);
  Future<List<CrmRef>> organizationUsers() async {
    final options = requireMap(await _client.get('/organization/options'));
    return (options['users'] as List? ?? const [])
        .whereType<Map>()
        .where((item) => item['active'] != false)
        .map((item) => CrmRef.fromJson(item))
        .toList(growable: false);
  }

  Future<List<CrmRef>> inspectionEngineers() async =>
      requireList(await _client.get('/crm/inspections/engineers'))
          .whereType<Map>()
          .map((item) => CrmRef.fromJson(item))
          .toList(growable: false);
  Future<List<CrmRef>> inspectionTypes() async =>
      requireList(await _client.get('/crm/inspection-types'))
          .whereType<Map>()
          .map((item) => CrmRef.fromJson(item))
          .toList(growable: false);

  Future<List<CrmFollowUp>> followUps(String leadId) async =>
      requireList(await _client.get('/crm/leads/$leadId/follow-ups'))
          .whereType<Map>()
          .map((item) => CrmFollowUp.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
  Future<CrmLeadDetail> saveLead({
    CrmLeadDetail? lead,
    required String name,
    required String mobile,
    String? altMobile,
    String? area,
    String? address,
    String? notes,
    String? sourceId,
    String? ownerId,
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'mobile': mobile.trim(),
      'altMobile': altMobile?.trim().isEmpty == true ? null : altMobile?.trim(),
      'area': area?.trim().isEmpty == true ? null : area?.trim(),
      'address': address?.trim().isEmpty == true ? null : address?.trim(),
      'sourceId': sourceId?.isEmpty == true
          ? null
          : sourceId ?? lead?.source?.id,
      'ownerId': ownerId?.isEmpty == true ? null : ownerId ?? lead?.owner?.id,
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      if (lead != null) 'version': lead.version,
    };
    final response = lead == null
        ? await _client.postJson('/crm/leads', body)
        : await _client.putJson('/crm/leads/${lead.id}', body);
    return CrmLeadDetail.fromJson(requireMap(response));
  }

  Future<CrmFollowUp> addFollowUp(
    String leadId, {
    required String channel,
    required String outcome,
    String? note,
    String? nextFollowUpAt,
  }) async => CrmFollowUp.fromJson(
    requireMap(
      await _client.postJson('/crm/leads/$leadId/follow-ups', {
        'channel': channel,
        'outcome': outcome,
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
        'nextFollowUpAt': nextFollowUpAt?.isEmpty == true
            ? null
            : nextFollowUpAt,
      }),
    ),
  );
  Future<CrmPage<CrmInspection>> inspections({
    String? from,
    String? to,
    String? status,
    String? engineerId,
    String? leadId,
    int page = 0,
    int size = 20,
  }) async {
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'size': '$size',
        'from': ?from,
        'to': ?to,
        if (status?.isNotEmpty == true) 'status': status,
        if (engineerId?.isNotEmpty == true) 'engineerId': engineerId,
        'leadId': ?leadId,
      },
    ).query;
    final json = requireMap(await _client.get('/crm/inspections?$query'));
    return CrmPage(
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => CrmInspection.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? page,
      size: (json['size'] as num?)?.toInt() ?? size,
    );
  }

  Future<CrmInspection> inspection(String id) async => CrmInspection.fromJson(
    requireMap(await _client.get('/crm/inspections/$id')),
  );
  Future<CrmInspection> addInspection({
    required String leadId,
    required String inspectionTypeId,
    required String scheduledAt,
    required String engineerId,
    required num agreedPrice,
    String? address,
  }) async => CrmInspection.fromJson(
    requireMap(
      await _client.postJson('/crm/inspections', {
        'leadId': leadId,
        'inspectionTypeId': inspectionTypeId,
        'scheduledAt': scheduledAt,
        'address': address?.trim().isEmpty == true ? null : address?.trim(),
        'locationUrl': null,
        'engineerId': engineerId,
        'agreedPrice': agreedPrice,
        'notes': null,
      }),
    ),
  );
}
