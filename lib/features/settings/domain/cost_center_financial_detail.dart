import '../../extracts/domain/extract_models.dart';
import 'settings_models.dart';

// The single cost centre screen (FundFlow docs/client-extracts.md §4.6). Every
// figure comes from the server; the phone adds nothing up.

String _s(Object? value, [String fallback = '0']) =>
    value?.toString() ?? fallback;

List<Map<String, dynamic>> _maps(Object? value) => (value as List? ?? const [])
    .whereType<Map>()
    .map((item) => Map<String, dynamic>.from(item))
    .toList(growable: false);

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

class CostCenterFinancialDetail {
  const CostCenterFinancialDetail({
    required this.center,
    required this.extracts,
    required this.contractors,
    required this.snag,
    required this.administrative,
    required this.actual,
    this.clientOwed,
    this.client,
    this.contract,
    this.profits,
  });

  factory CostCenterFinancialDetail.fromJson(Map<String, dynamic> json) {
    final contractors = _map(json['contractors']) ?? const {};
    final snag = _map(json['snag']) ?? const {};
    final administrative = _map(json['administrative']) ?? const {};
    final actual = _map(json['actual']) ?? const {};
    final client = _map(json['client']);
    final contract = _map(json['contract']);
    final profits = _map(json['profits']);
    return CostCenterFinancialDetail(
      center: ReferenceRecord.fromJson(json),
      extracts: _maps(
        json['extracts'],
      ).map(ContractorExtract.fromJson).toList(growable: false),
      clientOwed: json['clientOwed']?.toString(),
      client: client == null ? null : ClientAccount.fromJson(client),
      contract: contract == null
          ? null
          : ClientContractSummary.fromJson(contract),
      profits: profits == null
          ? null
          : (
              fees: _s(profits['fees']),
              priceDifference: _s(profits['priceDifference']),
              savings: _s(profits['savings']),
              total: _s(profits['total']),
            ),
      contractors: (
        due: _s(contractors['due']),
        paid: _s(contractors['paid']),
        debt: _s(contractors['debt']),
        items: _maps(
          contractors['items'],
        ).map(CenterContractorLine.fromJson).toList(growable: false),
      ),
      snag: (
        total: _s(snag['total']),
        items: _maps(
          snag['items'],
        ).map(CenterSpendingLine.fromJson).toList(growable: false),
        unmarked: _maps(
          snag['unmarked'],
        ).map(CenterSpendingLine.fromJson).toList(growable: false),
      ),
      administrative: (
        total: _s(administrative['total']),
        items: _maps(
          administrative['items'],
        ).map(CenterSpendingLine.fromJson).toList(growable: false),
      ),
      actual: (
        deposits: _s(actual['deposits']),
        spent: _s(actual['spent']),
        difference: _s(actual['difference']),
      ),
    );
  }

  final ReferenceRecord center;
  final List<ContractorExtract> extracts;

  /// Null without CONTRACTOR_EXTRACT_CLIENT_PRICE, like [client] and [profits].
  final String? clientOwed;
  final ClientAccount? client;
  final ClientContractSummary? contract;
  final ({String fees, String priceDifference, String savings, String total})?
  profits;
  final ({
    String due,
    String paid,
    String debt,
    List<CenterContractorLine> items,
  })
  contractors;
  final ({
    String total,
    List<CenterSpendingLine> items,
    List<CenterSpendingLine> unmarked,
  })
  snag;
  final ({String total, List<CenterSpendingLine> items}) administrative;

  /// [difference] is deposits − spent: cash, not profit.
  final ({String deposits, String spent, String difference}) actual;
}

class ClientAccount {
  const ClientAccount({
    required this.charged,
    required this.credited,
    required this.balance,
    required this.months,
    required this.movements,
  });

  factory ClientAccount.fromJson(Map<String, dynamic> json) => ClientAccount(
    charged: _s(json['charged']),
    credited: _s(json['credited']),
    balance: _s(json['balance']),
    months: [
      for (final month in _maps(json['months']))
        (
          month: _s(month['month'], ''),
          charged: _s(month['charged']),
          covered: _s(month['covered']),
          remaining: _s(month['remaining']),
        ),
    ],
    movements: _maps(
      json['movements'],
    ).map(ClientMovement.fromJson).toList(growable: false),
  );

  final String charged, credited, balance;
  final List<({String month, String charged, String covered, String remaining})>
  months;
  final List<ClientMovement> movements;
}

class ClientMovement {
  const ClientMovement({
    required this.date,
    required this.kind,
    required this.charge,
    required this.credit,
    required this.balance,
    this.reference,
    this.description,
    this.party,
  });

  factory ClientMovement.fromJson(Map<String, dynamic> json) => ClientMovement(
    date: _s(json['date'], ''),
    kind: _s(json['kind'], ''),
    reference: json['reference']?.toString(),
    description: json['description']?.toString(),
    party: json['party']?.toString(),
    charge: _s(json['charge']),
    credit: _s(json['credit']),
    balance: _s(json['balance']),
  );

