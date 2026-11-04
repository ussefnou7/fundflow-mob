import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

enum SettingsSection {
  expenseCategories(
    slug: 'expense-categories',
    title: 'بنود الصرف',
    singular: 'بند صرف',
    icon: LucideIcons.tags,
  ),
  units(
    slug: 'units',
    title: 'وحدات القياس',
    singular: 'وحدة قياس',
    icon: LucideIcons.ruler,
  ),
  contractors(
    slug: 'contractors',
    title: 'المقاولون',
    singular: 'مقاول',
    icon: LucideIcons.hardHat,
  ),
  costCenters(
    slug: 'cost-centers',
    title: 'مراكز التكلفة',
    singular: 'مركز تكلفة',
    icon: LucideIcons.folderKanban,
  );

  const SettingsSection({
    required this.slug,
    required this.title,
    required this.singular,
    required this.icon,
  });

  final String slug;
  final String title;
  final String singular;
  final IconData icon;
}

class ReferenceRecord {
  const ReferenceRecord({
    required this.id,
    required this.code,
    required this.name,
    required this.active,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.type,
    this.parentId,
    this.inputMode,
    this.incoming,
    this.outgoing,
    this.debt,
    this.extractCount,
  });

  factory ReferenceRecord.fromJson(Map<String, dynamic> json) {
    return ReferenceRecord(
      id: json['id'].toString(),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      active: json['active'] == true,
      version: (json['version'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
      type: json['type']?.toString(),
      parentId: json['parentId']?.toString(),
      inputMode: json['inputMode']?.toString(),
      incoming: json['incoming']?.toString(),
      outgoing: json['outgoing']?.toString(),
      debt: json['debt']?.toString(),
      extractCount: (json['extractCount'] as num?)?.toInt(),
    );
  }

  final String id;
  final String code;
  final String name;
  final bool active;
  final int version;
  final String createdAt;
  final String updatedAt;
  final String? type;
  final String? parentId;
  final String? inputMode;
  final String? incoming;
  final String? outgoing;
  final String? debt;
  final int? extractCount;
}

class ReferencePage {
  const ReferencePage({
    required this.items,
    required this.total,
    required this.page,
    required this.size,
  });

  factory ReferencePage.fromJson(Map<String, dynamic> json) => ReferencePage(
    items: (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => ReferenceRecord.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false),
    total: (json['total'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 0,
    size: (json['size'] as num?)?.toInt() ?? 10,
  );

  final List<ReferenceRecord> items;
  final int total;
  final int page;
  final int size;
}

class ContractorFinancial {
  const ContractorFinancial({
    required this.due,
    required this.settled,
    required this.debt,
    required this.projectCount,
  });

  factory ContractorFinancial.fromJson(Map<String, dynamic> json) =>
      ContractorFinancial(
        due: json['due']?.toString() ?? '0',
        settled: json['settled']?.toString() ?? '0',
        debt: json['debt']?.toString() ?? '0',
        projectCount: (json['projectCount'] as num?)?.toInt() ?? 0,
      );

  final String due;
  final String settled;
  final String debt;
  final int projectCount;
}
