import '../../extracts/domain/extract_models.dart';
import 'settings_models.dart';

class CostCenterFinancialDetail {
  const CostCenterFinancialDetail({
    required this.center,
    required this.extracts,
  });

  factory CostCenterFinancialDetail.fromJson(Map<String, dynamic> json) =>
      CostCenterFinancialDetail(
        center: ReferenceRecord.fromJson(json),
        extracts: (json['extracts'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  ContractorExtract.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList(growable: false),
      );

  final ReferenceRecord center;
  final List<ContractorExtract> extracts;
}
