import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/app_buttons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_filter.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/settings_repository.dart';
import '../domain/settings_models.dart';
import 'contractor_detail_screen.dart';
import 'cost_center_detail_screen.dart';

class ReferenceSettingsScreen extends StatefulWidget {
  const ReferenceSettingsScreen({
    super.key,
    required this.repository,
    required this.section,
    required this.canManage,
    this.canOpenCenter = false,
    this.canViewContract = false,
  });

  final SettingsRepository repository;
  final SettingsSection section;
  final bool canManage;

  /// CONTRACTOR_EXTRACT_APPROVE: the centre file, as on the web.
  final bool canOpenCenter;

  /// CLIENT_CONTRACT_VIEW: the centre file's contract tab.
  final bool canViewContract;

  @override
  State<ReferenceSettingsScreen> createState() =>
      _ReferenceSettingsScreenState();
}

/// Section-specific filters, as one value so the shared filter sheet can
/// edit a draft of them.
typedef _Filters = ({String status, String level, String type, int size});

class _ReferenceSettingsScreenState extends State<ReferenceSettingsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  int _loadGeneration = 0;
  ReferencePage? _data;
  bool _loading = true;
  String? _error;
  int _page = 0;
  String _query = '';
  _Filters _filters = _empty(10);
  String? _openedCenterId;
  String? _openedContractorId;

  static _Filters _empty(int size) =>
      (status: '', level: '', type: '', size: size);

  bool get _isCenters => widget.section == SettingsSection.costCenters;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReferenceSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _openedCenterId = null;
      _openedContractorId = null;
      _resetFilters(load: false);
      _load();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository.findAll(
        section: widget.section,
        query: _query,
        active: switch (_filters.status) {
          'true' => true,
          'false' => false,
          _ => null,
        },
        type: _filters.type,
        subCategoriesOnly: _filters.level == 'sub',
        page: _page,
        size: _filters.size,
      );
      if (!mounted || generation != _loadGeneration) return;
      if (_page > 0 && result.total > 0 && result.items.isEmpty) {
        _page = ((result.total - 1) / _filters.size).floor();
        await _load();
        return;
      }
      setState(() => _data = result);
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  void _search(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _page = 0;
      _query = value;
      _load();
    });
  }

  void _resetFilters({bool load = true}) {
    _searchController.clear();
    setState(() {
      _query = '';
      _filters = _empty(_filters.size);
      _page = 0;
    });
    if (load) _load();
  }

  bool _active(_Filters f) =>
      f.status.isNotEmpty || f.level.isNotEmpty || f.type.isNotEmpty;

  String get _summary {
    final f = _filters;
    return [
      if (f.status.isNotEmpty) _statusOptions[f.status],
      if (f.level.isNotEmpty) _levelOptions[f.level],
      if (f.type.isNotEmpty) _typeOptions[f.type],
    ].whereType<String>().join(' · ');
  }

  Future<void> _openFilters() async {
    final result = await showAppFilterSheet<_Filters>(
      context: context,
      subtitle: widget.section.title,
      initial: _filters,
      empty: _empty(_filters.size),
      isActive: _active,
      fields: (context, f, update) => AppFilterGrid(
        children: [
          _choice('الحالة', f.status, _statusOptions, (value) {
            update((status: value, level: f.level, type: f.type, size: f.size));
          }),
          if (widget.section == SettingsSection.expenseCategories)
            _choice('المستوى', f.level, _levelOptions, (value) {
              update((
                status: f.status,
                level: value,
                type: f.type,
                size: f.size,
              ));
            }),
          if (_isCenters)
            _choice('النوع', f.type, _typeOptions, (value) {
              update((
                status: f.status,
                level: f.level,
                type: value,
                size: f.size,
              ));
            }),
          appPageSizeField(
            value: f.size,
            onChanged: (size) => update((
              status: f.status,
              level: f.level,
              type: f.type,
              size: size,
            )),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _filters = result;
      _page = 0;
    });
    await _load();
  }

  Future<bool> _edit([ReferenceRecord? record]) async {
    final saved = await showAppSheet<bool>(
      context,
      builder: (context) => _ReferenceFormSheet(
        repository: widget.repository,
        section: widget.section,
        record: record,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ التغييرات بنجاح')));
      await _load();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_openedContractorId != null &&
        widget.section == SettingsSection.contractors) {
      return ContractorDetailScreen(
        repository: widget.repository,
        contractorId: _openedContractorId!,
        onBack: () => setState(() => _openedContractorId = null),
      );
    }
    if (_openedCenterId != null && _isCenters) {
      return CostCenterDetailScreen(
        repository: widget.repository,
        centerId: _openedCenterId!,
        canViewContract: widget.canViewContract,
        onBack: () {
          setState(() => _openedCenterId = null);
          _load();
        },
        onEdit: widget.canManage
            ? () async {
                final record = _data?.items.firstWhere(
                  (item) => item.id == _openedCenterId,
                );
                if (record == null) return false;
                return _edit(record);
              }
            : null,
      );
    }
    final tokens = context.tokens;
    final data = _data;
    final filtered = _query.isNotEmpty || _active(_filters);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.md,
          AppSpace.md,
          40,
        ),
        children: [
          PageHeader(
            title: widget.section.title,
            subtitle: _isCenters
                ? 'المشروعات والمراكز الإدارية. الأرقام المالية في ملف كل مركز.'
                : data == null
                ? null
                : '${data.total} سجل',
            action: widget.canManage
                ? AppAddButton(
                    label: _isCenters ? 'مركز جديد' : 'إضافة',
                    onPressed: () => _edit(),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            textAlign: TextAlign.right,
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو الكود…',
              fillColor: Colors.white,
              prefixIcon: const Icon(LucideIcons.search, size: 19),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: tokens.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: tokens.brand, width: 1.4),
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _searchController.clear();
                        _search('');
                      },
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          AppFilterBar(
            activeCount: _active(_filters) ? 1 : 0,
            summary: _summary,
            onOpen: _openFilters,
            onClear: () {
              setState(() {
                _filters = _empty(_filters.size);
                _page = 0;
              });
              _load();
            },
          ),
          if (_loading && data != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: 12),
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _load)
          else if (_loading && data == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (data == null || data.items.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tokens.line),
              ),
              child: AppEmptyState(
                icon: filtered ? LucideIcons.searchX : widget.section.icon,
                title: filtered ? 'لا توجد نتائج مطابقة' : 'لا توجد بيانات بعد',
                action: !filtered && widget.canManage
                    ? AppAddButton(
                        label: 'إضافة ${widget.section.singular}',
                        onPressed: () => _edit(),
                        secondary: true,
                      )
                    : null,
              ),
            )
          else ...[
            if (_isCenters)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${data.total} مركز تكلفة مطابق',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      'صفحة ${_page + 1} من ${(data.total / data.size).ceil()}',
                      style: TextStyle(color: tokens.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            for (final record in data.items) ...[
              RepaintBoundary(
                child: _ReferenceCard(
                  record: record,
                  section: widget.section,
                  canManage: widget.canManage,
                  onEdit: () => _edit(record),
                  onOpen: switch (widget.section) {
                    SettingsSection.contractors => () => setState(
                      () => _openedContractorId = record.id,
                    ),
                    SettingsSection.costCenters when widget.canOpenCenter =>
                      () => setState(() => _openedCenterId = record.id),
                    _ => null,
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 2),
            AppPagination(
              page: _page,
              size: data.size,
              total: data.total,
              disabled: _loading,
              onChanged: (page) {
                setState(() => _page = page);
                _load();
              },
            ),
          ],
        ],
      ),
    );
  }
}

const _statusOptions = {'': 'كل الحالات', 'true': 'نشط', 'false': 'غير نشط'};
const _levelOptions = {'': 'البنود الرئيسية', 'sub': 'البنود الفرعية'};
const _typeOptions = {'': 'كل الأنواع', 'PROJECT': 'مشروع', 'OFFICE': 'مكتب'};
Widget _choice(
  String label,
  String value,
  Map<String, String> options,
  ValueChanged<String> onChanged,
) => AppSelect<String>(
  compact: true,
  label: label,
  value: value,
  options: [
    for (final entry in options.entries)
      AppSelectOption(value: entry.key, label: entry.value),
  ],
  onChanged: (value) => onChanged(value ?? ''),
);

/// One card frame for every reference list; each section adds its own data:
/// contractors and cost centres open their detail files; units and categories
/// show their input mode or level.
class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({
    required this.record,
    required this.section,
    required this.canManage,
    required this.onEdit,
    this.onOpen,
  });

  final ReferenceRecord record;
  final SettingsSection section;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final office = record.type == 'OFFICE';
    final (icon, kind) = switch (section) {
      SettingsSection.contractors => (LucideIcons.hardHat, 'ملف مقاول'),
      SettingsSection.costCenters => (
        office ? LucideIcons.building2 : LucideIcons.hardHat,
        office ? 'مكتب إداري' : 'مشروع',
      ),
      SettingsSection.units => (
        LucideIcons.ruler,
        record.inputMode == 'LUMP_SUM' ? 'مقطوعية' : 'كمية × سعر',
      ),
      SettingsSection.expenseCategories => (
        LucideIcons.tag,
        record.parentId == null ? 'بند رئيسي' : 'بند فرعي',
      ),
    };
    if (section == SettingsSection.costCenters) {
      return _CostCenterReferenceCard(
        record: record,
        kind: kind,
        canManage: canManage,
        onEdit: onEdit,
        onOpen: onOpen,
      );
    }
    final compact =
        section == SettingsSection.units ||
        section == SettingsSection.expenseCategories;
    final center = section == SettingsSection.costCenters;
    final radius = BorderRadius.circular(center ? 20 : 18);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: center
            ? [
                BoxShadow(
                  color: tokens.brandDeep.withValues(alpha: .07),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: center
            ? Color.alphaBlend(
                tokens.brand.withValues(alpha: .025),
                Colors.white,
              )
            : Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: center ? tokens.brand.withValues(alpha: .16) : tokens.line,
          ),
        ),
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              center ? 16 : 14,
              compact
                  ? 10
                  : center
                  ? 16
                  : 14,
              center ? 10 : 6,
              compact
                  ? 10
                  : center
                  ? 16
                  : 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: center ? 44 : 40,
                      height: center ? 44 : 40,
                      decoration: BoxDecoration(
                        color: section == SettingsSection.contractors
                            ? tokens.brandStrong
                            : tokens.wash,
                        borderRadius: BorderRadius.circular(center ? 15 : 13),
                        border: center
                            ? Border.all(
                                color: tokens.brand.withValues(alpha: .12),
                              )
                            : null,
                      ),
                      child: Icon(
                        icon,
                        size: center ? 20 : 19,
                        color: section == SettingsSection.contractors
                            ? Colors.white
                            : tokens.brandStrong,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.name,
                            maxLines: center ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: center ? 15.5 : 15,
                              height: 1.25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                record.code,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  color: tokens.brandStrong,
                                  fontSize: center ? 12 : 11.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                ' · ',
                                style: TextStyle(color: tokens.muted),
                              ),
                              Flexible(
                                child: Text(
                                  center
                                      ? '$kind · ${record.active ? 'نشط' : 'غير نشط'}'
                                      : kind,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tokens.muted,
                                    fontSize: center ? 12 : 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!center)
                      record.active
                          ? const AppTag('نشط', tone: AppTone.success)
                          : const AppTag('غير نشط', tone: AppTone.danger),
                    if (canManage)
                      AppEditButton(tooltip: 'تعديل', onPressed: onEdit)
                    else if (!center)
                      const SizedBox(width: 8),
                    if (center && onOpen != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 5),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: tokens.line),
                          ),
                          child: Icon(
                            LucideIcons.chevronLeft,
                            size: 17,
                            color: tokens.brand,
                          ),
                        ),
                      ),
                  ],
                ),
                if (section == SettingsSection.contractors) ...[
                  Divider(height: 22, color: tokens.line),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'آخر تحديث ${_date(record.updatedAt)}',
                            style: TextStyle(
                              color: tokens.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: onOpen,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            backgroundColor: tokens.brandStrong,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon: const Icon(LucideIcons.arrowLeft, size: 15),
                          label: const Text('عرض الحساب'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CostCenterReferenceCard extends StatelessWidget {
  const _CostCenterReferenceCard({
    required this.record,
    required this.kind,
    required this.canManage,
    required this.onEdit,
    required this.onOpen,
  });

  final ReferenceRecord record;
  final String kind;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final office = record.type == 'OFFICE';
    final radius = BorderRadius.circular(18);
    final accent = office ? AppTokens.warning : tokens.brandStrong;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: tokens.brandDeep.withValues(alpha: .07),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tokens.brand.withValues(alpha: .16)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [tokens.wash.withValues(alpha: .7), Colors.white],
            ),
          ),
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent,
                        accent.withValues(alpha: .58),
                        accent.withValues(alpha: .2),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20,
                            height: 2,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: .75),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              office ? 'مركز إداري' : 'ملف مشروع',
                              style: TextStyle(
                                color: accent,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          record.active
                              ? const AppTag('نشط', tone: AppTone.success)
                              : const AppTag('غير نشط', tone: AppTone.danger),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        record.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.brandDeep,
                          fontSize: 18,
                          height: 1.3,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _CostCenterMetaPill(
                            label: record.code,
                            ltr: true,
                            strong: true,
                          ),
                          _CostCenterMetaPill(label: kind),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(height: 1, color: tokens.line),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (canManage)
                            AppEditButton(tooltip: 'تعديل', onPressed: onEdit),
                          const Spacer(),
                          if (onOpen != null)
                            FilledButton.icon(
                              onPressed: onOpen,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 39),
                                backgroundColor: tokens.brandStrong,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(LucideIcons.arrowLeft, size: 16),
                              label: const Text('عرض التفاصيل'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CostCenterMetaPill extends StatelessWidget {
  const _CostCenterMetaPill({
    required this.label,
    this.ltr = false,
    this.strong = false,
  });

  final String label;
  final bool ltr;
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: context.tokens.line),
    ),
    child: Text(
      label,
      textDirection: ltr ? TextDirection.ltr : null,
      style: TextStyle(
        color: strong ? context.tokens.brandStrong : context.tokens.muted,
        fontSize: 12,
        fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
      ),
    ),
  );
}

