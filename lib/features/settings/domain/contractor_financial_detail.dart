import '../../extracts/domain/extract_models.dart';
import 'settings_models.dart';

class ContractorFinancialDetail {
  const ContractorFinancialDetail({
    required this.contractor,
    required this.due,
    required this.settled,
    required this.debt,
    required this.projectCount,
    required this.extracts,
  });

  factory ContractorFinancialDetail.fromJson(Map<String, dynamic> json) =>
      ContractorFinancialDetail(
        contractor: ReferenceRecord.fromJson(json),
        due: json['due']?.toString() ?? '0',
        settled: json['settled']?.toString() ?? '0',
        debt: json['debt']?.toString() ?? '0',
        projectCount: (json['projectCount'] as num?)?.toInt() ?? 0,
        extracts: (json['extracts'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  ContractorExtract.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
      );

  final ReferenceRecord contractor;
  final String due;
  final String settled;
  final String debt;
  final int projectCount;
  final List<ContractorExtract> extracts;
}
