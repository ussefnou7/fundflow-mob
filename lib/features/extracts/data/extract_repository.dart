import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/format/exact_decimal.dart';
import '../domain/extract_models.dart';

class ExtractRepository {
  const ExtractRepository(this._client);

  final ApiClient _client;

  Future<ExtractOptions> options() async => ExtractOptions.fromJson(
    requireMap(await _client.get('/contractor-extracts/options')),
  );

  Future<List<ContractorExtract>> list({
    String? contractorId,
    String? centerId,
  }) async {
    final query = <String, String>{
      if (contractorId != null && contractorId.isNotEmpty)
        'contractorId': contractorId,
      if (centerId != null && centerId.isNotEmpty) 'centerId': centerId,
    };
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    return requireList(await _client.get('/contractor-extracts$suffix'))
        .whereType<Map>()
        .map(
          (item) => ContractorExtract.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<ContractorExtract> get(String id) async => ContractorExtract.fromJson(
    requireMap(await _client.get('/contractor-extracts/$id')),
  );

  Future<ContractorExtract> create({
    required String contractorId,
    required String centerId,
    required String extractDate,
    required List<ExtractLineInput> items,
    String? note,
  }) async {
    return ContractorExtract.fromJson(
      requireMap(
        await _client.postJson('/contractor-extracts', {
          'contractorId': contractorId,
          'centerId': centerId,
          'extractDate': extractDate,
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
          'items': items.map((item) => item.toJson()).toList(),
        }),
      ),
    );
  }

  Future<ContractorExtract> update({
    required ContractorExtract extract,
    required String extractDate,
    required List<ExtractLineInput> items,
    String? note,
  }) async => ContractorExtract.fromJson(
    requireMap(
      await _client.putJson('/contractor-extracts/${extract.id}', {
        'contractorId': extract.contractorId,
        'centerId': extract.centerId,
        'extractDate': extractDate,
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
        'items': items.map((item) => item.toJson()).toList(),
        'version': extract.version,
      }),
    ),
  );

  Future<void> recordMeasurement({
    required String extractId,
    required Map<String, String> percentages,
  }) async {
    requireList(
      await _client.postJson('/contractor-extracts/$extractId/measurements', {
        'items': percentages.entries
            .map((entry) => {'itemId': entry.key, 'percentage': entry.value})
            .toList(),
      }),
    );
  }

  Future<void> reviewMeasurements({
    required String extractId,
    required List<String> ids,
    required String decision,
  }) async {
    requireList(
      await _client.postJson(
        '/contractor-extracts/$extractId/measurements/review',
        {'measurementIds': ids, 'decision': decision},
      ),
    );
  }

  Future<ContractorExtract> addItem({
    required String extractId,
    required AddedExtractItemInput item,
  }) async => ContractorExtract.fromJson(
    requireMap(
      await _client.postJson(
        '/contractor-extracts/$extractId/items',
        item.toJson(),
      ),
    ),
  );

  Future<ContractorExtract> reviewItem({
    required String extractId,
    required String itemId,
    required String decision,
    String? rate,
    String? clientRate,
  }) async => ContractorExtract.fromJson(
    requireMap(
      await _client
          .postJson('/contractor-extracts/$extractId/items/$itemId/review', {
            'decision': decision,
            if (rate != null) 'rate': ExactDecimal.parse(rate).toString(),
            if (clientRate != null)
              'clientRate': ExactDecimal.parse(clientRate).toString(),
          }),
    ),
  );

  Future<ContractorExtract> review({
    required ContractorExtract extract,
    required String decision,
    String? reason,
  }) async => ContractorExtract.fromJson(
    requireMap(
      await _client.postJson('/contractor-extracts/${extract.id}/review', {
        'decision': decision,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        'version': extract.version,
      }),
    ),
  );
}
