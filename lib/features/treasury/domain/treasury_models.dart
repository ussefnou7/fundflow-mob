import '../../custody/domain/custody_models.dart';

class TreasuryAccount {
  const TreasuryAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.currencyCode,
    required this.defaultTreasury,
    required this.active,
    required this.balance,
    required this.version,
  });

  factory TreasuryAccount.fromJson(Map<String, dynamic> json) =>
      TreasuryAccount(
        id: json['id'].toString(),
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        currencyCode: json['currencyCode']?.toString() ?? 'EGP',
        defaultTreasury: json['defaultTreasury'] == true,
        active: json['active'] == true,
        balance: json['balance']?.toString() ?? '0',
        version: (json['version'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String code;
  final String name;
  final String currencyCode;
  final bool defaultTreasury;
  final bool active;
  final String balance;
  final int version;
}

class TreasuryMovement {
  const TreasuryMovement({
    required this.id,
    required this.treasuryId,
    required this.treasuryName,
    required this.type,
    required this.status,
    required this.amount,
    required this.entryDate,
    required this.version,
    this.method,
    this.description,
    this.recipientName,
    this.destinationTreasuryName,
    this.creatorName,
    this.reviewerName,
    this.reviewReason,
    this.categoryName,
    this.centerName,
    this.contractorName,
    this.depositKind,
  });

  factory TreasuryMovement.fromJson(Map<String, dynamic> json) =>
      TreasuryMovement(
        id: json['id'].toString(),
        treasuryId: json['treasuryId'].toString(),
        treasuryName: json['treasuryName']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        status: json['status']?.toString() ?? 'PENDING',
        method: json['method']?.toString(),
        amount: json['amount']?.toString() ?? '0',
        entryDate: json['entryDate']?.toString() ?? '',
        description: json['description']?.toString(),
        recipientName:
            json['recipientName']?.toString() ??
            json['custodyOwnerName']?.toString(),
        destinationTreasuryName: json['destinationTreasuryName']?.toString(),
        creatorName: json['creatorName']?.toString(),
        reviewerName: json['reviewerName']?.toString(),
        reviewReason: json['reviewReason']?.toString(),
        categoryName: json['categoryName']?.toString(),
        centerName: json['centerName']?.toString(),
        contractorName: json['contractorName']?.toString(),
        depositKind: json['depositKind']?.toString(),
        version: (json['version'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String treasuryId;
  final String treasuryName;
  final String type;
  final String status;
  final String? method;
  final String amount;
  final String entryDate;
  final String? description;
  final String? recipientName;
  final String? destinationTreasuryName;
  final String? creatorName;
  final String? reviewerName;
  final String? reviewReason;
  final String? categoryName;
  final String? centerName;
  final String? contractorName;
  final String? depositKind;
  final int version;
}

class TreasuryMovementPage {
  const TreasuryMovementPage({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });
  factory TreasuryMovementPage.fromJson(Map<String, dynamic> json) =>
      TreasuryMovementPage(
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  TreasuryMovement.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 0,
        size: (json['size'] as num?)?.toInt() ?? 20,
      );
  final List<TreasuryMovement> items;
  final int total;
  final int page;
  final int size;
}

class DirectExpenseOptions {
  const DirectExpenseOptions({
    required this.centers,
    required this.categories,
    required this.contractors,
    required this.today,
  });
  factory DirectExpenseOptions.fromJson(Map<String, dynamic> json) {
    List<ExpenseReference> records(String key) =>
        (json[key] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  ExpenseReference.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false);
    return DirectExpenseOptions(
      centers: records('centers'),
      categories: records('categories'),
      contractors: records('contractors'),
      today: json['today']?.toString() ?? '',
    );
  }
  final List<ExpenseReference> centers;
  final List<ExpenseReference> categories;
  final List<ExpenseReference> contractors;
  final String today;
}

class TreasuryLedgerEntry {
  const TreasuryLedgerEntry({
    required this.operationId,
    required this.referenceNo,
    required this.type,
    required this.status,
    required this.direction,
    required this.amount,
    required this.currencyCode,
    required this.balanceAfter,
    required this.entryDate,
    required this.description,
    this.reversedOperationId,
  });

  factory TreasuryLedgerEntry.fromJson(Map<String, dynamic> json) =>
      TreasuryLedgerEntry(
        operationId: json['operationId']?.toString() ?? '',
        referenceNo: json['referenceNo']?.toString() ?? '—',
        type: json['type']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        direction: json['direction']?.toString() ?? '',
        amount: json['amount']?.toString() ?? '0',
        currencyCode: json['currencyCode']?.toString() ?? 'EGP',
        balanceAfter: json['balanceAfter']?.toString() ?? '0',
        entryDate: json['entryDate']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        reversedOperationId: json['reversedOperationId']?.toString(),
      );

  final String operationId;
  final String referenceNo;
  final String type;
  final String status;
  final String direction;
  final String amount;
  final String currencyCode;
  final String balanceAfter;
  final String entryDate;
  final String description;
  final String? reversedOperationId;
}

class TreasuryLedgerPage {
  const TreasuryLedgerPage({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });

  factory TreasuryLedgerPage.fromJson(Map<String, dynamic> json) =>
      TreasuryLedgerPage(
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  TreasuryLedgerEntry.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 0,
        size: (json['size'] as num?)?.toInt() ?? 20,
      );

  final List<TreasuryLedgerEntry> items;
  final int total;
  final int page;
  final int size;
}

class TreasuryLedgerSummary {
  const TreasuryLedgerSummary({
    required this.currencyCode,
    required this.openingBalance,
    required this.inflows,
    required this.outflows,
    required this.closingBalance,
  });

  factory TreasuryLedgerSummary.fromJson(Map<String, dynamic> json) =>
      TreasuryLedgerSummary(
        currencyCode: json['currencyCode']?.toString() ?? 'EGP',
        openingBalance: json['openingBalance']?.toString() ?? '0',
        inflows: json['inflows']?.toString() ?? '0',
        outflows: json['outflows']?.toString() ?? '0',
        closingBalance: json['closingBalance']?.toString() ?? '0',
      );

  final String currencyCode;
  final String openingBalance;
  final String inflows;
  final String outflows;
  final String closingBalance;
}

class IntercompanySide {
  const IntercompanySide({
    required this.companyId,
    required this.companyName,
    required this.treasuryId,
    required this.treasuryName,
    required this.amount,
    required this.currencyCode,
  });

  factory IntercompanySide.fromJson(Map<String, dynamic> json) =>
      IntercompanySide(
        companyId: json['companyId']?.toString() ?? '',
        companyName: json['companyName']?.toString() ?? '—',
        treasuryId: json['treasuryId']?.toString(),
        treasuryName: json['treasuryName']?.toString() ?? '—',
        amount: json['amount']?.toString() ?? '0',
        currencyCode: json['currencyCode']?.toString() ?? 'EGP',
      );

  final String companyId;
  final String companyName;
  final String? treasuryId;
  final String treasuryName;
  final String amount;
  final String currencyCode;
}

class IntercompanyTransfer {
  const IntercompanyTransfer({
    required this.id,
    required this.from,
    required this.to,
    required this.purpose,
    required this.status,
    required this.entryDate,
    required this.description,
    this.loanId,
    this.receivedOn,
    this.reversedTransferId,
    this.reversalTransferId,
    this.decisionReason,
  });

  factory IntercompanyTransfer.fromJson(Map<String, dynamic> json) =>
      IntercompanyTransfer(
        id: json['id']?.toString() ?? '',
        from: IntercompanySide.fromJson(
          Map<String, dynamic>.from(json['from'] as Map? ?? const {}),
        ),
        to: IntercompanySide.fromJson(
          Map<String, dynamic>.from(json['to'] as Map? ?? const {}),
        ),
        purpose: json['purpose']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        entryDate: json['entryDate']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        loanId: json['loanId']?.toString(),
        receivedOn: json['receivedOn']?.toString(),
        reversedTransferId: json['reversedTransferId']?.toString(),
        reversalTransferId: json['reversalTransferId']?.toString(),
        decisionReason: json['decisionReason']?.toString(),
      );

  final String id;
  final IntercompanySide from;
  final IntercompanySide to;
  final String purpose;
  final String status;
  final String entryDate;
  final String description;
  final String? loanId;
  final String? receivedOn;
  final String? reversedTransferId;
  final String? reversalTransferId;
  final String? decisionReason;
}

class IntercompanyTransferPage {
  const IntercompanyTransferPage({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });

  factory IntercompanyTransferPage.fromJson(Map<String, dynamic> json) =>
      IntercompanyTransferPage(
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => IntercompanyTransfer.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 0,
        size: (json['size'] as num?)?.toInt() ?? 20,
      );

  final List<IntercompanyTransfer> items;
  final int total;
  final int page;
  final int size;
}

class IntercompanyLoan {
  const IntercompanyLoan({
    required this.id,
    required this.lenderCompanyId,
    required this.lenderCompanyName,
    required this.borrowerCompanyId,
    required this.borrowerCompanyName,
    required this.currencyCode,
    required this.principalAmount,
    required this.principalOutstanding,
    required this.status,
    required this.purpose,
    required this.disbursedOn,
  });

  factory IntercompanyLoan.fromJson(Map<String, dynamic> json) =>
      IntercompanyLoan(
        id: json['id']?.toString() ?? '',
        lenderCompanyId: json['lenderCompanyId']?.toString() ?? '',
        lenderCompanyName: json['lenderCompanyName']?.toString() ?? '—',
        borrowerCompanyId: json['borrowerCompanyId']?.toString() ?? '',
        borrowerCompanyName: json['borrowerCompanyName']?.toString() ?? '—',
        currencyCode: json['principalCurrencyCode']?.toString() ?? 'EGP',
        principalAmount: json['principalAmount']?.toString() ?? '0',
        principalOutstanding: json['principalOutstanding']?.toString() ?? '0',
        status: json['status']?.toString() ?? '',
        purpose: json['purpose']?.toString() ?? '',
        disbursedOn: json['disbursedOn']?.toString() ?? '',
      );

  final String id;
  final String lenderCompanyId;
  final String lenderCompanyName;
  final String borrowerCompanyId;
  final String borrowerCompanyName;
  final String currencyCode;
  final String principalAmount;
  final String principalOutstanding;
  final String status;
  final String purpose;
  final String disbursedOn;
}

class IntercompanyLoanPage {
  const IntercompanyLoanPage({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });

  factory IntercompanyLoanPage.fromJson(Map<String, dynamic> json) =>
      IntercompanyLoanPage(
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  IntercompanyLoan.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
        total: (json['total'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 0,
        size: (json['size'] as num?)?.toInt() ?? 20,
      );

  final List<IntercompanyLoan> items;
  final int total;
  final int page;
  final int size;
}

class IntercompanyTreasuryOption {
  const IntercompanyTreasuryOption({
    required this.id,
    required this.code,
    required this.name,
    required this.currencyCode,
  });

  factory IntercompanyTreasuryOption.fromJson(Map<String, dynamic> json) =>
      IntercompanyTreasuryOption(
        id: json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        currencyCode: json['currencyCode']?.toString() ?? 'EGP',
      );

  final String id;
  final String code;
  final String name;
  final String currencyCode;
}

class IntercompanyCompanyOption {
  const IntercompanyCompanyOption({
    required this.id,
    required this.code,
    required this.name,
    required this.canApprove,
    required this.canRequest,
    required this.treasuries,
  });

  factory IntercompanyCompanyOption.fromJson(Map<String, dynamic> json) =>
      IntercompanyCompanyOption(
        id: json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        canApprove: json['canApprove'] == true,
        canRequest: json['canRequest'] == true,
        treasuries: (json['treasuries'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => IntercompanyTreasuryOption.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false),
      );

  final String id;
  final String code;
  final String name;
  final bool canApprove;
  final bool canRequest;
  final List<IntercompanyTreasuryOption> treasuries;
}

class IntercompanyOptions {
  const IntercompanyOptions({
    required this.activeCompanyId,
    required this.companies,
    required this.today,
  });

  factory IntercompanyOptions.fromJson(Map<String, dynamic> json) =>
      IntercompanyOptions(
        activeCompanyId: json['activeCompanyId']?.toString(),
        companies: (json['companies'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => IntercompanyCompanyOption.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false),
        today: json['today']?.toString() ?? '',
      );

  final String? activeCompanyId;
  final List<IntercompanyCompanyOption> companies;
  final String today;
}
