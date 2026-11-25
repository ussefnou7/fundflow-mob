import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/workflow_models.dart';

class WorkflowRepository {
  const WorkflowRepository(this._client);

  final ApiClient _client;

  Future<WorkflowInbox> inbox({
    String stage = 'APPROVAL',
    bool all = false,
    int page = 0,
    int size = 20,
  }) async {
    final query = Uri(
      queryParameters: {
        'stage': stage,
        'all': '$all',
        'page': '$page',
        'size': '$size',
      },
    ).query;
    return WorkflowInbox.fromJson(
      requireMap(await _client.get('/workflow/inbox?$query')),
    );
  }

  Future<WorkflowInboxCount> count() async => WorkflowInboxCount.fromJson(
    requireMap(await _client.get('/workflow/inbox/count')),
  );

  Future<WorkflowState> state(
    String docType,
    String docId,
  ) async => WorkflowState.fromJson(
    requireMap(
      await _client.get(
        '/workflow/${Uri.encodeComponent(docType)}/${Uri.encodeComponent(docId)}',
      ),
    ),
  );

  Future<WorkflowState> act({
    required String docType,
    required String docId,
    required String action,
    String? comment,
  }) async => WorkflowState.fromJson(
    requireMap(
      await _client.postJson(
        '/workflow/${Uri.encodeComponent(docType)}/${Uri.encodeComponent(docId)}/actions',
        {
          'action': action,
          if (comment?.trim().isNotEmpty == true) 'comment': comment!.trim(),
        },
      ),
    ),
  );
}
