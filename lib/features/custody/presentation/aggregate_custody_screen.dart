import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/app_filter.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_refresh_page.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_table.dart';
import '../data/custody_repository.dart';
import '../domain/custody_models.dart';
import 'custody_ledger.dart';
import 'custody_widgets.dart';
import 'expense_form_sheet.dart';

/// Every employee's custody items in one table. This is where managers act on
/// items: Snag, edit, reject, administrative correction and spending on an
/// employee's behalf.
class AggregateCustodyScreen extends StatefulWidget {
  const AggregateCustodyScreen({
    super.key,
    required this.repository,
    required this.currentUserId,
    required this.permissions,
  });

  final CustodyRepository repository;
  final String currentUserId;
  final Set<String> permissions;

  @override
  State<AggregateCustodyScreen> createState() => _AggregateCustodyScreenState();
}

class _AggregateCustodyScreenState extends State<AggregateCustodyScreen> {
  PageData<LedgerItem>? _page;
  ExpenseFilters? _options;
  ExpenseFilterState _filters = const ExpenseFilterState();
  int _pageIndex = 0;
  int _pageSize = 20;
  bool _loading = true;
  String? _error;

  bool get _canReview => widget.permissions.contains('CUSTODY_EXPENSE_REVIEW');
  bool get _canCorrect => widget.permissions.contains('CUSTODY_CORRECT');
  bool get _canOnBehalf =>
      widget.permissions.contains('CUSTODY_COMPANY_VIEW') &&
      widget.permissions.contains('CUSTODY_EXPENSE_ON_BEHALF');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        if (_options == null) widget.repository.expenseFilters(),
        widget.repository.ledger(
          aggregate: true,
          page: _pageIndex,
          size: _pageSize,
          filters: _filters,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        if (results.length > 1) _options = results.first as ExpenseFilters;
        _page = results.last as PageData<LedgerItem>;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _spendOnBehalf() async {
    final saved = await showExpenseForm(
      context: context,
      repository: widget.repository,
      currentUserId: widget.currentUserId,
      permissions: widget.permissions,
      onBehalf: true,
    );
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم صرف البند على عهدة الموظف')),
    );
    setState(() => _pageIndex = 0);
    await _load();
  }

  String _summary() {
    final options = _options;
    String? name(List<ExpenseFilterOption>? list, String? id) =>
        list?.where((item) => item.id == id).firstOrNull?.name;
    final f = _filters;
    return [
      ?name(options?.people, f.ownerId),
      ?name(options?.centers, f.centerId),
      ?name(options?.categories, f.categoryId),
      ?name(options?.contractors, f.contractorId),
      if (f.status == 'APPROVED') 'معتمد',
      if (f.status == 'REJECTED') 'مرفوض',
      if (f.settled == true) 'مُصفّى',
      if (f.settled == false) 'غير مُصفّى',
      if (f.isSnag == true) 'Snag',
      if (f.isSnag == false) 'بدون Snag',
      if (f.dateFrom != null || f.dateTo != null)
        '${f.dateFrom == null ? '…' : shortDate(f.dateFrom!)} إلى ${f.dateTo == null ? '…' : shortDate(f.dateTo!)}',
    ].join(' · ');
  }

