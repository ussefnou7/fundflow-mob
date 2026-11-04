import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
  String _contractorId = '';
  String _centerId = '';
  String _status = '';
  String? _expandedId;
  int _page = 0;
  int _pageSize = 10;
  bool _loading = true;
  String? _error;

  bool get _canCreate =>
      widget.permissions.contains('CONTRACTOR_EXTRACT_CREATE');
  bool get _canApprove =>
      widget.permissions.contains('CONTRACTOR_EXTRACT_APPROVE');

  List<ContractorExtract> get _filtered {
    final query = normalizeArabic(_search.text);
    return _extracts
        .where((extract) {
          if (_status.isNotEmpty && extract.status != _status) return false;
          if (query.isEmpty) return true;
          return normalizeArabic(extract.contractorName).contains(query) ||
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
      final options = await widget.repository.options();
      final extracts = await widget.repository.list();
      if (!mounted) return;
      setState(() {
        _options = options;
        _extracts = extracts;
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
      final extracts = await widget.repository.list(
        contractorId: _contractorId,
        centerId: _centerId,
      );
      if (!mounted) return;
      setState(() {
        _extracts = extracts;
        final lastPage = _filtered.isEmpty
            ? 0
            : ((_filtered.length - 1) / _pageSize).floor();
        if (_page > lastPage) _page = lastPage;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _create() async {
    final options = _options;
    if (options == null) return;
    final saved = await showAppSheet<bool>(
      context,
      tall: true,
      dismissible: false,
      builder: (context) => _CreateExtractSheet(
        repository: widget.repository,
        options: options,
        initialContractorId: _contractorId,
        initialCenterId: _centerId,
      ),
    );
    if (saved == true && mounted) {
      _notify('تم إرسال المستخلص للتسعير');
      await _refresh();
    }
  }

  Future<void> _price(ContractorExtract extract) async {
    final saved = await showAppSheet<bool>(
      context,
      tall: true,
      dismissible: false,
      builder: (context) =>
          _PriceExtractSheet(repository: widget.repository, extract: extract),
    );
    if (saved == true && mounted) {
      _notify('تم تسعير واعتماد المستخلص');
      await _refresh();
    }
  }

  Future<void> _reject(ContractorExtract extract) async {
    final reason = await showAppSheet<String>(
      context,
      builder: (context) => _RejectSheet(extract: extract),
    );
    if (reason == null || !mounted) return;
    try {
      await widget.repository.reject(extract: extract, reason: reason);
      if (!mounted) return;
      _notify('تم رفض المستخلص');
      await _refresh();
    } catch (error) {
      if (mounted) _notify(error.toString());
    }
  }

  String get _summary {
    final options = _options;
    String? name(List<ReferenceRecord>? list, String id) => id.isEmpty
        ? null
        : list?.where((item) => item.id == id).firstOrNull?.name;
    return [
      ?name(options?.centers, _centerId),
      ?name(options?.contractors, _contractorId),
      if (_status.isNotEmpty) _statusLabel(_status),
    ].join(' · ');
  }

  Future<void> _openFilters() async {
    final options = _options;
    final result = await showAppFilterSheet<(String, String, String, int)>(
      context: context,
      subtitle: 'المستخلصات',
      initial: (_centerId, _contractorId, _status, _pageSize),
      empty: ('', '', '', _pageSize),
      isActive: (draft) =>
          draft.$1.isNotEmpty || draft.$2.isNotEmpty || draft.$3.isNotEmpty,
      fields: (context, draft, update) {
        final (center, contractor, status, size) = draft;
        return AppFilterGrid(
          children: [
            _referenceFilter(
              label: 'مركز التكلفة',
              all: 'كل مراكز التكلفة',
              value: center,
              items: options?.centers ?? const [],
              onChanged: (value) => update((value, contractor, status, size)),
            ),
            _referenceFilter(
              label: 'المقاول',
              all: 'كل المقاولين',
              value: contractor,
              items: options?.contractors ?? const [],
              onChanged: (value) => update((center, value, status, size)),
            ),
            AppSelect<String>(
              compact: true,
              label: 'الحالة',
              value: status,
              options: const [
                AppSelectOption(value: '', label: 'كل الحالات'),
                AppSelectOption(
                  value: 'PENDING',
                  label: 'بانتظار التسعير والاعتماد',
                ),
                AppSelectOption(value: 'APPROVED', label: 'معتمد'),
                AppSelectOption(value: 'REJECTED', label: 'مرفوض'),
              ],
              onChanged: (value) =>
                  update((center, contractor, value ?? '', size)),
            ),
            appPageSizeField(
              value: size,
              onChanged: (value) => update((center, contractor, status, value)),
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
      _status = result.$3;
      _pageSize = result.$4;
      _page = 0;
    });
    if (reload) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
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
            title: _canApprove ? 'مستخلصات المقاولين' : 'مستخلصاتي',
            subtitle: '${_extracts.length} مستخلص',
            action: _canCreate
                ? FilledButton.icon(
                    onPressed: _options == null ? null : _create,
                    icon: const Icon(LucideIcons.plus, size: 17),
                    label: const Text('مستخلص جديد'),
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
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
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
                _status = '';
                _page = 0;
              });
              if (reload) _refresh();
            },
          ),
          if (_loading && _extracts.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: 12),
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _initialize)
          else if (_loading && _extracts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visible.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tokens.line),
              ),
              child: const AppEmptyState(
                icon: LucideIcons.fileSpreadsheet,
                title: 'لا توجد مستخلصات مطابقة للفلاتر',
              ),
            )
          else ...[
            for (final extract in visible) ...[
              RepaintBoundary(
                child: ContractorExtractCard(
                  extract: extract,
                  expanded: _expandedId == extract.id,
                  showFinancials: _canApprove,
                  canReview: _canApprove,
                  onToggle: () => setState(
                    () => _expandedId = _expandedId == extract.id
                        ? null
                        : extract.id,
                  ),
                  onPrice: () => _price(extract),
                  onReject: () => _reject(extract),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 2),
            AppPagination(
              page: _page,
              size: _pageSize,
              total: filtered.length,
              disabled: _loading,
              onChanged: (page) => setState(() => _page = page),
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
  onChanged: (value) => onChanged(value ?? ''),
);

class ContractorExtractCard extends StatelessWidget {
  const ContractorExtractCard({
    super.key,
    required this.extract,
    required this.expanded,
    required this.showFinancials,
    this.canReview = false,
    required this.onToggle,
    required this.onPrice,
    required this.onReject,
  });

  final ContractorExtract extract;
  final bool expanded;
  final bool showFinancials;
  final bool canReview;
  final VoidCallback onToggle;
  final VoidCallback onPrice;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final approved = extract.status == 'APPROVED';
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: extract.status == 'REJECTED'
              ? AppTokens.danger.withValues(alpha: .25)
              : expanded
              ? tokens.brand.withValues(alpha: .45)
              : tokens.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          size: 19,
                          color: tokens.brandStrong,
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
                                fontSize: 14.5,
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
                        turns: expanded ? .5 : 0,
                        duration: AppMotion.duration(
                          context,
                          AppMotion.feedback,
                        ),
                        child: Icon(
                          LucideIcons.chevronDown,
                          size: 19,
                          color: tokens.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _statusTag(extract.status),
                      AppTag(
                        shortDate(extract.extractDate),
                        icon: LucideIcons.calendarDays,
                      ),
                      if (extract.assignmentId != null)
                        const AppTag(
                          'إسناد شركة شقيقة',
                          tone: AppTone.info,
                          icon: LucideIcons.building2,
                        ),
                    ],
                  ),
                  if (showFinancials) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: tokens.sunken,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tokens.line),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: _Amount(
                                label: 'المستحق',
                                value: approved ? _money(extract.net) : '—',
                              ),
                            ),
                            VerticalDivider(width: 1, color: tokens.line),
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
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              decoration: BoxDecoration(
                color: tokens.sunken,
                border: Border(top: BorderSide(color: tokens.line)),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ExtractItemsTable(
                    items: extract.items,
                    showFinancials: showFinancials,
                    approved: approved,
                  ),
                  if (extract.note != null && extract.note!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'ملاحظات: ${extract.note}',
                      style: const TextStyle(fontSize: 13, height: 1.7),
                    ),
                  ],
                  if (extract.rejectionReason != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTokens.dangerTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'سبب الرفض: ${extract.rejectionReason}',
                        style: const TextStyle(
                          color: Color(0xFF7A1A12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (canReview && !approved) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (extract.status != 'REJECTED') ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: onReject,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTokens.danger,
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                  color: AppTokens.danger.withValues(alpha: .4),
                                ),
                                minimumSize: const Size.fromHeight(44),
                              ),
                              icon: const Icon(LucideIcons.x, size: 17),
                              label: const Text('رفض'),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: onPrice,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                            ),
                            icon: const Icon(LucideIcons.calculator, size: 17),
                            label: const Text('تسعير واعتماد'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ExtractItemsTable extends StatelessWidget {
  const _ExtractItemsTable({
    required this.items,
    required this.showFinancials,
    required this.approved,
  });

  final List<ExtractItem> items;
  final bool showFinancials;
  final bool approved;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.line),
      ),
      child: Table(
        columnWidths: {
          0: const FlexColumnWidth(2.35),
          1: const FlexColumnWidth(.95),
          2: const FlexColumnWidth(.95),
          if (showFinancials) 3: const FlexColumnWidth(1.1),
          if (showFinancials) 4: const FlexColumnWidth(1.15),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(horizontalInside: BorderSide(color: tokens.line)),
        children: [
          TableRow(
            decoration: BoxDecoration(color: tokens.sunken),
            children: [
              const _ExtractTableCell('البند', header: true),
              const _ExtractTableCell('الكمية', header: true),
              const _ExtractTableCell('الوحدة', header: true),
              if (showFinancials)
                const _ExtractTableCell('سعر الوحدة', header: true),
              if (showFinancials)
                const _ExtractTableCell('الإجمالي', header: true),
            ],
          ),
          for (final item in items)
            TableRow(
              decoration: BoxDecoration(
                color: item.kind == 'RETURN'
                    ? AppTokens.dangerTint.withValues(alpha: .5)
                    : Colors.white,
              ),
              children: [
                _ExtractDescriptionCell(item: item),
                _ExtractTableCell(_number(item.quantity), numeric: true),
                _ExtractTableCell(item.unitName),
                if (showFinancials)
                  _ExtractTableCell(
                    approved ? _money(item.rate) : '—',
                    numeric: true,
                    emphasized: approved,
                  ),
                if (showFinancials)
                  _ExtractTableCell(
                    approved ? _money(item.amount) : '—',
                    numeric: true,
                    emphasized: approved,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ExtractDescriptionCell extends StatelessWidget {
  const _ExtractDescriptionCell({required this.item});

  final ExtractItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.tokens.washStrong,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${item.lineNo}',
            style: TextStyle(
              color: context.tokens.brandStrong,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              if (item.kind == 'RETURN') ...[
                const SizedBox(height: 3),
                const AppTag('خصم', tone: AppTone.danger),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _ExtractTableCell extends StatelessWidget {
  const _ExtractTableCell(
    this.value, {
    this.header = false,
    this.numeric = false,
    this.emphasized = false,
  });

  final String value;
  final bool header;
  final bool numeric;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 4, vertical: header ? 9 : 10),
    child: Text(
      value,
      maxLines: header ? 2 : 3,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      textDirection: numeric ? TextDirection.ltr : null,
      style: TextStyle(
        color: header
            ? context.tokens.muted
            : emphasized
            ? context.tokens.brandStrong
            : context.tokens.ink,
        fontSize: header ? 10.5 : 11.5,
        fontWeight: header || emphasized ? FontWeight.w700 : FontWeight.w600,
        height: 1.3,
        fontFeatures: numeric ? const [FontFeature.tabularFigures()] : null,
      ),
    ),
  );
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value});
  final String label;
  final String value;
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

String _statusLabel(String status) => switch (status) {
  'APPROVED' => 'معتمد',
  'REJECTED' => 'مرفوض',
  _ => 'بانتظار التسعير والاعتماد',
};

AppTag _statusTag(String status) => switch (status) {
  'APPROVED' => const AppTag(
    'معتمد',
    tone: AppTone.success,
    icon: LucideIcons.check,
  ),
  'REJECTED' => const AppTag(
    'مرفوض',
    tone: AppTone.danger,
    icon: LucideIcons.x,
  ),
  _ => const AppTag(
    'بانتظار التسعير والاعتماد',
    tone: AppTone.warning,
    icon: LucideIcons.clock,
  ),
};

class _RejectSheet extends StatefulWidget {
  const _RejectSheet({required this.extract});
  final ContractorExtract extract;

  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();

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
      primaryIcon: LucideIcons.x,
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
        autofocus: true,
        textAlign: TextAlign.right,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'سبب الرفض *',
          alignLabelWithHint: true,
        ),
        validator: _required,
      ),
    ),
  );
}

/// The old one-field select used by the create sheet, now on the shared AppSelect.
class _ExtractSelect extends StatelessWidget {
  const _ExtractSelect({
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Map<String, String> choices;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = choices.containsKey(value) ? value : choices.keys.first;
    return AppSelect<String>(
      label: label,
      value: selected,
      options: [
        for (final entry in choices.entries)
          AppSelectOption(value: entry.key, label: entry.value),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _CreateExtractSheet extends StatefulWidget {
  const _CreateExtractSheet({
    required this.repository,
    required this.options,
    required this.initialContractorId,
    required this.initialCenterId,
  });

  final ExtractRepository repository;
  final ExtractOptions options;
  final String initialContractorId;
  final String initialCenterId;

  @override
  State<_CreateExtractSheet> createState() => _CreateExtractSheetState();
}

class _CreateExtractSheetState extends State<_CreateExtractSheet> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  late String _contractorId;
  late String _centerId;
  late DateTime _date;
  final List<_DraftLine> _lines = [_DraftLine()];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contractorId = widget.initialContractorId;
    _centerId = widget.initialCenterId;
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _note.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showAppDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_contractorId.isEmpty || _centerId.isEmpty) {
      setState(() => _error = 'اختر المقاول ومركز التكلفة');
      return;
    }
    if (_lines.any((line) => line.unitId.isEmpty)) {
      setState(() => _error = 'اختر وحدة القياس لكل بند');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.create(
        contractorId: _contractorId,
        centerId: _centerId,
        extractDate: _isoDate(_date),
        note: _note.text,
        items: _lines
            .map(
              (line) => QuantityLineInput(
                kind: line.kind,
                description: line.description.text,
                unitId: line.unitId,
                quantity: line.quantity.text,
              ),
            )
            .toList(),
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
    return AppSheetScaffold(
      title: 'مستخلص جديد',
      subtitle: 'الكميات ووحدات القياس فقط',
      closeEnabled: !_saving,
      onClose: () => Navigator.pop(context, false),
      footer: AppSheetActions(
        primaryLabel: 'حفظ وإرسال للتسعير',
        primaryIcon: LucideIcons.send,
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
            Text(
              'سجّل الكميات ووحدات القياس فقط — التسعير والاعتماد للمدير',
              style: TextStyle(color: context.tokens.muted, fontSize: 12.5),
            ),
            const SizedBox(height: AppSpace.md),
            if (_error != null) ...[
              MessagePanel(message: _error!),
              const SizedBox(height: AppSpace.sm),
            ],
            _ExtractSelect(
              label: 'المقاول *',
              value: _contractorId,
              choices: {
                '': 'اختر المقاول',
                for (final item in widget.options.contractors)
                  item.id: '${item.code} — ${item.name}',
              },
              onChanged: (value) => setState(() => _contractorId = value),
            ),
            const SizedBox(height: AppSpace.sm),
            _ExtractSelect(
              label: 'مركز التكلفة *',
              value: _centerId,
              choices: {
                '': 'اختر مركز التكلفة',
                for (final item in widget.options.centers)
                  item.id: '${item.code} — ${item.name}',
              },
              onChanged: (value) => setState(() => _centerId = value),
            ),
            const SizedBox(height: AppSpace.sm),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تاريخ المستخلص *',
                  suffixIcon: Icon(LucideIcons.calendarDays, size: 18),
                ),
                child: Text(shortDate(_isoDate(_date))),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            TextFormField(
              controller: _note,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
            const SizedBox(height: AppSpace.md),
            for (var index = 0; index < _lines.length; index++) ...[
              _DraftLineCard(
                index: index,
                line: _lines[index],
                units: widget.options.units,
                canDelete: _lines.length > 1,
                onChanged: () => setState(() {}),
                onDelete: () {
                  final removed = _lines.removeAt(index);
                  removed.dispose();
                  setState(() {});
                },
              ),
              const SizedBox(height: AppSpace.sm),
            ],
            OutlinedButton.icon(
              onPressed: () => setState(() => _lines.add(_DraftLine())),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
              icon: const Icon(LucideIcons.plus, size: 17),
              label: const Text('إضافة بند'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftLineCard extends StatelessWidget {
  const _DraftLineCard({
    required this.index,
    required this.line,
    required this.units,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final _DraftLine line;
  final List<ReferenceRecord> units;
  final bool canDelete;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tokens.sunken,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.tokens.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'بند ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (canDelete)
                  IconButton(
                    tooltip: 'حذف البند',
                    onPressed: onDelete,
                    color: AppTokens.danger,
                    icon: const Icon(LucideIcons.trash2, size: 18),
                  ),
              ],
            ),
            AppSegmented<String>(
              value: line.kind,
              options: const [
                ('WORK', 'أعمال', LucideIcons.hammer),
                ('RETURN', 'مرتجع / خصم', LucideIcons.undo2),
              ],
              onChanged: (value) {
                line.kind = value;
                onChanged();
              },
            ),
            const SizedBox(height: AppSpace.sm),
            TextFormField(
              controller: line.description,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(labelText: 'بيان الأعمال *'),
              validator: _required,
            ),
            const SizedBox(height: AppSpace.sm),
            _ExtractSelect(
              label: 'وحدة القياس *',
              value: line.unitId,
              choices: {
                '': 'اختر الوحدة',
                for (final unit in units) unit.id: unit.name,
              },
              onChanged: (value) {
                line.unitId = value;
                onChanged();
              },
            ),
            const SizedBox(height: AppSpace.sm),
            TextFormField(
              controller: line.quantity,
              textDirection: TextDirection.ltr,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'الكمية *'),
              validator: _nonNegativeNumber,
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftLine {
  String kind = 'WORK';
  String unitId = '';
  final description = TextEditingController();
  final quantity = TextEditingController();

  void dispose() {
    description.dispose();
    quantity.dispose();
  }
}

class _PriceExtractSheet extends StatefulWidget {
  const _PriceExtractSheet({required this.repository, required this.extract});

  final ExtractRepository repository;
  final ContractorExtract extract;

  @override
  State<_PriceExtractSheet> createState() => _PriceExtractSheetState();
}

class _PriceExtractSheetState extends State<_PriceExtractSheet> {
  final _formKey = GlobalKey<FormState>();
  late final List<_PriceLine> _prices;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prices = widget.extract.items.map(_PriceLine.new).toList();
    for (final line in _prices) {
      line.rate.addListener(_recalculate);
      line.percentage.addListener(_recalculate);
    }
  }

  void _recalculate() {
    if (mounted) setState(() {});
  }

  String get _total {
    var total = ExactDecimal.zero;
    for (final line in _prices) {
      final quantity =
          ExactDecimal.tryParse(line.item.quantity) ?? ExactDecimal.zero;
      final rate = ExactDecimal.tryParse(line.rate.text) ?? ExactDecimal.zero;
      final percentage =
          (ExactDecimal.tryParse(line.percentage.text) ?? ExactDecimal.zero)
              .percent;
      final amount = (quantity * rate * percentage).rounded(2);
      total = total + (line.item.kind == 'RETURN' ? -amount : amount);
    }
    return total.rounded(2).toString();
  }

  @override
  void dispose() {
    for (final line in _prices) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.priceAndApprove(
        extract: widget.extract,
        items: _prices
            .map(
              (line) => PriceLineInput(
                itemId: line.item.id,
                rate: line.rate.text,
                percentage: line.percentage.text,
              ),
            )
            .toList(),
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
    return AppSheetScaffold(
      title: 'تسعير واعتماد المستخلص',
      subtitle:
          '${widget.extract.centerName} — ${widget.extract.contractorName} — مستخلص ${widget.extract.extractNo}',
      closeEnabled: !_saving,
      onClose: () => Navigator.pop(context, false),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'صافي المستحق',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              AppMoney(_money(_total), size: 18),
            ],
          ),
          const SizedBox(height: 10),
          AppSheetActions(
            primaryLabel: 'اعتماد المستخلص',
            busy: _saving,
            busyLabel: 'جارٍ الاعتماد…',
            onPrimary: _save,
            secondaryLabel: 'إلغاء',
            onSecondary: () => Navigator.pop(context, false),
          ),
        ],
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
            for (final line in _prices) ...[
              Container(
                decoration: BoxDecoration(
                  color: line.item.kind == 'RETURN'
                      ? AppTokens.dangerTint.withValues(alpha: .5)
                      : context.tokens.sunken,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.tokens.line),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${line.item.lineNo}. ${line.item.description}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${_number(line.item.quantity)} ${line.item.unitName}',
                        style: TextStyle(color: context.tokens.muted),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      TextFormField(
                        controller: line.rate,
                        textDirection: TextDirection.ltr,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'الفئة *'),
                        validator: _nonNegativeNumber,
                      ),
                      const SizedBox(height: AppSpace.sm),
                      TextFormField(
                        controller: line.percentage,
                        textDirection: TextDirection.ltr,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'النسبة %',
                        ),
                        validator: _percentage,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriceLine {
  _PriceLine(this.item)
    : rate = TextEditingController(text: item.rate ?? ''),
      percentage = TextEditingController(
        text: item.percentage == null
            ? '100'
            : ((ExactDecimal.tryParse(item.percentage!) ??
                          ExactDecimal.parse('1')) *
                      ExactDecimal.parse('100'))
                  .toString(),
      );

  final ExtractItem item;
  final TextEditingController rate;
  final TextEditingController percentage;

  void dispose() {
    rate.dispose();
    percentage.dispose();
  }
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;

String? _nonNegativeNumber(String? value) {
  final number = ExactDecimal.tryParse(value ?? '');
  if (number == null || number.units.isNegative) {
    return 'أدخل رقمًا صحيحًا لا يقل عن صفر';
  }
  return null;
}

String? _percentage(String? value) {
  final number = ExactDecimal.tryParse(value ?? '');
  if (number == null ||
      number.units.isNegative ||
      number.compareTo(ExactDecimal.parse('100')) > 0) {
    return 'النسبة من 0 إلى 100';
  }
  return null;
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _number(String? value) {
  final fixed = (ExactDecimal.tryParse(value ?? '') ?? ExactDecimal.zero)
      .rounded(2)
      .toString();
  return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
}

String _money(String? value) =>
    (ExactDecimal.tryParse(value ?? '') ?? ExactDecimal.zero).money();
