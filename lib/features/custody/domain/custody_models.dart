String money(String value) {
  final negative = value.startsWith('-');
  final clean = negative ? value.substring(1) : value;
  final parts = clean.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final fraction = (parts.length > 1 ? parts[1] : '').padRight(2, '0');
  return '${negative ? '-' : ''}$whole.${fraction.substring(0, 2)}';
}

String shortDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class DashboardData {
  const DashboardData({
    required this.memberCount,
    required this.custodyOwnerCount,
    required this.totalFunding,
    required this.approvedAmount,
    required this.remaining,
    required this.unpaidRequestCount,
    required this.unpaidRequestAmount,
    required this.companyCash,
    required this.owners,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
    memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
    custodyOwnerCount: (json['custodyOwnerCount'] as num?)?.toInt() ?? 0,
    totalFunding: json['totalFunding']?.toString() ?? '0',
    approvedAmount: json['approvedAmount']?.toString() ?? '0',
    remaining: json['remaining']?.toString() ?? '0',
    unpaidRequestCount: (json['unpaidRequestCount'] as num?)?.toInt() ?? 0,
    unpaidRequestAmount: json['unpaidRequestAmount']?.toString() ?? '0',
    companyCash: (json['companyCash'] as List? ?? const [])
        .map(
          (item) =>
              CompanyCash.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    owners: (json['owners'] as List? ?? const [])
        .map(
          (item) =>
              CustodyOwner.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );

  final int memberCount;
  final int custodyOwnerCount;
  final String totalFunding;
  final String approvedAmount;
  final String remaining;
  final int unpaidRequestCount;
  final String unpaidRequestAmount;
  final List<CompanyCash> companyCash;
  final List<CustodyOwner> owners;
}

class CompanyCash {
  const CompanyCash(this.code, this.arabicCode, this.total);
  factory CompanyCash.fromJson(Map<String, dynamic> json) => CompanyCash(
    json['currencyCode']?.toString() ?? '',
    json['currencyCodeAr']?.toString() ?? '',
    json['total']?.toString() ?? '0',
  );
  final String code;
  final String arabicCode;
  final String total;
}

class CustodyOwner {
  const CustodyOwner({
    required this.id,
    required this.custodyId,
    required this.name,
    required this.code,
    required this.active,
    required this.lastSettledAt,
    required this.totalFunding,
    required this.approved,
    required this.remaining,
  });
  factory CustodyOwner.fromJson(Map<String, dynamic> json) => CustodyOwner(
    id: json['ownerId'].toString(),
    custodyId: json['custodyId']?.toString(),
    name: json['name']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    active: json['active'] == true,
    lastSettledAt: json['lastSettledAt']?.toString(),
    totalFunding: json['totalFunding']?.toString() ?? '0',
    approved: json['approved']?.toString() ?? '0',
    remaining: json['remaining']?.toString() ?? '0',
  );
  final String id;
  final String? custodyId;
  final String name;
  final String code;
  final bool active;
  final String? lastSettledAt;
  final String totalFunding;
  final String approved;
  final String remaining;
}

class CustodyBalance {
  const CustodyBalance({
    required this.remaining,
    required this.pendingIncoming,
    required this.pendingOutgoing,
  });
  factory CustodyBalance.fromJson(Map<String, dynamic> json) => CustodyBalance(
    remaining: json['remaining']?.toString() ?? '0',
    pendingIncoming: json['pendingIncoming']?.toString() ?? '0',
    pendingOutgoing: json['pendingOutgoing']?.toString() ?? '0',
  );
  final String remaining;
  final String pendingIncoming;
  final String pendingOutgoing;
}

class LedgerItem {
  const LedgerItem({
    required this.id,
    required this.ownerName,
    required this.entryDate,
    required this.amount,
    required this.description,
    required this.center,
    required this.category,
    required this.contractor,
    required this.approval,
    required this.settlement,
    required this.kind,
    this.ownerId,
    this.centerId,
    this.categoryId,
    this.status,
    this.note,
    this.costDirection,
    this.evidenceType,
    this.contractorId,
    this.isSnag = false,
    this.settled = false,
    this.approvedAt,
    this.rejectedAt,
    this.rejecterName,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.invoices = const [],
    this.version = 0,
    this.senderId,
    this.recipientId,
  });

  factory LedgerItem.fromExpense(Map<String, dynamic> json) => LedgerItem(
    id: json['id'].toString(),
    ownerName: json['ownerName']?.toString() ?? '—',
    entryDate: json['entryDate']?.toString() ?? '',
    amount: json['amount']?.toString() ?? '0',
    description: json['description']?.toString() ?? '—',
    center: json['centerName']?.toString() ?? '—',
    category: [
      json['categoryName'],
      json['subCategoryName'],
    ].whereType<String>().where((value) => value.isNotEmpty).join(' / '),
    contractor:
        json['contractorName']?.toString() ??
        (json['evidenceType'] == 'INVOICE' ? 'فاتورة' : '—'),
    approval: json['status'] == 'REJECTED'
        ? 'مرفوض'
        : json['approverName']?.toString() ?? 'اعتماد تلقائي',
    settlement: json['settled'] == true ? 'تمت التصفية' : 'غير مصفّى',
    kind: LedgerKind.expense,
    ownerId: json['ownerId']?.toString(),
    centerId: json['centerId']?.toString(),
    categoryId: json['categoryId']?.toString(),
    status: json['status']?.toString() ?? 'APPROVED',
    note: json['note']?.toString(),
    costDirection: json['costDirection']?.toString(),
    evidenceType: json['evidenceType']?.toString(),
    contractorId: json['contractorId']?.toString(),
    isSnag: json['isSnag'] == true,
    settled: json['settled'] == true,
    approvedAt: json['approvedAt']?.toString(),
    rejectedAt: json['rejectedAt']?.toString(),
    rejecterName: json['rejecterName']?.toString(),
    rejectionReason: json['rejectionReason']?.toString(),
    createdAt: json['createdAt']?.toString(),
    updatedAt: json['updatedAt']?.toString(),
    invoices: (json['invoices'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) => ExpenseInvoice.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(growable: false),
    version: (json['version'] as num?)?.toInt() ?? 0,
  );

  factory LedgerItem.fromLedgerRow(Map<String, dynamic> row) {
    if (row['expense'] is Map) {
      return LedgerItem.fromExpense(
        Map<String, dynamic>.from(row['expense'] as Map),
      );
    }
    if (row['funding'] is Map) {
      final json = Map<String, dynamic>.from(row['funding'] as Map);
      return LedgerItem(
        id: json['id'].toString(),
        ownerName: json['recipientName']?.toString() ?? '—',
        entryDate: json['entryDate']?.toString() ?? '',
        amount: '+${json['amount'] ?? '0'}',
        description: 'تمويل عهدة',
        center: '—',
        category: '—',
        contractor: '—',
        approval: '—',
        settlement: '—',
        kind: LedgerKind.funding,
      );
    }
    if (row['transfer'] is Map) {
      final json = Map<String, dynamic>.from(row['transfer'] as Map);
      return LedgerItem(
        id: json['id'].toString(),
        ownerName: '${json['senderName']} إلى ${json['recipientName']}',
        entryDate: json['entryDate']?.toString() ?? '',
        amount: json['amount']?.toString() ?? '0',
        description: json['description']?.toString() ?? 'تحويل عهدة',
        center: '—',
        category: 'تحويل عهدة',
        contractor: '—',
        approval: json['receivedAt'] == null
            ? 'بانتظار الاستلام'
            : 'تم الاستلام',
        settlement: '—',
        kind: LedgerKind.transfer,
        senderId: json['senderId']?.toString(),
        recipientId: json['recipientId']?.toString(),
      );
    }
    final json = Map<String, dynamic>.from(row['custodyReturn'] as Map);
    return LedgerItem(
      id: json['id'].toString(),
      ownerName: json['ownerName']?.toString() ?? '—',
      entryDate: json['entryDate']?.toString() ?? '',
      amount: '-${json['amount'] ?? '0'}',
      description: json['description']?.toString() ?? 'رد عهدة',
      center: '—',
      category: json['categoryName']?.toString() ?? '—',
      contractor: '—',
      approval: 'معتمد فوريًا',
      settlement: '—',
      kind: LedgerKind.custodyReturn,
    );
  }

  final String id;
  final String ownerName;
  final String entryDate;
  final String amount;
  final String description;
  final String center;
  final String category;
  final String contractor;
  final String approval;
  final String settlement;
  final LedgerKind kind;
  final String? ownerId;
  final String? centerId;
  final String? categoryId;
  final String? status;
  final String? note;
  final String? costDirection;
  final String? evidenceType;
  final String? contractorId;
  final bool isSnag;
  final bool settled;
  final String? approvedAt;
  final String? rejectedAt;
  final String? rejecterName;
  final String? rejectionReason;
  final String? createdAt;
  final String? updatedAt;
  final List<ExpenseInvoice> invoices;
  final int version;

  /// Transfers only: who sent and who received, to sign the row for the viewer.
  final String? senderId;
  final String? recipientId;

  bool get rejected => status == 'REJECTED';
}

class ExpenseInvoice {
  const ExpenseInvoice({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.byteSize,
  });

  factory ExpenseInvoice.fromJson(Map<String, dynamic> json) => ExpenseInvoice(
    id: json['id']?.toString() ?? '',
    fileName: json['fileName']?.toString() ?? 'فاتورة',
    contentType: json['contentType']?.toString() ?? 'image/jpeg',
    byteSize: (json['byteSize'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String fileName;
  final String contentType;
  final int byteSize;
}

enum LedgerKind { expense, funding, transfer, custodyReturn }

class PageData<T> {
  const PageData(this.items, this.total);
  final List<T> items;
  final int total;
}

class ExpenseReference {
  const ExpenseReference({
    required this.id,
    required this.name,
    required this.code,
    this.active = true,
    this.type,
    this.parentId,
  });

  factory ExpenseReference.fromJson(Map<String, dynamic> json) =>
      ExpenseReference(
        id: json['id'].toString(),
        name: json['name']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        active: json['active'] != false,
        type: json['type']?.toString(),
        parentId: json['parentId']?.toString(),
      );

  final String id;
  final String name;
  final String code;
  final bool active;
  final String? type;
  final String? parentId;

  String get label => code.isEmpty ? name : '$code · $name';
}

class CustodyPerson {
  const CustodyPerson({
    required this.id,
    required this.name,
    required this.code,
    required this.active,
    required this.custodyId,
  });

  factory CustodyPerson.fromJson(Map<String, dynamic> json) => CustodyPerson(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
    active: json['active'] == true,
    custodyId: json['custodyId']?.toString(),
  );

  final String id;
  final String name;
  final String code;
  final bool active;
  final String? custodyId;

  String get label => code.isEmpty ? name : '$code · $name';
}

class ExpenseOptions {
  const ExpenseOptions({
    required this.centers,
    required this.categories,
    required this.contractors,
    required this.people,
    required this.subCategories,
    required this.costDetailsEnabled,
    required this.today,
    required this.custodyId,
  });

  factory ExpenseOptions.fromJson(Map<String, dynamic> json) {
    List<ExpenseReference> references(String key) =>
        (json[key] as List? ?? const [])
            .map(
              (item) => ExpenseReference.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
    return ExpenseOptions(
      centers: references('centers'),
      categories: references('categories'),
      contractors: references('contractors'),
      people: (json['people'] as List? ?? const [])
          .map(
            (item) =>
                CustodyPerson.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      subCategories: references('subCategories'),
      costDetailsEnabled: json['costDetailsEnabled'] == true,
      today: json['today']?.toString() ?? '',
      custodyId: json['custodyId']?.toString(),
    );
  }

  final List<ExpenseReference> centers;
  final List<ExpenseReference> categories;
  final List<ExpenseReference> contractors;
  final List<CustodyPerson> people;
  final List<ExpenseReference> subCategories;
  final bool costDetailsEnabled;
  final String today;
  final String? custodyId;
}

class ExpenseFilterOption {
  const ExpenseFilterOption({
    required this.id,
    required this.name,
    required this.active,
  });

  factory ExpenseFilterOption.fromJson(Map<String, dynamic> json) =>
      ExpenseFilterOption(
        id: json['id'].toString(),
        name: json['name']?.toString() ?? '',
        active: json['active'] != false,
      );

  final String id;
  final String name;
  final bool active;

  String get label => active ? name : '$name (غير نشط)';
}

class ExpenseFilters {
  const ExpenseFilters({
    required this.people,
    required this.centers,
    required this.categories,
    required this.contractors,
    required this.today,
  });

  factory ExpenseFilters.fromJson(Map<String, dynamic> json) {
    List<ExpenseFilterOption> options(String key) =>
        (json[key] as List? ?? const [])
            .map(
              (item) => ExpenseFilterOption.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
    return ExpenseFilters(
      people: options('people'),
      centers: options('centers'),
      categories: options('categories'),
      contractors: options('contractors'),
      today: json['today']?.toString() ?? '',
    );
  }

  final List<ExpenseFilterOption> people;
  final List<ExpenseFilterOption> centers;
  final List<ExpenseFilterOption> categories;
  final List<ExpenseFilterOption> contractors;
  final String today;
}

class ExpenseFilterState {
  const ExpenseFilterState({
    this.ownerId,
    this.centerId,
    this.categoryId,
    this.status,
    this.contractorId,
    this.settled,
    this.isSnag,
    this.dateFrom,
    this.dateTo,
  });

  final String? ownerId;
  final String? centerId;
  final String? categoryId;
  final String? status;
  final String? contractorId;
  final bool? settled;
  final bool? isSnag;
  final String? dateFrom;
  final String? dateTo;

  bool get isActive =>
      ownerId != null ||
      centerId != null ||
      categoryId != null ||
      status != null ||
      contractorId != null ||
      settled != null ||
      isSnag != null ||
      dateFrom != null ||
      dateTo != null;
}

class NamedOption {
  const NamedOption({required this.id, required this.name, required this.code});
  factory NamedOption.fromJson(Map<String, dynamic> json) => NamedOption(
    id: json['id'].toString(),
    name: json['name']?.toString() ?? '',
    code: json['code']?.toString() ?? '',
  );
  final String id;
  final String name;
  final String code;
}

class CustodyRequestItem {
  const CustodyRequestItem({
    required this.id,
    this.requesterId = '',
    this.centerId = '',
    this.fundingStatus = 'NONE',
    required this.requesterName,
    required this.centerName,
    required this.amount,
    required this.description,
    required this.createdAt,
    required this.status,
    required this.reviewerName,
    required this.reviewedAt,
    required this.reviewReason,
  });
  factory CustodyRequestItem.fromJson(Map<String, dynamic> json) =>
      CustodyRequestItem(
        id: json['id'].toString(),
        requesterId: json['requesterId']?.toString() ?? '',
        centerId: json['centerId']?.toString() ?? '',
        fundingStatus: json['fundingStatus']?.toString() ?? 'NONE',
        requesterName: json['requesterName']?.toString() ?? '',
        centerName: json['centerName']?.toString() ?? '',
        amount: json['amount']?.toString() ?? '0',
        description: json['description']?.toString(),
        createdAt: json['createdAt']?.toString() ?? '',
        status: json['status']?.toString() ?? 'PENDING',
        reviewerName: json['reviewerName']?.toString(),
        reviewedAt: json['reviewedAt']?.toString(),
        reviewReason: json['reviewReason']?.toString(),
      );
  final String id;
  final String requesterName;
  final String centerName;
  final String amount;
  final String? description;
  final String createdAt;
  final String status;
  final String? reviewerName;
  final String? reviewedAt;
  final String? reviewReason;
  final String requesterId;
  final String centerId;

  /// NONE, PENDING (a treasury funding awaits review) or FUNDED.
  final String fundingStatus;

  bool get awaitingFunding => status == 'APPROVED' && fundingStatus == 'NONE';
}

class CustodyTransferItem {
  const CustodyTransferItem({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.recipientName,
    required this.amount,
    required this.description,
    required this.createdAt,
    required this.receivedAt,
  });
  factory CustodyTransferItem.fromJson(Map<String, dynamic> json) =>
      CustodyTransferItem(
        id: json['id'].toString(),
        senderId: json['senderId'].toString(),
        senderName: json['senderName']?.toString() ?? '',
        recipientId: json['recipientId'].toString(),
        recipientName: json['recipientName']?.toString() ?? '',
        amount: json['amount']?.toString() ?? '0',
        description: json['description']?.toString(),
        createdAt: json['createdAt']?.toString() ?? '',
        receivedAt: json['receivedAt']?.toString(),
      );
  final String id;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String recipientName;
  final String amount;
  final String? description;
  final String createdAt;
  final String? receivedAt;
}