  Future<void> _openFilters() async {
    final options = _options;
    final result = await showAppFilterSheet<(ExpenseFilterState, int)>(
      context: context,
      subtitle: 'كل بنود عهد الموظفين',
      initial: (_filters, _pageSize),
      empty: (const ExpenseFilterState(), _pageSize),
      isActive: (value) => value.$1.isActive,
      fields: (context, draft, update) {
        final (f, size) = draft;
        void set(_Changes changes) => update((changes.apply(f), size));
        return AppFilterGrid(
          children: [
            _referenceSelect(
              label: 'الموظف',
              all: 'كل الموظفين',
              value: f.ownerId,
              options: options?.people ?? const [],
              onChanged: (value) => set(_Changes(ownerId: () => value)),
            ),
            _referenceSelect(
              label: 'المشروع / مركز التكلفة',
              all: 'كل المراكز',
              value: f.centerId,
              options: options?.centers ?? const [],
              onChanged: (value) => set(_Changes(centerId: () => value)),
            ),
            _referenceSelect(
              label: 'بند الصرف',
              all: 'كل البنود',
              value: f.categoryId,
              options: options?.categories ?? const [],
              onChanged: (value) => set(_Changes(categoryId: () => value)),
            ),
            _choiceSelect(
              label: 'حالة البند',
              all: 'كل الحالات',
              value: f.status,
              options: const [('APPROVED', 'معتمد'), ('REJECTED', 'مرفوض')],
              onChanged: (value) => set(_Changes(status: () => value)),
            ),
            _referenceSelect(
              label: 'المقاول',
              all: 'كل المقاولين',
              value: f.contractorId,
              options: options?.contractors ?? const [],
              onChanged: (value) => set(_Changes(contractorId: () => value)),
            ),
            _choiceSelect(
              label: 'التصفية',
              all: 'الكل',
              value: f.settled?.toString(),
              options: const [('true', 'مُصفّى'), ('false', 'غير مُصفّى')],
              onChanged: (value) => set(
                _Changes(settled: () => value == null ? null : value == 'true'),
              ),
            ),
            if (_canReview)
              _choiceSelect(
                label: 'علامة Snag',
                all: 'الكل',
                value: f.isSnag?.toString(),
                options: const [
                  ('true', 'معلّم بـ Snag'),
                  ('false', 'غير معلّم'),
                ],
                onChanged: (value) => set(
                  _Changes(
                    isSnag: () => value == null ? null : value == 'true',
                  ),
                ),
              ),
            appPageSizeField(
              value: size,
              onChanged: (value) => update((f, value)),
            ),
            AppDateFilterField(
              label: 'من تاريخ',
              value: f.dateFrom,
              onChanged: (value) => set(_Changes(dateFrom: () => value)),
            ),
            AppDateFilterField(
              label: 'إلى تاريخ',
              value: f.dateTo,
              onChanged: (value) => set(_Changes(dateTo: () => value)),
            ),
          ],
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() {
      _filters = result.$1;
      _pageSize = result.$2;
      _pageIndex = 0;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final actions = LedgerReviewActions(
      canReview: _canReview,
      canCorrect: _canCorrect,
      categories: _options?.categories ?? const [],
    );
    return AppRefreshPage(
      onRefresh: _load,
      children: [
        PageHeader(
          title: 'مجمع العهد',
          action: _canOnBehalf
              ? FilledButton.icon(
                  onPressed: _spendOnBehalf,
                  icon: const Icon(LucideIcons.userPlus, size: 18),
                  label: const Text('صرف باسم موظف'),
                )
              : null,
        ),
        const SizedBox(height: 14),
        AppFilterBar(
          activeCount: _filters.isActive ? 1 : 0,
          summary: _summary(),
          onOpen: _openFilters,
          onClear: () {
            setState(() {
              _filters = const ExpenseFilterState();
              _pageIndex = 0;
            });
            _load();
          },
        ),
        const SizedBox(height: 10),
        if (_error != null) ...[
          MessagePanel(message: _error!, onRetry: _load),
          const SizedBox(height: 10),
        ],
        AppDataTable<LedgerItem>(
          columns: ledgerColumns(aggregate: true),
          rows: page?.items ?? const [],
          loading: _loading,
          rowColor: (item) => ledgerRowColor(item, showSnag: _canReview),
          cells: (item) => ledgerCells(context, item, aggregate: true),
          onTap: (item) => showLedgerDetail(
            context,
            item: item,
            repository: widget.repository,
            actions: actions,
            onChanged: _load,
          ),
          empty: AppEmptyState(
            icon: _filters.isActive ? LucideIcons.searchX : LucideIcons.inbox,
            title: _filters.isActive
                ? 'لا توجد بنود مطابقة'
                : 'لا توجد بنود بعد',
            message: _filters.isActive
                ? 'غيّر الفلاتر أو امسحها لعرض كل البنود.'
                : null,
          ),
        ),
        if (page != null) ...[
          const SizedBox(height: 12),
          AppPagination(
            page: _pageIndex,
            size: _pageSize,
            total: page.total,
            disabled: _loading,
            onChanged: (index) {
              setState(() => _pageIndex = index);
              _load();
            },
          ),
        ],
      ],
    );
  }
}

/// A filter change; each field is a thunk so «clear this one» can be told
/// apart from «leave it as it is».
class _Changes {
  const _Changes({
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

  final String? Function()? ownerId;
  final String? Function()? centerId;
  final String? Function()? categoryId;
  final String? Function()? status;
  final String? Function()? contractorId;
  final bool? Function()? settled;
  final bool? Function()? isSnag;
  final String? Function()? dateFrom;
  final String? Function()? dateTo;

  ExpenseFilterState apply(ExpenseFilterState f) => ExpenseFilterState(
    ownerId: ownerId == null ? f.ownerId : ownerId!(),
    centerId: centerId == null ? f.centerId : centerId!(),
    categoryId: categoryId == null ? f.categoryId : categoryId!(),
    status: status == null ? f.status : status!(),
    contractorId: contractorId == null ? f.contractorId : contractorId!(),
    settled: settled == null ? f.settled : settled!(),
    isSnag: isSnag == null ? f.isSnag : isSnag!(),
    dateFrom: dateFrom == null ? f.dateFrom : dateFrom!(),
    dateTo: dateTo == null ? f.dateTo : dateTo!(),
  );
}

Widget _referenceSelect({
  required String label,
  required String all,
  required String? value,
  required List<ExpenseFilterOption> options,
  required ValueChanged<String?> onChanged,
}) => AppSelect<String>(
  compact: true,
  label: label,
  value: value ?? '',
  options: [
    AppSelectOption(value: '', label: all),
    for (final option in options)
      AppSelectOption(value: option.id, label: option.label),
  ],
  onChanged: (value) =>
      onChanged(value == null || value.isEmpty ? null : value),
);

Widget _choiceSelect({
  required String label,
  required String all,
  required String? value,
  required List<(String, String)> options,
  required ValueChanged<String?> onChanged,
}) => AppSelect<String>(
  compact: true,
  label: label,
  value: value ?? '',
  options: [
    AppSelectOption(value: '', label: all),
    for (final (id, name) in options) AppSelectOption(value: id, label: name),
  ],
  onChanged: (value) =>
      onChanged(value == null || value.isEmpty ? null : value),
);
