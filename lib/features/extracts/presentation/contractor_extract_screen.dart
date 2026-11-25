import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/app_buttons.dart';
import '../../../core/format/arabic_search.dart';
import '../../../core/format/exact_decimal.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_filter.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/domain/custody_models.dart' show shortDate;
import '../../custody/presentation/custody_widgets.dart';
import '../../settings/domain/settings_models.dart';
import '../data/extract_repository.dart';
import '../domain/extract_models.dart';

class ContractorExtractScreen extends StatefulWidget {
  const ContractorExtractScreen({
    super.key,
    required this.repository,
    required this.permissions,
  });
  final ExtractRepository repository;
  final Set<String> permissions;
  @override
  State<ContractorExtractScreen> createState() =>
      _ContractorExtractScreenState();
}

class _ContractorExtractScreenState extends State<ContractorExtractScreen> {
  final _search = TextEditingController();
  ExtractOptions? _options;
  List<ContractorExtract> _extracts = const [];
  String _contractorId = '', _centerId = '', _approval = '';
  String? _expandedId, _error;
  int _page = 0, _pageSize = 10;
  bool _loading = true;

  bool get _canApprove =>
      widget.permissions.contains('CONTRACTOR_EXTRACT_APPROVE');
  bool get _canCreate =>
      widget.permissions.contains('CONTRACTOR_EXTRACT_CREATE');
  bool get _canClient =>
      widget.permissions.contains('CONTRACTOR_EXTRACT_CLIENT_PRICE');
  List<ContractorExtract> get _filtered {
    final query = normalizeArabic(_search.text);
    return _extracts
        .where((extract) {
          if (_approval == 'waiting' &&
              extract.status != 'PENDING' &&
              _waitingCount(extract) == 0) {
            return false;
          }
          return query.isEmpty ||
              normalizeArabic(extract.contractorName).contains(query) ||
              normalizeArabic(extract.centerName).contains(query) ||
              '${extract.extractNo}'.contains(query);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait([
        widget.repository.options(),
        widget.repository.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _options = values[0] as ExtractOptions;
        _extracts = values[1] as List<ContractorExtract>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.repository.list(
        contractorId: _contractorId,
        centerId: _centerId,
      );
      if (mounted) setState(() => _extracts = rows);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _replace(ContractorExtract changed) => setState(
    () => _extracts = [
      for (final row in _extracts)
        if (row.id == changed.id) changed else row,
    ],
  );
  Future<void> _reloadOne(String id) async =>
      _replace(await widget.repository.get(id));

  Future<void> _create() async {
    if (_options == null) return;
    final saved = await showAppSheet<bool>(
      context,
      tall: true,
      dismissible: false,
      builder: (_) => _CreateExtractSheet(
        repository: widget.repository,
        options: _options!,
        initialContractorId: _contractorId,
        initialCenterId: _centerId,
        canClient: _canClient,
      ),
    );
    if (saved == true && mounted) {
      _notify('تم حفظ المستخلص');
      await _refresh();
    }
  }

  Future<void> _edit(ContractorExtract extract) async {
    if (_options == null) return;
    final changed = await showAppSheet<ContractorExtract>(
      context,
      tall: true,
      dismissible: false,
      builder: (_) => _CreateExtractSheet(
        repository: widget.repository,
        options: _options!,
        initialContractorId: extract.contractorId,
        initialCenterId: extract.centerId,
        canClient: _canClient,
        extract: extract,
      ),
    );
    if (changed != null && mounted) {
      _replace(changed);
      _notify('تم تعديل المستخلص');
    }
  }

  void _notify(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));
  String get _summary {
    String? name(List<ReferenceRecord>? list, String id) => id.isEmpty
        ? null
        : list?.where((item) => item.id == id).firstOrNull?.name;
    return [
      ?name(_options?.centers, _centerId),
      ?name(_options?.contractors, _contractorId),
      if (_approval == 'waiting') 'فيها ما ينتظر الاعتماد',
    ].join(' · ');
  }

  Future<void> _openFilters() async {
    final result = await showAppFilterSheet<(String, String, String, int)>(
      context: context,
      subtitle: 'المستخلصات',
      initial: (_centerId, _contractorId, _approval, _pageSize),
      empty: ('', '', '', _pageSize),
      isActive: (d) => d.$1.isNotEmpty || d.$2.isNotEmpty || d.$3.isNotEmpty,
      fields: (context, draft, update) {
        final (center, contractor, approval, size) = draft;
        return AppFilterGrid(
          children: [
            _referenceFilter(
              label: 'مركز التكلفة',
              all: 'كل مراكز التكلفة',
              value: center,
              items: _options?.centers ?? const [],
              onChanged: (v) => update((v, contractor, approval, size)),
            ),
            _referenceFilter(
              label: 'المقاول',
              all: 'كل المقاولين',
              value: contractor,
              items: _options?.contractors ?? const [],
              onChanged: (v) => update((center, v, approval, size)),
            ),
            AppSelect<String>(
              compact: true,
              searchable: false,
              label: 'الاعتماد',
              value: approval,
              options: const [
                AppSelectOption(value: '', label: 'كل المستخلصات'),
                AppSelectOption(
                  value: 'waiting',
                  label: 'فيها ما ينتظر الاعتماد',
                ),
              ],
              onChanged: (v) => update((center, contractor, v ?? '', size)),
            ),
            appPageSizeField(
              value: size,
              onChanged: (v) => update((center, contractor, approval, v)),
            ),
          ],
        );
      },
    );
    if (result == null || !mounted) return;
    final reload = result.$1 != _centerId || result.$2 != _contractorId;
    setState(() {
      _centerId = result.$1;
      _contractorId = result.$2;
      _approval = result.$3;
      _pageSize = result.$4;
      _page = 0;
    });
    if (reload) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final start = _page * _pageSize;
    final visible = start >= filtered.length
        ? const <ContractorExtract>[]
        : filtered.sublist(
            start,
            (start + _pageSize).clamp(0, filtered.length),
          );
    return RefreshIndicator(
      onRefresh: _refresh,
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
            title: 'مستخلصات المقاولين',
            subtitle: '${_extracts.length} مستخلص',
            action: _canCreate
                ? AppAddButton(
                    label: 'مستخلص جديد',
                    onPressed: _options == null ? null : _create,
                  )
                : null,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            textAlign: TextAlign.right,
            onChanged: (_) => setState(() => _page = 0),
            decoration: InputDecoration(
              hintText: 'ابحث بالمقاول، المركز أو رقم المستخلص…',
              prefixIcon: const Icon(LucideIcons.search, size: 19),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() => _page = 0);
                      },
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          AppFilterBar(
            activeCount: _summary.isEmpty ? 0 : 1,
            summary: _summary,
            onOpen: _openFilters,
            onClear: () {
              final reload = _centerId.isNotEmpty || _contractorId.isNotEmpty;
              setState(() {
                _centerId = '';
                _contractorId = '';
                _approval = '';
                _page = 0;
              });
              if (reload) _refresh();
            },
          ),
          if (_loading && _extracts.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 12),
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _initialize)
          else if (_loading && _extracts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visible.isEmpty)
            const AppEmptyState(
              icon: LucideIcons.fileSpreadsheet,
              title: 'لا توجد مستخلصات مطابقة للفلاتر',
            )
          else ...[
            for (final extract in visible) ...[
              ContractorExtractCard(
                extract: extract,
                expanded: _expandedId == extract.id,
                showFinancials: extract.financialsVisible,
                canReview: _canApprove,
                repository: widget.repository,
                permissions: widget.permissions,
                units: _options?.units ?? const [],
                onToggle: () => setState(
                  () => _expandedId = _expandedId == extract.id
                      ? null
                      : extract.id,
                ),
                onChanged: _replace,
                onReload: () => _reloadOne(extract.id),
                onEdit: _canCreate && extract.financialsVisible
                    ? () => _edit(extract)
                    : null,
              ),
              const SizedBox(height: 10),
            ],
            AppPagination(
              page: _page,
              size: _pageSize,
              total: filtered.length,
              disabled: _loading,
              onChanged: (v) => setState(() => _page = v),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _referenceFilter({
  required String label,
  required String all,
  required String value,
  required List<ReferenceRecord> items,
  required ValueChanged<String> onChanged,
}) => AppSelect<String>(
  compact: true,
  label: label,
  value: value,
  options: [
    AppSelectOption(value: '', label: all),
    for (final item in items)
      AppSelectOption(value: item.id, label: item.name, subtitle: item.code),
  ],
  onChanged: (v) => onChanged(v ?? ''),
);

class ContractorExtractCard extends StatefulWidget {
  const ContractorExtractCard({
    super.key,
    required this.extract,
    required this.expanded,
    required this.showFinancials,
    required this.onToggle,
    this.canReview = false,
    this.repository,
    this.permissions = const {},
    this.units = const [],
    this.onChanged,
    this.onReload,
    this.onPrice,
    this.onReject,
    this.onEdit,
  });
  final ContractorExtract extract;
  final bool expanded, showFinancials, canReview;
  final VoidCallback onToggle;
  final ExtractRepository? repository;
  final Set<String> permissions;
  final List<ReferenceRecord> units;
  final ValueChanged<ContractorExtract>? onChanged;
  final Future<void> Function()? onReload;
  final VoidCallback? onPrice, onReject;
  final VoidCallback? onEdit;
  @override
  State<ContractorExtractCard> createState() => _ContractorExtractCardState();
}

class _ContractorExtractCardState extends State<ContractorExtractCard> {
  bool _measuring = false, _busy = false;
  final Map<String, TextEditingController> _drafts = {};
  final _all = TextEditingController();
  bool get _canApprove =>
      widget.permissions.contains('CONTRACTOR_EXTRACT_APPROVE') ||
      widget.canReview;
  bool get _canMeasure =>
      _canApprove || widget.permissions.contains('CONTRACTOR_EXTRACT_MEASURE');
  bool get _canClient =>
      widget.permissions.contains('CONTRACTOR_EXTRACT_CLIENT_PRICE');
  List<ExtractItem> get _measurable => widget.extract.items
      .where(
        (i) =>
            i.kind == 'WORK' &&
            i.status == 'APPROVED' &&
            i.pendingMeasurementId == null,
      )
      .toList();
  List<String> get _measurementIds => widget.extract.items
      .map((i) => i.pendingMeasurementId)
      .whereType<String>()
      .toList();

  @override
  void dispose() {
    _clearDrafts();
    _all.dispose();
    super.dispose();
  }

  void _clearDrafts() {
    for (final c in _drafts.values) {
      c.dispose();
    }
    _drafts.clear();
  }

  void _startMeasurement() {
    _clearDrafts();
    for (final item in _measurable) {
      _drafts[item.id] = TextEditingController(
        text: _displayPercent(item.percentage),
      );
    }
    setState(() => _measuring = true);
  }

  Map<String, String> get _changed {
    final result = <String, String>{};
    for (final item in _measurable) {
      final entered = ExactDecimal.tryParse(_drafts[item.id]?.text ?? '');
      final current = ExactDecimal.tryParse(_displayPercent(item.percentage));
      if (entered != null &&
          entered.compareTo(ExactDecimal.zero) >= 0 &&
          entered.compareTo(ExactDecimal.parse('100')) <= 0 &&
          entered.compareTo(current ?? ExactDecimal.zero) != 0) {
        result[item.id] = entered.percent.toString();
      }
    }
    return result;
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (widget.onReload != null) await widget.onReload!();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveMeasurement() async {
    if (_changed.isEmpty || widget.repository == null) return;
    await _run(
      () => widget.repository!.recordMeasurement(
        extractId: widget.extract.id,
        percentages: _changed,
      ),
      _canApprove ? 'تم حفظ الحصر واعتماده' : 'تم إرسال الحصر للاعتماد',
    );
    if (mounted) setState(() => _measuring = false);
  }

  Future<void> _reviewMeasurements(List<String> ids, String decision) async {
    if (widget.repository != null && ids.isNotEmpty) {
      await _run(
        () => widget.repository!.reviewMeasurements(
          extractId: widget.extract.id,
          ids: ids,
          decision: decision,
        ),
        decision == 'APPROVED' ? 'تم اعتماد الحصر' : 'تم رفض الحصر',
      );
    }
  }

  Future<void> _addItem() async {
    if (widget.repository == null) return;
    final input = await showAppSheet<AddedExtractItemInput>(
      context,
      tall: true,
      builder: (_) =>
          _AddItemSheet(units: widget.units, immediate: _canApprove),
    );
    if (input != null && mounted) {
      await _run(() async {
        widget.onChanged?.call(
          await widget.repository!.addItem(
            extractId: widget.extract.id,
            item: input,
          ),
        );
      }, _canApprove ? 'تمت إضافة البند' : 'تم إرسال البند للاعتماد');
    }
  }

  Future<void> _reviewItem(ExtractItem item, String decision) async {
    if (widget.repository == null) return;
    String? rate, clientRate;
    if (decision == 'APPROVED') {
      final values = await showAppSheet<(String, String?)>(
        context,
        builder: (_) => _ReviewItemSheet(item: item, canClient: _canClient),
      );
      if (values == null || !mounted) return;
      rate = values.$1;
      clientRate = values.$2;
    } else if (!await _confirm(
          context,
          title: 'رفض البند المضاف',
          message: 'سيُحذف البند من المستخلص. هل تريد المتابعة؟',
        ) ||
        !mounted) {
      return;
    }
    await _run(() async {
      widget.onChanged?.call(
        await widget.repository!.reviewItem(
          extractId: widget.extract.id,
          itemId: item.id,
          decision: decision,
          rate: rate,
          clientRate: clientRate,
        ),
      );
    }, decision == 'APPROVED' ? 'تم اعتماد البند' : 'تم رفض البند');
  }

  Future<void> _reviewExtract(String decision) async {
    if (widget.repository == null) return;
    String? reason;
    if (decision == 'REJECTED') {
      reason = await showAppSheet<String>(
        context,
        builder: (_) => _RejectSheet(extract: widget.extract),
      );
      if (reason == null || !mounted) return;
    }
    await _run(() async {
      widget.onChanged?.call(
        await widget.repository!.review(
          extract: widget.extract,
          decision: decision,
          reason: reason,
        ),
      );
    }, decision == 'APPROVED' ? 'تم اعتماد المستخلص' : 'تم رفض المستخلص');
  }

  @override
  Widget build(BuildContext context) {
    final extract = widget.extract, tokens = context.tokens;
    final approved = extract.status == 'APPROVED',
        waiting = _waitingCount(extract),
        changed = _measuring ? _changed.length : 0;
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: widget.expanded
              ? tokens.brand.withValues(alpha: .45)
              : tokens.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: tokens.wash,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          LucideIcons.fileSpreadsheet,
                          color: tokens.brandStrong,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              extract.contractorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${extract.centerName} · مستخلص ${extract.extractNo}',
                              style: TextStyle(
                                color: tokens.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: widget.expanded ? .5 : 0,
                        duration: AppMotion.duration(
                          context,
                          AppMotion.feedback,
                        ),
                        child: Icon(
                          LucideIcons.chevronDown,
                          color: tokens.muted,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _statusTag(extract.status),
                      if (waiting > 0)
                        AppTag(
                          'بانتظار الاعتماد ($waiting)',
                          tone: AppTone.warning,
                          icon: LucideIcons.clock,
                        ),
                      AppTag(
                        shortDate(extract.extractDate),
                        icon: LucideIcons.calendarDays,
                      ),
                    ],
                  ),
                  if (widget.showFinancials && extract.financialsVisible) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: tokens.sunken,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tokens.line),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _Amount(
                              label: 'المستحق',
                              value: approved ? _money(extract.net) : '—',
                            ),
                          ),
                          Expanded(
                            child: _Amount(
                              label: 'المتبقي',
                              value: approved
                                  ? _money(extract.outstanding)
                                  : '—',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (widget.expanded)
            Container(
              color: tokens.sunken,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_canMeasure &&
                      !_canApprove &&
                      approved &&
                      !_measuring) ...[
                    _EngineerMeasurementPanel(
                      pendingCount: _measurementIds.length,
                      canStart: _measurable.isNotEmpty && !_busy,
                      onStart: _startMeasurement,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (widget.onEdit != null) ...[
                    OutlinedButton.icon(
                      key: const ValueKey('edit-extract-button'),
                      onPressed: _busy ? null : widget.onEdit,
                      icon: const Icon(LucideIcons.pencil, size: 17),
                      label: const Text('تعديل المستخلص'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_measuring) ...[
                    Text(
                      'أدخل نسبة الإنجاز التراكمية لكل بند ثم ارفع الحصر للاعتماد.',
                      style: TextStyle(
                        color: tokens.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _all,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_decimalFormatter],
                      decoration: const InputDecoration(
                        labelText: 'نفس النسبة لكل البنود',
                        suffixText: '%',
                      ),
                      onChanged: (value) {
                        for (final c in _drafts.values) {
                          c.text = value;
                        }
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  _ExtractItemsTable(
                    items: extract.items,
                    showFinancials:
                        widget.showFinancials && extract.financialsVisible,
                    measuring: _measuring,
                    drafts: _drafts,
                    canReview: _canApprove && widget.repository != null,
                    onDraftChanged: () => setState(() {}),
                    onReviewMeasurement: (item, decision) =>
                        _reviewMeasurements([
                          item.pendingMeasurementId!,
                        ], decision),
                    onReviewItem: _reviewItem,
                  ),
                  if (_measuring) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _measuring = false),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _busy || changed == 0
                                ? null
                                : _saveMeasurement,
                            icon: const Icon(LucideIcons.ruler, size: 17),
                            label: Text('حفظ الحصر ($changed بنود)'),
                          ),
                        ),
                      ],
                    ),
                  ] else if (approved && widget.repository != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_canApprove && _measurable.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _startMeasurement,
                            icon: const Icon(LucideIcons.ruler, size: 17),
                            label: const Text('تسجيل حصر'),
                          ),
                        if (_canMeasure)
                          AppAddButton(
                            label: 'إضافة بند',
                            onPressed: _busy ? null : _addItem,
                            secondary: true,
                          ),
                        if (_canApprove && _measurementIds.length > 1) ...[
                          FilledButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _reviewMeasurements(
                                    _measurementIds,
                                    'APPROVED',
                                  ),
                            icon: const Icon(LucideIcons.check, size: 17),
                            label: const Text('اعتماد الحصر كله'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _reviewMeasurements(
                                    _measurementIds,
                                    'REJECTED',
                                  ),
                            icon: const Icon(LucideIcons.x, size: 17),
                            label: const Text('رفض الحصر كله'),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (_canApprove &&
                      extract.status == 'PENDING' &&
                      widget.repository != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _reviewExtract('REJECTED'),
                            child: const Text('رفض'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _reviewExtract('APPROVED'),
                            child: const Text('اعتماد المستخلص'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (extract.note?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text('ملاحظات: ${extract.note}'),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ExtractItemsTable extends StatefulWidget {
  const _ExtractItemsTable({
    required this.items,
    required this.showFinancials,
    required this.measuring,
    required this.drafts,
    required this.canReview,
    required this.onDraftChanged,
    required this.onReviewMeasurement,
    required this.onReviewItem,
  });
  final List<ExtractItem> items;
  final bool showFinancials, measuring, canReview;
  final Map<String, TextEditingController> drafts;
  final VoidCallback onDraftChanged;
  final void Function(ExtractItem, String) onReviewMeasurement, onReviewItem;

  @override
  State<_ExtractItemsTable> createState() => _ExtractItemsTableState();
}

class _ExtractItemsTableState extends State<_ExtractItemsTable> {
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tableWidth = widget.showFinancials
        ? (widget.canReview ? 840.0 : 760.0)
        : (widget.canReview ? 620.0 : 520.0);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.line),
      ),
      child: Scrollbar(
        key: const ValueKey('extract-items-horizontal-scrollbar'),
        controller: _horizontal,
        thumbVisibility: true,
        interactive: true,
        thickness: 5,
        radius: const Radius.circular(999),
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            key: const ValueKey('extract-items-scroll-content'),
            width: tableWidth,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Table(
                columnWidths: {
                  0: const FlexColumnWidth(2.2),
                  1: const FlexColumnWidth(.8),
                  2: const FlexColumnWidth(.9),
                  3: const FlexColumnWidth(1.35),
                  if (widget.showFinancials) 4: const FlexColumnWidth(1),
                  if (widget.showFinancials) 5: const FlexColumnWidth(1.1),
                  if (widget.canReview)
                    (widget.showFinancials ? 6 : 4): const FlexColumnWidth(.9),
                },
                border: TableBorder(
                  horizontalInside: BorderSide(color: tokens.line),
                ),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: tokens.sunken),
                    children: [
                      const _Cell('البند', header: true),
                      const _Cell('الكمية', header: true),
                      const _Cell('الوحدة', header: true),
                      const _Cell('الإنجاز', header: true),
                      if (widget.showFinancials)
                        const _Cell('سعر الوحدة', header: true),
                      if (widget.showFinancials)
                        const _Cell('الإجمالي', header: true),
                      if (widget.canReview) const _Cell('مراجعة', header: true),
                    ],
                  ),
                  for (final item in widget.items)
                    TableRow(
                      decoration: BoxDecoration(
                        color:
                            item.status == 'PENDING' ||
                                item.pendingMeasurementId != null
                            ? const Color(0xFFFFF4DF)
                            : Colors.white,
                      ),
                      children: [
                        _Description(item),
                        _Cell(_number(item.quantity), numeric: true),
                        _Cell(item.unitName),
                        if (widget.measuring &&
                            widget.drafts.containsKey(item.id))
                          Padding(
                            padding: const EdgeInsets.all(5),
                            child: TextField(
                              controller: widget.drafts[item.id],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [_decimalFormatter],
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                isDense: true,
                                suffixText: '%',
                              ),
                              onChanged: (_) => widget.onDraftChanged(),
                            ),
                          )
                        else
                          _Progress(item),
                        if (widget.showFinancials)
                          _Cell(_money(item.rate), numeric: true),
                        if (widget.showFinancials) _TotalCell(item),
                        if (widget.canReview)
                          _ReviewButtons(
                            item: item,
                            onMeasurement: widget.onReviewMeasurement,
                            onItem: widget.onReviewItem,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EngineerMeasurementPanel extends StatelessWidget {
  const _EngineerMeasurementPanel({
    required this.pendingCount,
    required this.canStart,
    required this.onStart,
  });

  final int pendingCount;
  final bool canStart;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.wash,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.ruler, color: tokens.brandStrong, size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'متابعة التنفيذ والحصر',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
              ),
              if (pendingCount > 0)
                AppTag(
                  '$pendingCount بانتظار الاعتماد',
                  tone: AppTone.warning,
                  icon: LucideIcons.clock,
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'حدّث نسب الإنجاز التراكمية وارفع حصرًا جديدًا لهذا المستخلص.',
            style: TextStyle(
              color: tokens.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: canStart ? onStart : null,
            icon: const Icon(LucideIcons.upload, size: 17),
            label: const Text('رفع حصر جديد'),
          ),
        ],
      ),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description(this.item);
  final ExtractItem item;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.description,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
        if (item.status == 'PENDING')
          const AppTag('بند مضاف', tone: AppTone.warning),
        if (item.kind == 'RETURN') const AppTag('مرتجع', tone: AppTone.danger),
        if (item.kind == 'PENALTY') const AppTag('خصم', tone: AppTone.danger),
      ],
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress(this.item);
  final ExtractItem item;
  @override
  Widget build(BuildContext context) {
    if (item.kind != 'WORK') return const _Cell('—');
    final current = _share(item.percentage),
        pending = item.pendingPercentage == null
            ? null
            : _share(item.pendingPercentage);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        children: [
          SizedBox(
            height: 7,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: context.tokens.line,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: pending ?? current,
                  child: Container(
                    decoration: BoxDecoration(
                      color: pending == null
                          ? context.tokens.brand
                          : const Color(0xFFF2B45D),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: current,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.tokens.brand,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${_displayPercent(item.percentage)}%',
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          if (pending != null)
            Text(
              '← ${_displayPercent(item.pendingPercentage)}% معلّق',
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFF9A5B00),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalCell extends StatelessWidget {
  const _TotalCell(this.item);
  final ExtractItem item;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(5),
    child: Column(
      children: [
        Text(
          _money(item.amount),
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
        if (item.pendingPercentage != null)
          Text(
            '← ${_pendingAmount(item)}',
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF9A5B00),
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    ),
  );
}

class _ReviewButtons extends StatelessWidget {
  const _ReviewButtons({
    required this.item,
    required this.onMeasurement,
    required this.onItem,
  });
  final ExtractItem item;
  final void Function(ExtractItem, String) onMeasurement, onItem;
  @override
  Widget build(BuildContext context) {
    if (item.pendingMeasurementId == null && item.status != 'PENDING') {
      return const SizedBox.shrink();
    }
    void decide(String value) => item.status == 'PENDING'
        ? onItem(item, value)
        : onMeasurement(item, value);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        InkWell(
          onTap: () => decide('APPROVED'),
          child: const SizedBox(
            width: 30,
            height: 36,
            child: Icon(LucideIcons.check, color: AppTokens.success, size: 18),
          ),
        ),
        InkWell(
          onTap: () => decide('REJECTED'),
          child: const SizedBox(
            width: 30,
            height: 36,
            child: Icon(LucideIcons.x, color: AppTokens.danger, size: 18),
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.value, {this.header = false, this.numeric = false});
  final String value;
  final bool header, numeric;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
    child: Text(
      value,
      textAlign: TextAlign.center,
      textDirection: numeric ? TextDirection.ltr : null,
      style: TextStyle(
        fontSize: header ? 10.5 : 11.5,
        fontWeight: header ? FontWeight.w700 : FontWeight.w600,
        color: header ? context.tokens.muted : null,
      ),
    ),
  );
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.tokens.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        AppMoney(value, size: 16),
      ],
    ),
  );
}

class _RejectSheet extends StatefulWidget {
  const _RejectSheet({required this.extract});
  final ContractorExtract extract;
  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  final _form = GlobalKey<FormState>(), _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: 'رفض المستخلص',
    subtitle:
        '${widget.extract.contractorName} · مستخلص ${widget.extract.extractNo}',
    footer: AppSheetActions(
      primaryLabel: 'تأكيد الرفض',
      destructive: true,
      onPrimary: () {
        if (_form.currentState!.validate()) {
          Navigator.pop(context, _reason.text.trim());
        }
      },
      secondaryLabel: 'إلغاء',
      onSecondary: () => Navigator.pop(context),
    ),
    child: Form(
      key: _form,
      child: TextFormField(
        controller: _reason,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'سبب الرفض *'),
        validator: _required,
      ),
    ),
  );
}

class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet({required this.units, required this.immediate});
  final List<ReferenceRecord> units;
  final bool immediate;
  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _form = GlobalKey<FormState>(),
      _description = TextEditingController(),
      _quantity = TextEditingController(),
      _rate = TextEditingController();
  String _unitId = '';
  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: 'إضافة بند',
    subtitle: widget.immediate
        ? 'سيُضاف البند مباشرة'
        : 'سيبقى البند بانتظار اعتماد المدير',
    footer: AppSheetActions(
      primaryLabel: widget.immediate ? 'إضافة البند' : 'إرسال للاعتماد',
      onPrimary: () {
        if (_form.currentState!.validate()) {
          Navigator.pop(
            context,
            AddedExtractItemInput(
              description: _description.text,
              unitId: _unitId,
              quantity: _quantity.text,
              rate: _rate.text,
            ),
          );
        }
      },
      secondaryLabel: 'إلغاء',
      onSecondary: () => Navigator.pop(context),
    ),
    child: Form(
      key: _form,
      child: Column(
        children: [
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'بيان الأعمال *'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          AppSelect<String>(
            label: 'وحدة القياس *',
            value: _unitId.isEmpty ? null : _unitId,
            options: [
              for (final unit in widget.units)
                AppSelectOption(
                  value: unit.id,
                  label: unit.name,
                  subtitle: unit.code,
                ),
            ],
            validator: (v) =>
                v == null || v.isEmpty ? 'اختر وحدة القياس' : null,
            onChanged: (v) => setState(() => _unitId = v ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalFormatter],
            decoration: const InputDecoration(labelText: 'الكمية *'),
            validator: _positive,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalFormatter],
            decoration: const InputDecoration(labelText: 'سعر الوحدة *'),
            validator: _nonNegative,
          ),
        ],
      ),
    ),
  );
}

class _ReviewItemSheet extends StatefulWidget {
  const _ReviewItemSheet({required this.item, required this.canClient});
  final ExtractItem item;
  final bool canClient;
  @override
  State<_ReviewItemSheet> createState() => _ReviewItemSheetState();
}

class _ReviewItemSheetState extends State<_ReviewItemSheet> {
  late final _rate = TextEditingController(text: widget.item.rate ?? ''),
      _clientRate = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _rate.dispose();
    _clientRate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: 'اعتماد البند المضاف',
    subtitle: widget.item.description,
    footer: AppSheetActions(
      primaryLabel: 'اعتماد البند',
      onPrimary: () {
        if (_form.currentState!.validate()) {
          Navigator.pop(context, (
            _rate.text,
            widget.canClient && _clientRate.text.trim().isNotEmpty
                ? _clientRate.text
                : null,
          ));
        }
      },
      secondaryLabel: 'إلغاء',
      onSecondary: () => Navigator.pop(context),
    ),
    child: Form(
      key: _form,
      child: Column(
        children: [
          TextFormField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalFormatter],
            decoration: const InputDecoration(labelText: 'سعر المقاول *'),
            validator: _nonNegative,
          ),
          if (widget.canClient) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _clientRate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [_decimalFormatter],
              decoration: InputDecoration(
                labelText: 'سعر العميل',
                hintText: widget.item.rate ?? 'مماثل لسعر المقاول',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? null
                  : _nonNegative(value),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CreateExtractSheet extends StatefulWidget {
  const _CreateExtractSheet({
    required this.repository,
    required this.options,
    required this.initialContractorId,
    required this.initialCenterId,
    required this.canClient,
    this.extract,
  });
  final ExtractRepository repository;
  final ExtractOptions options;
  final String initialContractorId, initialCenterId;
  final bool canClient;
  final ContractorExtract? extract;
  @override
  State<_CreateExtractSheet> createState() => _CreateExtractSheetState();
}

class _CreateExtractSheetState extends State<_CreateExtractSheet> {
  final _form = GlobalKey<FormState>(), _note = TextEditingController();
  late String _contractorId, _centerId;
  late DateTime _date;
  late final List<_DraftLine> _lines;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.extract != null;

  @override
  void initState() {
    super.initState();
    final extract = widget.extract;
    _contractorId = widget.initialContractorId;
    _centerId = widget.initialCenterId;
    _date = extract == null
        ? DateTime.now()
        : DateTime.parse(extract.extractDate);
    _note.text = extract?.note ?? '';
    _lines = extract == null
        ? [_DraftLine()]
        : [for (final item in extract.items) _DraftLine.fromItem(item)];
  }

  @override
  void dispose() {
    _note.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  String get _total {
    var total = ExactDecimal.zero;
    for (final line in _lines) {
      final amount =
          (ExactDecimal.tryParse(line.quantity.text) ?? ExactDecimal.zero) *
          (ExactDecimal.tryParse(line.rate.text) ?? ExactDecimal.zero);
      total = line.kind == 'WORK' ? total + amount : total + -amount;
    }
    return total.money();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final items = [
        for (final line in _lines)
          ExtractLineInput(
            kind: line.kind,
            description: line.description.text,
            unitId: line.unitId,
            quantity: line.quantity.text,
            rate: line.rate.text,
            percentage: line.percentage,
            clientRate:
                widget.canClient && line.clientRate.text.trim().isNotEmpty
                ? line.clientRate.text
                : null,
          ),
      ];
      final changed = _editing
          ? await widget.repository.update(
              extract: widget.extract!,
              extractDate: _date.toIso8601String().substring(0, 10),
              note: _note.text,
              items: items,
            )
          : await widget.repository.create(
              contractorId: _contractorId,
              centerId: _centerId,
              extractDate: _date.toIso8601String().substring(0, 10),
              note: _note.text,
              items: items,
            );
      if (mounted) Navigator.pop(context, _editing ? changed : true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: _editing ? 'تعديل المستخلص' : 'مستخلص جديد',
    subtitle: _editing
        ? 'عدّل البنود والكميات والأسعار مع الحفاظ على نسب الإنجاز'
        : 'يبدأ إنجاز بنود الأعمال من صفر ويُرفع بالحصر',
    closeEnabled: !_saving,
    footer: AppSheetActions(
      primaryLabel: _editing ? 'حفظ التعديلات' : 'حفظ المستخلص',
      busy: _saving,
      onPrimary: _save,
      secondaryLabel: 'إلغاء',
      onSecondary: () => Navigator.pop(context),
    ),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppTokens.danger)),
          AppSelect<String>(
            label: 'المقاول *',
            value: _contractorId.isEmpty ? null : _contractorId,
            options: [
              for (final item in widget.options.contractors)
                AppSelectOption(
                  value: item.id,
                  label: item.name,
                  subtitle: item.code,
                ),
            ],
            validator: (v) => v == null || v.isEmpty ? 'اختر المقاول' : null,
            enabled: !_editing,
            onChanged: (v) => setState(() => _contractorId = v ?? ''),
          ),
          const SizedBox(height: 12),
          AppSelect<String>(
            label: 'مركز التكلفة *',
            value: _centerId.isEmpty ? null : _centerId,
            options: [
              for (final item in widget.options.centers)
                AppSelectOption(
                  value: item.id,
                  label: item.name,
                  subtitle: item.code,
                ),
            ],
            validator: (v) =>
                v == null || v.isEmpty ? 'اختر مركز التكلفة' : null,
            enabled: !_editing,
            onChanged: (v) => setState(() => _centerId = v ?? ''),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final value = await showAppDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (value != null && mounted) setState(() => _date = value);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'تاريخ المستخلص *',
                suffixIcon: Icon(LucideIcons.calendarDays, size: 18),
              ),
              child: Text(_date.toIso8601String().substring(0, 10)),
            ),
          ),
          const SizedBox(height: 16),
          for (final (index, line) in _lines.indexed) ...[
            _DraftLineCard(
              index: index,
              line: line,
              units: widget.options.units,
              canClient: widget.canClient,
              canRemove: _lines.length > 1,
              onChanged: () => setState(() {}),
              onRemove: () => setState(() {
                _lines.removeAt(index).dispose();
              }),
            ),
            const SizedBox(height: 10),
          ],
          AppAddButton(
            label: 'إضافة بند',
            onPressed: () => setState(() => _lines.add(_DraftLine())),
            secondary: true,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'قيمة التعاقد عند تمام الإنجاز',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              AppMoney(_total),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'ملاحظات'),
          ),
        ],
      ),
    ),
  );
}

class _DraftLine {
  _DraftLine();

  _DraftLine.fromItem(ExtractItem item) {
    kind = item.kind;
    unitId = item.unitId;
    percentage = item.percentage;
    description.text = item.description;
    quantity.text = item.quantity;
    rate.text = item.rate ?? '';
    clientRate.text = item.clientRate ?? '';
  }

  String kind = 'WORK', unitId = '';
  String? percentage;
  final description = TextEditingController(),
      quantity = TextEditingController(),
      rate = TextEditingController(),
      clientRate = TextEditingController();
  void dispose() {
    description.dispose();
    quantity.dispose();
    rate.dispose();
    clientRate.dispose();
  }
}

class _DraftLineCard extends StatelessWidget {
  const _DraftLineCard({
    required this.index,
    required this.line,
    required this.units,
    required this.canClient,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });
  final int index;
  final _DraftLine line;
  final List<ReferenceRecord> units;
  final bool canClient, canRemove;
  final VoidCallback onChanged, onRemove;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.tokens.sunken,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.tokens.line),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'البند ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (canRemove)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  LucideIcons.trash2,
                  color: AppTokens.danger,
                  size: 18,
                ),
              ),
          ],
        ),
        AppSelect<String>(
          label: 'النوع *',
          searchable: false,
          value: line.kind,
          options: const [
            AppSelectOption(value: 'WORK', label: 'أعمال'),
            AppSelectOption(value: 'RETURN', label: 'مرتجع'),
            AppSelectOption(value: 'PENALTY', label: 'خصم'),
          ],
          onChanged: (v) {
            line.kind = v ?? 'WORK';
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: line.description,
          decoration: const InputDecoration(labelText: 'بيان الأعمال *'),
          validator: _required,
        ),
        const SizedBox(height: 10),
        AppSelect<String>(
          label: 'الوحدة *',
          value: line.unitId.isEmpty ? null : line.unitId,
          options: [
            for (final unit in units)
              AppSelectOption(
                value: unit.id,
                label: unit.name,
                subtitle: unit.code,
              ),
          ],
          validator: (v) => v == null || v.isEmpty ? 'اختر الوحدة' : null,
          onChanged: (v) {
            line.unitId = v ?? '';
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: line.quantity,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_decimalFormatter],
          decoration: const InputDecoration(labelText: 'الكمية *'),
          validator: _positive,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: line.rate,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_decimalFormatter],
          decoration: InputDecoration(
            labelText: canClient ? 'سعر المقاول *' : 'سعر الوحدة *',
          ),
          validator: _nonNegative,
          onChanged: (_) => onChanged(),
        ),
        if (canClient) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: line.clientRate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_decimalFormatter],
            decoration: InputDecoration(
              labelText: 'سعر العميل',
              hintText: line.kind == 'PENALTY' ? '0' : line.rate.text,
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? null : _nonNegative(v),
          ),
        ],
      ],
    ),
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
}) async =>
    await showAppSheet<bool>(
      context,
      builder: (sheetContext) => AppSheetScaffold(
        title: title,
        footer: AppSheetActions(
          primaryLabel: 'تأكيد الرفض',
          destructive: true,
          onPrimary: () => Navigator.pop(sheetContext, true),
          secondaryLabel: 'إلغاء',
          onSecondary: () => Navigator.pop(sheetContext, false),
        ),
        child: Text(message),
      ),
    ) ??
    false;

int _waitingCount(ContractorExtract extract) => extract.items
    .where(
      (item) => item.status == 'PENDING' || item.pendingMeasurementId != null,
    )
    .length;
String _statusLabel(String status) => switch (status) {
  'APPROVED' => 'معتمد',
  'REJECTED' => 'مرفوض',
  _ => 'بانتظار الاعتماد',
};
AppTag _statusTag(String status) => AppTag(
  _statusLabel(status),
  tone: switch (status) {
    'APPROVED' => AppTone.success,
    'REJECTED' => AppTone.danger,
    _ => AppTone.warning,
  },
);
double _share(String? value) {
  final decimal = ExactDecimal.tryParse(value ?? '0') ?? ExactDecimal.zero;
  final clamped = decimal.compareTo(ExactDecimal.zero) < 0
      ? ExactDecimal.zero
      : decimal.compareTo(ExactDecimal.parse('1')) > 0
      ? ExactDecimal.parse('1')
      : decimal;
  return double.parse(clamped.toString());
}

String _displayPercent(String? share) =>
    ((ExactDecimal.tryParse(share ?? '') ?? ExactDecimal.zero) *
            ExactDecimal.parse('100'))
        .rounded(2)
        .toString()
        .replaceFirst(RegExp(r'\.0+$'), '');
String _pendingAmount(ExtractItem item) =>
    ((ExactDecimal.tryParse(item.quantity) ?? ExactDecimal.zero) *
            (ExactDecimal.tryParse(item.rate ?? '') ?? ExactDecimal.zero) *
            (ExactDecimal.tryParse(item.pendingPercentage ?? '') ??
                ExactDecimal.zero))
        .money();
String _money(String? value) =>
    (ExactDecimal.tryParse(value ?? '') ?? ExactDecimal.zero).money();
String _number(String? value) =>
    (ExactDecimal.tryParse(value ?? '') ?? ExactDecimal.zero).toString();
String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;
String? _positive(String? value) {
  final decimal = ExactDecimal.tryParse(value ?? '');
  return decimal == null || decimal.compareTo(ExactDecimal.zero) <= 0
      ? 'أدخل رقمًا أكبر من صفر'
      : null;
}

String? _nonNegative(String? value) {
  final decimal = ExactDecimal.tryParse(value ?? '');
  return decimal == null || decimal.compareTo(ExactDecimal.zero) < 0
      ? 'أدخل رقمًا صحيحًا'
      : null;
}

final _decimalFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'[0-9٠-٩۰-۹.,٫-]'),
);