  final String date, kind, charge, credit, balance;
  final String? reference, description, party;

  /// Ledger numbers stay internal: an extract shows its number, a client
  /// payment its own reference, deposits and expenses nothing.
  String? get shownReference {
    if (reference == null || kind == 'DEPOSIT' || kind.endsWith('_EXPENSE')) {
      return null;
    }
    return kind == 'CONTRACTOR_EXTRACT' ? '#$reference' : reference;
  }
}

class CenterContractorLine {
  const CenterContractorLine({
    required this.contractorId,
    required this.contractorName,
    required this.due,
    required this.paidByCompany,
    required this.paidByClient,
    required this.debt,
  });

  factory CenterContractorLine.fromJson(Map<String, dynamic> json) =>
      CenterContractorLine(
        contractorId: _s(json['contractorId'], ''),
        contractorName: _s(json['contractorName'], '—'),
        due: _s(json['due']),
        paidByCompany: _s(json['paidByCompany']),
        paidByClient: _s(json['paidByClient']),
        debt: _s(json['debt']),
      );

  final String contractorId,
      contractorName,
      due,
      paidByCompany,
      paidByClient,
      debt;
}

/// A snag or administrative spending line.
class CenterSpendingLine {
  const CenterSpendingLine({
    required this.operationId,
    required this.type,
    required this.date,
    required this.amount,
    this.description,
    this.categoryName,
  });

  factory CenterSpendingLine.fromJson(Map<String, dynamic> json) =>
      CenterSpendingLine(
        operationId: _s(json['operationId'], ''),
        type: _s(json['type'], ''),
        date: _s(json['date'], ''),
        description: json['description']?.toString(),
        categoryName: json['categoryName']?.toString(),
        amount: _s(json['amount']),
      );

  final String operationId, type, date, amount;
  final String? description, categoryName;
}

class ClientContractSummary {
  const ClientContractSummary({
    required this.id,
    required this.status,
    required this.totalValue,
    required this.remaining,
  });

  factory ClientContractSummary.fromJson(Map<String, dynamic> json) =>
      ClientContractSummary(
        id: _s(json['id'], ''),
        status: _s(json['status'], ''),
        totalValue: _s(json['totalValue']),
        remaining: _s(json['remaining']),
      );

  final String id, status, totalValue, remaining;
}

/// The client contract, read-only on the phone; it is edited on the web.
class ClientContract {
  const ClientContract({
    required this.contractNo,
    required this.contractDate,
    required this.contractValue,
    required this.additionsTotal,
    required this.totalValue,
    required this.fromDate,
    required this.toDate,
    required this.durationDays,
    required this.status,
    required this.addenda,
    required this.attachmentCount,
    this.advanceAmount,
    this.advancePercent,
    this.terms,
  });

  factory ClientContract.fromJson(Map<String, dynamic> json) => ClientContract(
    contractNo: _s(json['contractNo'], '—'),
    contractDate: _s(json['contractDate'], ''),
    contractValue: _s(json['contractValue']),
    additionsTotal: _s(json['additionsTotal']),
    totalValue: _s(json['totalValue']),
    advanceAmount: json['advanceAmount']?.toString(),
    advancePercent: json['advancePercent']?.toString(),
    fromDate: _s(json['fromDate'], ''),
    toDate: _s(json['toDate'], ''),
    durationDays: (json['durationDays'] as num?)?.toInt() ?? 0,
    terms: json['terms']?.toString(),
    status: _s(json['status'], ''),
    addenda: [
      for (final item in _maps(json['addenda']))
        (
          description: _s(item['description'], '—'),
          amount: _s(item['amount']),
          creatorName: _s(item['creatorName'], '—'),
          createdAt: _s(item['createdAt'], ''),
        ),
    ],
    attachmentCount: (json['attachments'] as List? ?? const []).length,
  );

  final String contractNo,
      contractDate,
      contractValue,
      additionsTotal,
      totalValue,
      fromDate,
      toDate,
      status;
  final String? advanceAmount, advancePercent, terms;
  final int durationDays, attachmentCount;
  final List<
    ({String description, String amount, String creatorName, String createdAt})
  >
  addenda;
}

const clientMovementKindLabels = <String, String>{
  'CONTRACTOR_EXTRACT': 'مستخلص مقاول',
  'CUSTODY_EXPENSE': 'صرف من عهدة',
  'TREASURY_EXPENSE': 'صرف من الخزنة',
  'DEPOSIT': 'إيداع',
  'CLIENT_PAYMENT': 'دفعة من العميل للمقاول',
};

const centerSpendingSourceLabels = <String, String>{
  'CUSTODY_EXPENSE': 'عهدة',
  'DIRECT_EXPENSE': 'خزنة',
};

const clientContractStatusLabels = <String, String>{
  'DRAFT': 'مسودة',
  'ACTIVE': 'ساري',
  'ENDED': 'منتهٍ',
};
