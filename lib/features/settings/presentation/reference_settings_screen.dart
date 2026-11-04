import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/format/exact_decimal.dart';
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
  });

  final SettingsRepository repository;
  final SettingsSection section;
  final bool canManage;

  @override
  State<ReferenceSettingsScreen> createState() =>
      _ReferenceSettingsScreenState();
}

/// Section-specific filters, as one value so the shared filter sheet can
/// edit a draft of them.
typedef _Filters = ({
  String status,
  String level,
  String type,
  String financial,
  String payment,
  int size,
});

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
      (status: '', level: '', type: '', financial: '', payment: '', size: size);

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
        financial: _filters.financial,
        payment: _filters.payment,
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
      f.status.isNotEmpty ||
      f.level.isNotEmpty ||
      f.type.isNotEmpty ||
      f.financial.isNotEmpty ||
      f.payment.isNotEmpty;

  String get _summary {
    final f = _filters;
    return [
      if (f.status.isNotEmpty) _statusOptions[f.status],
      if (f.level.isNotEmpty) _levelOptions[f.level],
      if (f.type.isNotEmpty) _typeOptions[f.type],
      if (f.financial.isNotEmpty) _financialOptions[f.financial],
      if (f.payment.isNotEmpty) _paymentOptions[f.payment],
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
            update((
              status: value,
              level: f.level,
              type: f.type,
              financial: f.financial,
              payment: f.payment,
              size: f.size,
            ));
          }),
          if (widget.section == SettingsSection.expenseCategories)
            _choice('المستوى', f.level, _levelOptions, (value) {
              update((
                status: f.status,
                level: value,
                type: f.type,
                financial: f.financial,
                payment: f.payment,
                size: f.size,
              ));
            }),
          if (_isCenters) ...[
            _choice('النوع', f.type, _typeOptions, (value) {
              update((
                status: f.status,
                level: f.level,
                type: value,
                financial: f.financial,
                payment: f.payment,
                size: f.size,
              ));
            }),
            _choice('الحركة', f.financial, _financialOptions, (value) {
              update((
                status: f.status,
                level: f.level,
                type: f.type,
                financial: value,
                payment: f.payment,
                size: f.size,
              ));
            }),
            _choice('السداد', f.payment, _paymentOptions, (value) {
              update((
                status: f.status,
                level: f.level,
                type: f.type,
                financial: f.financial,
                payment: value,
                size: f.size,
              ));
            }),
          ],
          appPageSizeField(
            value: f.size,
            onChanged: (size) => update((
              status: f.status,
              level: f.level,
              type: f.type,
              financial: f.financial,
              payment: f.payment,
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

  Future<void> _edit([ReferenceRecord? record]) async {
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
    }
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
        onBack: () => setState(() => _openedCenterId = null),
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
                ? 'صورة مالية لكل مشروع: الوارد والمنصرف ومديونية مستخلصات المقاولين.'
                : data == null
                ? null
                : '${data.total} سجل',
            action: widget.canManage
                ? FilledButton.icon(
                    onPressed: () => _edit(),
                    icon: const Icon(LucideIcons.plus, size: 17),
                    label: Text(_isCenters ? 'مركز جديد' : 'إضافة'),
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
                    ? OutlinedButton.icon(
                        onPressed: () => _edit(),
                        icon: const Icon(LucideIcons.plus, size: 17),
                        label: Text('إضافة ${widget.section.singular}'),
                      )
                    : null,
              ),
            )
          else ...[
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
                    SettingsSection.costCenters => () => setState(
                      () => _openedCenterId = record.id,
                    ),
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
const _financialOptions = {
  '': 'كل الحركات',
  'INCOMING': 'به وارد',
  'OUTGOING': 'به منصرف',
  'DEBT': 'عليه مديونية',
};
const _paymentOptions = {
  '': 'كل حالات السداد',
  'PAID': 'مدفوع بالكامل',
  'PARTIAL': 'مدفوع جزئيًا',
  'UNPAID': 'غير مدفوع',
  'PENDING': 'بانتظار الاعتماد',
  'REJECTED': 'مرفوض',
};

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
/// contractors open their account, cost centres show in/out/debt, units and
/// categories show their input mode or level.
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
        office ? 'مركز إداري' : 'ملف مشروع',
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
    final compact =
        section == SettingsSection.units ||
        section == SettingsSection.expenseCategories;
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: tokens.line),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            compact ? 10 : 14,
            6,
            compact ? 10 : 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: section == SettingsSection.contractors
                          ? tokens.brandStrong
                          : tokens.wash,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      icon,
                      size: 19,
                      color: section == SettingsSection.contractors
                          ? Colors.white
                          : tokens.brandStrong,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              record.code,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                color: tokens.brandStrong,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(' · ', style: TextStyle(color: tokens.muted)),
                            Flexible(
                              child: Text(
                                kind,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.muted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  record.active
                      ? const AppTag('نشط', tone: AppTone.success)
                      : const AppTag('غير نشط', tone: AppTone.danger),
                  if (canManage)
                    IconButton(
                      tooltip: 'تعديل',
                      visualDensity: VisualDensity.compact,
                      onPressed: onEdit,
                      icon: const Icon(LucideIcons.pencil, size: 17),
                    )
                  else
                    const SizedBox(width: 8),
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
              if (section == SettingsSection.costCenters) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      AppTag(office ? 'مكتب' : 'مشروع'),
                      AppTag(
                        '${record.extractCount ?? 0} مستخلص',
                        icon: LucideIcons.fileSpreadsheet,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: tokens.sunken,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tokens.line),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: _CenterMetric(
                              label: 'وارد',
                              value: _money(record.incoming),
                              color: AppTokens.success,
                            ),
                          ),
                          VerticalDivider(width: 1, color: tokens.line),
                          Expanded(
                            child: _CenterMetric(
                              label: 'منصرف',
                              value: _money(record.outgoing),
                              color: AppTokens.danger,
                            ),
                          ),
                          VerticalDivider(width: 1, color: tokens.line),
                          Expanded(
                            child: _CenterMetric(
                              label: 'مديون',
                              value: _money(record.debt),
                              color: AppTokens.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterMetric extends StatelessWidget {
  const _CenterMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
    child: Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.tokens.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: color,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
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

String _money(String? value) =>
    (ExactDecimal.tryParse(value ?? '') ?? ExactDecimal.zero).money();
