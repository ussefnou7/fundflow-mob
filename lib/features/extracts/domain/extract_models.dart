import '../../../core/format/exact_decimal.dart';
import '../../settings/domain/settings_models.dart';

class ExtractItem {
  const ExtractItem({
    required this.id,
    required this.kind,
    required this.lineNo,
    required this.description,
    required this.unitId,
    required this.unitName,
    required this.quantity,
    this.status = 'APPROVED',
    this.pendingPercentage,
    this.pendingMeasurementId,
    this.rate,
    this.clientRate,
    this.percentage,
    this.amount,
  });

  factory ExtractItem.fromJson(Map<String, dynamic> json) => ExtractItem(
    id: json['id'].toString(),
    kind: json['kind']?.toString() ?? 'WORK',
    lineNo: (json['lineNo'] as num?)?.toInt() ?? 0,
    description: json['description']?.toString() ?? '',
    unitId: json['unitId'].toString(),
    unitName: json['unitName']?.toString() ?? '',
    quantity: json['quantity']?.toString() ?? '0',
    status: json['status']?.toString() ?? 'APPROVED',
    pendingPercentage: json['pendingPercentage']?.toString(),
    pendingMeasurementId: json['pendingMeasurementId']?.toString(),
    rate: json['rate']?.toString(),
    clientRate: json['clientRate']?.toString(),
    percentage: json['percentage']?.toString(),
    amount: json['amount']?.toString(),
  );

  final String id;
  final String kind;
  final int lineNo;
  final String description;
  final String unitId;
  final String unitName;
  final String quantity;
  final String status;
  final String? pendingPercentage;
  final String? pendingMeasurementId;
  final String? rate;
  final String? clientRate;
  final String? percentage;
  final String? amount;
}

class ContractorExtract {
  const ContractorExtract({
    required this.id,
    required this.contractorId,
    required this.contractorName,
    required this.centerId,
    required this.centerName,
    required this.extractNo,
    required this.extractDate,
    required this.status,
    required this.version,
    required this.financialsVisible,
    required this.items,
    this.note,
    this.net,
    this.settled,
    this.outstanding,
    this.createdBy,
    this.approvedBy,
    this.rejectionReason,
    this.assignmentId,
  });

  factory ContractorExtract.fromJson(Map<String, dynamic> json) =>
      ContractorExtract(
        id: json['id'].toString(),
        contractorId: json['contractorId'].toString(),
        contractorName: json['contractorName']?.toString() ?? '',
        centerId: json['centerId'].toString(),
        centerName: json['centerName']?.toString() ?? '',
        extractNo: (json['extractNo'] as num?)?.toInt() ?? 0,
        extractDate: json['extractDate']?.toString() ?? '',
        status: json['status']?.toString() ?? 'PENDING',
        note: json['note']?.toString(),
        net: json['net']?.toString(),
        settled: json['settled']?.toString(),
        outstanding: json['outstanding']?.toString(),
        createdBy: json['createdBy']?.toString(),
        approvedBy: json['approvedBy']?.toString(),
        rejectionReason: json['rejectionReason']?.toString(),
        version: (json['version'] as num?)?.toInt() ?? 0,
        assignmentId: json['assignmentId']?.toString(),
        financialsVisible: json['financialsVisible'] == true,
        items: (json['items'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => ExtractItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
      );

  final String id;
  final String contractorId;
  final String contractorName;
  final String centerId;
  final String centerName;
  final int extractNo;
  final String extractDate;
  final String status;
  final String? note;
  final String? net;
  final String? settled;
  final String? outstanding;
  final String? createdBy;
  final String? approvedBy;
  final String? rejectionReason;
  final int version;
  final String? assignmentId;
  final bool financialsVisible;
  final List<ExtractItem> items;
}

class ExtractOptions {
  const ExtractOptions({
    required this.contractors,
    required this.centers,
    required this.units,
  });

  factory ExtractOptions.fromJson(Map<String, dynamic> json) => ExtractOptions(
    contractors: _records(json['contractors']),
    centers: _records(json['centers']),
    units: _records(json['units']),
  );

  final List<ReferenceRecord> contractors;
  final List<ReferenceRecord> centers;
  final List<ReferenceRecord> units;

  static List<ReferenceRecord> _records(dynamic value) =>
      (value as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) => ReferenceRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
}

class ExtractLineInput {
  const ExtractLineInput({
    required this.kind,
    required this.description,
    required this.unitId,
    required this.quantity,
    required this.rate,
    this.percentage,
    this.clientRate,
  });

  final String kind;
  final String description;
  final String unitId;
  final String quantity;
  final String rate;
  final String? percentage;
  final String? clientRate;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'description': description.trim(),
    'unitId': unitId,
    'quantity': ExactDecimal.parse(quantity).toString(),
    'rate': ExactDecimal.parse(rate).toString(),
    if (percentage != null)
      'percentage': ExactDecimal.parse(percentage!).toString(),
    if (clientRate != null)
      'clientRate': ExactDecimal.parse(clientRate!).toString(),
  };
}

class AddedExtractItemInput {
  const AddedExtractItemInput({
    required this.description,
    required this.unitId,
    required this.quantity,
    required this.rate,
  });

  final String description;
  final String unitId;
  final String quantity;
  final String rate;

  Map<String, dynamic> toJson() => {
    'description': description.trim(),
    'unitId': unitId,
    'quantity': ExactDecimal.parse(quantity).toString(),
    'rate': ExactDecimal.parse(rate).toString(),
  };
}
