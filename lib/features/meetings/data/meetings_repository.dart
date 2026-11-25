import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/meeting_models.dart';

class MeetingsRepository {
  const MeetingsRepository(this._client);
  final ApiClient _client;
  Future<List<Meeting>> mine({String? from, String? to}) async {
    final query = Uri(queryParameters: {'from': ?from, 'to': ?to}).query;
    return _list('/meetings/mine${query.isEmpty ? '' : '?$query'}');
  }

  Future<List<Meeting>> forOwner(String ownerType, String ownerId) => _list(
    '/meetings?ownerType=${Uri.encodeQueryComponent(ownerType)}&ownerId=${Uri.encodeQueryComponent(ownerId)}',
  );
  Future<List<Meeting>> _list(String path) async =>
      requireList(await _client.get(path))
          .whereType<Map>()
          .map((e) => Meeting.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);

  Future<Meeting> createForLead({
    required String leadId,
    required String leadName,
    required String leadMobile,
    required String title,
    required String meetingType,
    required String startAt,
    String? location,
    String? link,
  }) async => Meeting.fromJson(
    requireMap(
      await _client.postJson('/meetings', {
        'ownerType': 'CRM_LEAD',
        'ownerId': leadId,
        'title': title.trim(),
        'meetingType': meetingType,
        'startAt': startAt,
        'endAt': null,
        'location': location?.trim().isEmpty == true ? null : location?.trim(),
        'link': link?.trim().isEmpty == true ? null : link?.trim(),
        'notes': null,
        'remindBeforeMinutes': 60,
        'attendees': [
          {'name': leadName, 'phone': leadMobile},
        ],
      }),
    ),
  );
}
