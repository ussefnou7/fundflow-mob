import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/workspace_context.dart';

class WorkspaceRepository {
  const WorkspaceRepository(this._client);
  final ApiClient _client;

  Future<WorkspaceContext> load() async => WorkspaceContext.fromJson(
    requireMap(await _client.get('/organization/context')),
  );

  Future<WorkspaceContext> selectCompany(String companyId) async {
    final response = await _client.postJson('/organization/context/company', {
      'companyId': companyId,
    });
    if (response.statusCode != 204) throw ApiError.fromResponse(response);
    return load();
  }

  Future<Uint8List?> loadTenantLogo() async {
    final response = await _client.getBytes('/organization/tenant-logo');
    if (response.statusCode != 200 || response.data == null) return null;
    return Uint8List.fromList(response.data!);
  }
}
