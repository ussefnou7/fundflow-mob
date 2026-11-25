import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/dashboard_models.dart';

class DashboardRepository {
  DashboardRepository(this._client);
  final ApiClient _client;

  Future<FollowUpBoard> load() async =>
      FollowUpBoard.fromJson(requireMap(await _client.get('/dashboard')));
}
