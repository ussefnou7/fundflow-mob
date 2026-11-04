import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/cost_center_financial_detail.dart';
import '../domain/contractor_financial_detail.dart';
import '../domain/settings_models.dart';

class SettingsRepository {
  const SettingsRepository(this._client);

  final ApiClient _client;

  Future<ReferencePage> findAll({
    required SettingsSection section,
    String query = '',
    bool? active,
    String? type,
    bool subCategoriesOnly = false,
    String? financial,
    String? payment,
    int page = 0,
    int size = 10,
  }) async {
    final parameters = <String, String>{
      'q': query.trim(),
      'page': '$page',
      'size': '$size',
      if (active != null) 'active': '$active',
      if (type != null && type.isNotEmpty) 'type': type,
      if (subCategoriesOnly) 'subsOnly': 'true',
      if (financial != null && financial.isNotEmpty) 'financial': financial,
      if (payment != null && payment.isNotEmpty) 'payment': payment,
    };
    final endpoint = section == SettingsSection.costCenters
        ? '/settings/cost-centers/financials'
        : '/settings/${section.slug}';
    return ReferencePage.fromJson(
      requireMap(
        await _client.get(
          '$endpoint?${Uri(queryParameters: parameters).query}',
        ),
      ),
    );
  }

  Future<List<ReferenceRecord>> categoryParents() async {
    final page = ReferencePage.fromJson(
      requireMap(
        await _client.get(
          '/settings/expense-categories?active=true&page=0&size=100',
        ),
      ),
    );
    return page.items.where((item) => item.parentId == null).toList();
  }

  Future<ReferenceRecord> save({
    required SettingsSection section,
    required String name,
    required String code,
    required bool active,
    ReferenceRecord? current,
    String? type,
    String? parentId,
    String? inputMode,
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'code': code.trim(),
      'active': active,
      'type': section == SettingsSection.costCenters ? type : null,
      'parentId': section == SettingsSection.expenseCategories
          ? parentId
          : null,
      'inputMode': section == SettingsSection.units ? inputMode : null,
      if (current != null) 'version': current.version,
    };
    final path =
        '/settings/${section.slug}${current == null ? '' : '/${current.id}'}';
    final response = current == null
        ? await _client.postJson(path, body)
        : await _client.putJson(path, body);
    return ReferenceRecord.fromJson(requireMap(response));
  }

  Future<ContractorFinancial> contractorFinancial(String id) async =>
      ContractorFinancial.fromJson(
        requireMap(await _client.get('/settings/contractors/$id/financials')),
      );

  Future<CostCenterFinancialDetail> costCenterFinancial(String id) async =>
      CostCenterFinancialDetail.fromJson(
        requireMap(await _client.get('/settings/cost-centers/$id/financials')),
      );

  Future<ContractorFinancialDetail> contractorFinancialDetail(
    String id,
  ) async => ContractorFinancialDetail.fromJson(
    requireMap(await _client.get('/settings/contractors/$id/financials')),
  );
}
