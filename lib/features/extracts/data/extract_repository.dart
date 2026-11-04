import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
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

  Future<void> create({
    required String contractorId,
    required String centerId,
    required String extractDate,
    required List<QuantityLineInput> items,
    String? note,
  }) async {
    requireMap(
      await _client.postJson('/contractor-extracts', {
        'contractorId': contractorId,
        'centerId': centerId,
        'extractDate': extractDate,
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
        'items': items.map((item) => item.toJson()).toList(),
      }),
    );
  }

  Future<void> priceAndApprove({
    required ContractorExtract extract,
    required List<PriceLineInput> items,
  }) async {
    requireMap(
      await _client
          .postJson('/contractor-extracts/${extract.id}/price-and-approve', {
            'version': extract.version,
            'items': items.map((item) => item.toJson()).toList(),
          }),
    );
  }

  Future<void> reject({
    required ContractorExtract extract,
    required String reason,
  }) async {
    requireMap(
      await _client.postJson('/contractor-extracts/${extract.id}/review', {
        'decision': 'REJECTED',
        'reason': reason.trim(),
        'version': extract.version,
      }),
    );
  }
}