class _ReferenceFormSheet extends StatefulWidget {
  const _ReferenceFormSheet({
    required this.repository,
    required this.section,
    this.record,
  });

  final SettingsRepository repository;
  final SettingsSection section;
  final ReferenceRecord? record;

  @override
  State<_ReferenceFormSheet> createState() => _ReferenceFormSheetState();
}

class _ReferenceFormSheetState extends State<_ReferenceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late bool _active;
  late String _type;
  late String _inputMode;
  late String _parentId;
  bool _saving = false;
  String? _error;
  List<ReferenceRecord> _parents = const [];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.record?.name ?? '');
    _code = TextEditingController(text: widget.record?.code ?? '');
    _active = widget.record?.active ?? true;
    _type = widget.record?.type ?? 'PROJECT';
    _inputMode = widget.record?.inputMode ?? 'QUANTITY_RATE';
    _parentId = widget.record?.parentId ?? '';
    if (widget.section == SettingsSection.expenseCategories) _loadParents();
  }

  Future<void> _loadParents() async {
    try {
      final parents = await widget.repository.categoryParents();
      if (mounted) {
        setState(() {
          _parents = parents
              .where((item) => item.id != widget.record?.id)
              .toList();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save(
        section: widget.section,
        name: _name.text,
        code: _code.text,
        active: _active,
        current: widget.record,
        type: _type,
        inputMode: _inputMode,
        parentId: _parentId.isEmpty ? null : _parentId,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppSheetScaffold(
      title:
          '${widget.record == null ? 'إضافة' : 'تعديل'} ${widget.section.singular}',
      subtitle: widget.record?.code,
      closeEnabled: !_saving,
      onClose: () => Navigator.pop(context, false),
      footer: AppSheetActions(
        primaryLabel: 'حفظ',
        busy: _saving,
        onPrimary: _save,
        secondaryLabel: 'إلغاء',
        onSecondary: () => Navigator.pop(context, false),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              MessagePanel(message: _error!),
              const SizedBox(height: AppSpace.sm),
            ],
            TextFormField(
              controller: _name,
              autofocus: widget.record == null,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'الاسم *'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _code,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'الكود *'),
              validator: _required,
            ),
            if (widget.section == SettingsSection.costCenters) ...[
              const SizedBox(height: 14),
              const _FieldLabel('نوع مركز التكلفة *'),
              AppSegmented<String>(
                value: _type,
                options: const [
                  ('PROJECT', 'مشروع', LucideIcons.hardHat),
                  ('OFFICE', 'مكتب', LucideIcons.building2),
                ],
                onChanged: (value) => setState(() => _type = value),
              ),
            ],
            if (widget.section == SettingsSection.expenseCategories) ...[
              const SizedBox(height: 12),
              AppSelect<String>(
                label: 'البند الرئيسي',
                value: _parents.any((item) => item.id == _parentId)
                    ? _parentId
                    : '',
                options: [
                  const AppSelectOption(
                    value: '',
                    label: 'بند رئيسي (بدون أب)',
                  ),
                  for (final parent in _parents)
                    AppSelectOption(
                      value: parent.id,
                      label: parent.name,
                      subtitle: parent.code,
                    ),
                ],
                onChanged: (value) => setState(() => _parentId = value ?? ''),
              ),
            ],
            if (widget.section == SettingsSection.units) ...[
              const SizedBox(height: 14),
              const _FieldLabel('طريقة إدخال الوحدة *'),
              AppSegmented<String>(
                value: _inputMode,
                options: const [
                  ('QUANTITY_RATE', 'كمية × سعر', LucideIcons.calculator),
                  ('LUMP_SUM', 'مقطوعية', LucideIcons.package),
                ],
                onChanged: (value) => setState(() => _inputMode = value),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: tokens.sunken,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tokens.line),
              ),
              child: SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                title: const Text(
                  'نشط',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _active ? 'يظهر في الاختيارات' : 'مخفي من الاختيارات الجديدة',
                  style: TextStyle(fontSize: 12, color: tokens.muted),
                ),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: context.tokens.ink,
      ),
    ),
  );
}

String _date(String value) => value.length >= 10 ? value.substring(0, 10) : '—';
