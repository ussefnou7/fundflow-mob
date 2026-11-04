import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../domain/treasury_models.dart';

class TreasuryRepository {
  const TreasuryRepository(this._client);
  final ApiClient _client;

  Future<List<TreasuryAccount>> list() async =>
      requireList(await _client.get('/treasuries'))
          .map(
            (item) => TreasuryAccount.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();

  Future<TreasuryMovementPage> movements({
    required String treasuryId,
    String status = '',
    int page = 0,
    int size = 20,
  }) async {
    final query = Uri(
      queryParameters: {
        'treasuryId': treasuryId,
        if (status.isNotEmpty) 'status': status,
        'page': '$page',
        'size': '$size',
      },
    ).query;
    return TreasuryMovementPage.fromJson(
      requireMap(await _client.get('/treasuries/movements?$query')),
    );
  }

  Future<DirectExpenseOptions> expenseOptions() async =>
      DirectExpenseOptions.fromJson(
        requireMap(await _client.get('/treasuries/expense-options')),
      );

  Future<TreasuryLedgerPage> ledger({
    required String treasuryId,
    String direction = '',
    int page = 0,
    int size = 20,
  }) async {
    final query = Uri(
      queryParameters: {
        if (direction.isNotEmpty) 'direction': direction,
        'page': '$page',
        'size': '$size',
      },
    ).query;
    return TreasuryLedgerPage.fromJson(
      requireMap(
        await _client.get('/financial-accounts/$treasuryId/ledger?$query'),
      ),
    );
  }

  Future<TreasuryLedgerSummary> ledgerSummary({
    required String treasuryId,
  }) async => TreasuryLedgerSummary.fromJson(
    requireMap(
      await _client.get('/financial-accounts/$treasuryId/ledger/summary'),
    ),
  );

  Future<IntercompanyLoanPage> loans({int page = 0, int size = 20}) async {
    final query = Uri(
      queryParameters: {'page': '$page', 'size': '$size'},
    ).query;
    return IntercompanyLoanPage.fromJson(
      requireMap(await _client.get('/intercompany/loans?$query')),
    );
  }

  Future<IntercompanyOptions> intercompanyOptions() async =>
      IntercompanyOptions.fromJson(
        requireMap(await _client.get('/intercompany/options')),
      );

  Future<IntercompanyTransferPage> contributions({
    int page = 0,
    int size = 20,
  }) async {
    final query = Uri(
      queryParameters: {
        'purpose': 'CONTRIBUTION',
        'page': '$page',
        'size': '$size',
      },
    ).query;
    return IntercompanyTransferPage.fromJson(
      requireMap(await _client.get('/intercompany/transfers?$query')),
    );
  }

  Future<void> createIntercompanyTransfer({
    required String mode,
    required String fromCompanyId,
    required String toCompanyId,
    required String? fromTreasuryId,
    required String toTreasuryId,
    required String? fromAmount,
    required String? toAmount,
    required String purpose,
    required String entryDate,
    required String description,
    String? loanId,
  }) async {
    requireMap(
      await _client.postJson('/intercompany/transfers', {
        'mode': mode,
        'fromCompanyId': fromCompanyId,
        'toCompanyId': toCompanyId,
        'fromTreasuryId': mode == 'EXECUTE' ? fromTreasuryId : null,
        'toTreasuryId': toTreasuryId,
        'fromAmount': mode == 'EXECUTE' ? fromAmount : null,
        'toAmount': toAmount,
        'purpose': purpose,
        'loanId': purpose == 'LOAN_REPAYMENT' ? loanId : null,
        'entryDate': entryDate,
        'description': description.trim().isEmpty ? null : description.trim(),
      }),
    );
  }

  Future<void> reverseIntercompanyTransfer({
    required String transferId,
    required String entryDate,
    required String reason,
  }) async {
    requireMap(
      await _client.postJson('/intercompany/transfers/$transferId/reverse', {
        'entryDate': entryDate,
        'reason': reason.trim(),
      }),
    );
  }

  Future<void> reverseOperation({
    required String operationId,
    required String entryDate,
    required String reason,
  }) async {
    requireMap(
      await _client.postJson('/treasuries/operations/$operationId/reverse', {
        'entryDate': entryDate,
        'reason': reason.trim(),
      }),
    );
  }

  Future<void> createMovement({
    required String treasuryId,
    required String type,
    required String amount,
    required String entryDate,
    required String description,
    String? method,
    String? recipientId,
    String? destinationTreasuryId,
    String? custodyRequestId,
    String? centerId,
    String? depositKind,
  }) async {
    requireMap(
      await _client.postJson('/treasuries/$treasuryId/movements', {
        'type': type,
        'amount': amount,
        'entryDate': entryDate,
        'description': description.trim().isEmpty ? null : description.trim(),
        'method': type == 'CORRECTION' ? null : method,
        'recipientId': type == 'CUSTODY_FUNDING' ? recipientId : null,
        'destinationTreasuryId': type == 'TREASURY_TRANSFER'
            ? destinationTreasuryId
            : null,
        'custodyRequestId': type == 'CUSTODY_FUNDING' ? custodyRequestId : null,
        'centerId': type == 'DEPOSIT' ? centerId : null,
        'depositKind': type == 'DEPOSIT' ? depositKind : null,
      }),
    );
  }

  Future<void> createDirectExpense({
    required String treasuryId,
    required String amount,
    required String entryDate,
    required String description,
    required String method,
    required String centerId,
    required String categoryId,
    required String costDirection,
    required String evidenceType,
    String? contractorId,
    List<String> invoicePaths = const [],
  }) async {
    requireMap(
      await _client.postMultipartFiles(
        '/treasuries/$treasuryId/direct-expenses',
        jsonPartName: 'movement',
        json: {
          'amount': amount,
          'entryDate': entryDate,
          'description': description.trim(),
          'method': method,
          'centerId': centerId,
          'categoryId': categoryId,
          'costDirection': costDirection,
          'evidenceType': evidenceType,
          'contractorId': evidenceType == 'CONTRACTOR' ? contractorId : null,
        },
        filePartName: 'invoices',
        filePaths: invoicePaths,
      ),
    );
  }

  Future<void> returnFromCustody({
    required String treasuryId,
    required String ownerId,
    required String amount,
    required String entryDate,
    required String description,
    required String method,
  }) async {
    requireMap(
      await _client.postJson('/treasuries/$treasuryId/returns', {
        'ownerId': ownerId,
        'amount': amount,
        'entryDate': entryDate,
        'description': description.trim(),
        'method': method,
      }),
    );
  }

  Future<void> review(
    TreasuryMovement movement,
    String decision, {
    String? reason,
  }) async {
    requireMap(
      await _client.postJson('/treasuries/movements/${movement.id}/review', {
        'decision': decision,
        'version': movement.version,
        'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
      }),
    );
  }
}
