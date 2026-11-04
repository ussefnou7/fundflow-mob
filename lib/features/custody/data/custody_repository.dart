import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/custody_models.dart';

class CustodyRepository {
  const CustodyRepository(this._client);
  final ApiClient _client;

  Future<DashboardData> dashboard() async => DashboardData.fromJson(
    requireMap(await _client.get('/custody/dashboard')),
  );

  Future<CustodyBalance> balance([String? ownerId]) async {
    final suffix = ownerId == null ? '' : '?ownerId=$ownerId';
    return CustodyBalance.fromJson(
      requireMap(await _client.get('/custody/balance$suffix')),
    );
  }

  Future<PageData<LedgerItem>> ledger({
    String? ownerId,
    bool aggregate = false,
    int page = 0,
    int size = 20,
    ExpenseFilterState filters = const ExpenseFilterState(),
  }) async {
    final query = <String, String>{'page': '$page', 'size': '$size'};
    final selectedOwner = aggregate ? filters.ownerId : ownerId;
    if (selectedOwner != null) query['ownerId'] = selectedOwner;
    if (filters.centerId != null) query['centerId'] = filters.centerId!;
    if (filters.categoryId != null) query['categoryId'] = filters.categoryId!;
    if (filters.status != null) query['status'] = filters.status!;
    if (filters.dateFrom != null) query['dateFrom'] = filters.dateFrom!;
    if (filters.dateTo != null) query['dateTo'] = filters.dateTo!;
    if (aggregate && filters.contractorId != null) {
      query['contractorId'] = filters.contractorId!;
    }
    if (aggregate && filters.settled != null) {
      query['settled'] = '${filters.settled}';
    }
    if (aggregate && filters.isSnag != null) {
      query['isSnag'] = '${filters.isSnag}';
    }
    final path = aggregate ? '/custody/expenses/master' : '/custody/ledger';
    final json = requireMap(
      await _client.get('$path?${Uri(queryParameters: query).query}'),
    );
    final items = (json['items'] as List? ?? const []).map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return aggregate
          ? LedgerItem.fromExpense(map)
          : LedgerItem.fromLedgerRow(map);
    }).toList();
    return PageData(items, (json['total'] as num?)?.toInt() ?? items.length);
  }

  Future<ExpenseFilters> expenseFilters({String? ownerId}) async {
    final suffix = ownerId == null
        ? ''
        : '?${Uri(queryParameters: {'ownerId': ownerId}).query}';
    return ExpenseFilters.fromJson(
      requireMap(await _client.get('/custody/expenses/filters$suffix')),
    );
  }

  Future<ExpenseOptions> expenseOptions({String? ownerId}) async {
    final suffix = ownerId == null
        ? ''
        : '?${Uri(queryParameters: {'ownerId': ownerId}).query}';
    return ExpenseOptions.fromJson(
      requireMap(await _client.get('/custody/options$suffix')),
    );
  }

  Future<LedgerItem> expense(String id) async => LedgerItem.fromExpense(
    requireMap(await _client.get('/custody/expenses/$id')),
  );

  Future<Uint8List> invoiceBytes(String id) async {
    final response = await _client.getBytes('/custody/invoices/$id');
    if (response.statusCode != 200 || response.data == null) {
      throw ApiError.fromResponse(response);
    }
    return Uint8List.fromList(response.data!);
  }

  Future<LedgerItem> editExpense({
    required LedgerItem expense,
    required String categoryId,
    required String description,
  }) async => LedgerItem.fromExpense(
    requireMap(
      await _client.putJson('/custody/expenses/${expense.id}', {
        'centerId': expense.centerId,
        'categoryId': categoryId,
        'description': description.trim(),
        'costDirection': expense.costDirection,
        'version': expense.version,
      }),
    ),
  );

  Future<LedgerItem> rejectExpense({
    required LedgerItem expense,
    String reason = '',
  }) async => LedgerItem.fromExpense(
    requireMap(
      await _client.postJson('/custody/expenses/${expense.id}/review', {
        'decision': 'REJECTED',
        'reason': reason.trim(),
        'version': expense.version,
      }),
    ),
  );

  Future<LedgerItem> correctExpense({
    required LedgerItem expense,
    required String amount,
    required String entryDate,
    required String reason,
  }) async => LedgerItem.fromExpense(
    requireMap(
      await _client.postJson('/custody/expenses/${expense.id}/correction', {
        'amount': amount,
        'entryDate': entryDate,
        'reason': reason.trim(),
        'version': expense.version,
      }),
    ),
  );

  Future<LedgerItem> setExpenseSnag({
    required LedgerItem expense,
    required bool isSnag,
  }) async => LedgerItem.fromExpense(
    requireMap(
      await _client.postJson('/custody/expenses/${expense.id}/snag', {
        'isSnag': isSnag,
        'version': expense.version,
      }),
    ),
  );

  Future<void> createExpense({
    required String centerId,
    required String categoryId,
    required String amount,
    required String entryDate,
    required String description,
    required String evidenceType,
    String? note,
    String? centerType,
    String? contractorId,
    String? subCategoryId,
    String? ownerId,
    List<String> invoicePaths = const [],
  }) async {
    final response = await _client.postMultipartFiles(
      '/custody/expenses',
      jsonPartName: 'expense',
      json: {
        'centerId': centerId,
        'categoryId': categoryId,
        'amount': amount,
        'entryDate': entryDate,
        'description': description.trim(),
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
        'centerType': centerType,
        'evidenceType': evidenceType,
        'contractorId': evidenceType == 'CONTRACTOR' ? contractorId : null,
        'subCategoryId': subCategoryId,
        'ownerId': ownerId,
      },
      filePartName: 'invoices',
      filePaths: invoicePaths,
    );
    requireMap(response);
  }

  Future<List<NamedOption>> requestSites() async =>
      requireList(await _client.get('/custody/requests/sites'))
          .map(
            (item) =>
                NamedOption.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();

  Future<PageData<CustodyRequestItem>> requests({
    int page = 0,
    int size = 20,
    bool unpaid = false,
    bool mine = false,
  }) async {
    final json = requireMap(
      await _client.get(
        '/custody/requests?page=$page&size=$size&unpaid=$unpaid&mine=$mine',
      ),
    );
    final items = (json['items'] as List? ?? const [])
        .map(
          (item) => CustodyRequestItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    return PageData(items, (json['total'] as num?)?.toInt() ?? items.length);
  }

  Future<void> createRequest({
    required String centerId,
    required String amount,
    required String description,
  }) async {
    final response = await _client.postJson('/custody/requests', {
      'centerId': centerId,
      'amount': amount,
      'description': description.trim().isEmpty ? null : description.trim(),
    });
    requireMap(response);
  }

  Future<void> reviewRequest({
    required String id,
    required String decision,
    String? reason,
  }) async {
    final response = await _client.postJson('/custody/requests/$id/review', {
      'decision': decision,
      'reason': reason,
    });
    requireMap(response);
  }

  Future<List<NamedOption>> transferRecipients() async =>
      requireList(await _client.get('/custody/transfers/recipients'))
          .map(
            (item) =>
                NamedOption.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();

  Future<PageData<CustodyTransferItem>> transfers({
    int page = 0,
    int size = 20,
    bool pendingOnly = false,
  }) async {
    final json = requireMap(
      await _client.get(
        '/custody/transfers?page=$page&size=$size&pendingOnly=$pendingOnly',
      ),
    );
    final items = (json['items'] as List? ?? const [])
        .map(
          (item) => CustodyTransferItem.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
    return PageData(items, (json['total'] as num?)?.toInt() ?? items.length);
  }

  Future<void> createTransfer({
    required String recipientId,
    required String amount,
    required String description,
    required String imagePath,
  }) async {
    final response = await _client.postMultipart(
      '/custody/transfers',
      jsonPartName: 'transfer',
      json: {
        'recipientId': recipientId,
        'amount': amount,
        'description': description.trim().isEmpty ? null : description.trim(),
      },
      filePartName: 'image',
      filePath: imagePath,
    );
    requireMap(response);
  }

  Future<void> receiveTransfer(String id) async {
    requireMap(
      await _client.postJson('/custody/transfers/$id/receive', const {}),
    );
  }
}
