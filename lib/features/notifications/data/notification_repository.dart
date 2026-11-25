import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/notification_models.dart';

class NotificationRepository {
  const NotificationRepository(this._client);

  final ApiClient _client;

  /// HR is not part of this app: the server leaves its notifications out of
  /// the list, the count and "read all", so they stay on the web.
  static const hiddenKindPrefix = 'HR_';

  Future<NotificationInbox> inbox({int page = 0, int size = 20}) async =>
      NotificationInbox.fromJson(
        requireMap(
          await _client.get(
            '/notifications?page=$page&size=$size'
            '&hiddenKindPrefix=$hiddenKindPrefix',
          ),
        ),
      );

  Future<void> read(String id) async {
    final response = await _client.postJson(
      '/notifications/$id/read',
      const {},
    );
    if (response.statusCode != 204) throw ApiError.fromResponse(response);
  }

  Future<void> readAll() async {
    final response = await _client.postJson(
      '/notifications/read-all?hiddenKindPrefix=$hiddenKindPrefix',
      const {},
    );
    if (response.statusCode != 204) throw ApiError.fromResponse(response);
  }

  Future<void> registerPush({
    required String firebaseInstallationId,
    required String platform,
  }) async {
    final response = await _client.postJson(
      '/notifications/push-registration',
      {'firebaseInstallationId': firebaseInstallationId, 'platform': platform},
    );
    if (response.statusCode != 204) throw ApiError.fromResponse(response);
  }

  Future<void> removePushRegistration() async {
    final response = await _client.delete('/notifications/push-registration');
    if (response.statusCode != 204) throw ApiError.fromResponse(response);
  }
}
