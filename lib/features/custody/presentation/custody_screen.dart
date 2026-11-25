import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/app_buttons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_filter.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_refresh_page.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../data/custody_repository.dart';
import '../domain/custody_models.dart';
import 'custody_ledger.dart';
import 'custody_requests_transfers.dart';
import 'custody_widgets.dart';
import 'expense_form_sheet.dart';

enum CustodyTab { moves, requests, transfers }

/// One employee's custody: balance, the ledger, their own requests and
/// transfers. Items here are read-only; review actions live in the aggregate.
class CustodyScreen extends StatefulWidget {
  const CustodyScreen({
    super.key,
    required this.repository,
    required this.ownerId,
    required this.currentUserId,
    required this.permissions,
    this.initialTab = CustodyTab.moves,
  });
  final CustodyRepository repository;
  final String? ownerId;
  final CustodyTab initialTab;
  final String currentUserId;
  final Set<String> permissions;

  @override
  State<CustodyScreen> createState() => _CustodyScreenState();
}

class _CustodyScreenState extends State<CustodyScreen> {
  late CustodyTab _tab = widget.initialTab;
  CustodyBalance? _balance;
  ExpenseFilters? _filterOptions;
  String? _error;
  bool _loading = true;

  // Movements
  PageData<LedgerItem>? _moves;
  ExpenseFilterState _filters = const ExpenseFilterState();
  int _movesPage = 0;

  // Requests
  PageData<CustodyRequestItem>? _requests;
  bool _unpaidOnly = false;
  int _requestsPage = 0;

  // Transfers
  PageData<CustodyTransferItem>? _transfers;
  bool _pendingOnly = false;
  int _transfersPage = 0;
  int _awaitingReceipt = 0;

  int _pageSize = 20;

  String get _owner => widget.ownerId ?? widget.currentUserId;
  bool get _isOwn => _owner == widget.currentUserId;
  bool get _canAdd =>
      _isOwn && widget.permissions.contains('CUSTODY_EXPENSE_CREATE');
  bool get _canRequest =>
      _isOwn && widget.permissions.contains('CUSTODY_REQUEST_CREATE');
  bool get _canTransfer =>
      _isOwn && widget.permissions.contains('CUSTODY_TRANSFER');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CustodyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) {
      _movesPage = 0;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([
        _loadBalance(),
        _loadMoves(),
        if (_canRequest) _loadRequests(),
        if (_canTransfer) _loadTransfers(),
      ]);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBalance() async {
    final balance = await widget.repository.balance(_owner);
    if (mounted) setState(() => _balance = balance);
  }

  Future<void> _loadMoves() async {
    final results = await Future.wait([
      if (_filterOptions == null)
        widget.repository.expenseFilters(ownerId: _owner),
      widget.repository.ledger(
        ownerId: _owner,
        page: _movesPage,
        size: _pageSize,
        filters: _filters,
      ),
    ]);
    if (!mounted) return;
    setState(() {
      if (results.length > 1) _filterOptions = results.first as ExpenseFilters;
      _moves = results.last as PageData<LedgerItem>;
    });
  }

  Future<void> _loadRequests() async {
    final page = await widget.repository.requests(
      page: _requestsPage,
      size: _pageSize,
      unpaid: _unpaidOnly,
      mine: true,
    );
    if (mounted) setState(() => _requests = page);
  }

  Future<void> _loadTransfers() async {
    final results = await Future.wait([
      widget.repository.transfers(
        page: _transfersPage,
        size: _pageSize,
        pendingOnly: _pendingOnly,
      ),
      widget.repository.transfers(size: 50, pendingOnly: true),
    ]);
    if (!mounted) return;
    setState(() {
      _transfers = results.first;
      _awaitingReceipt = results.last.items
          .where((item) => transferIncoming(item, _owner))
          .length;
    });
  }

  Future<void> _reloadTab() async {
    setState(() => _loading = true);
    try {
      await switch (_tab) {
        CustodyTab.moves => _loadMoves(),
        CustodyTab.requests => _loadRequests(),
        CustodyTab.transfers => _loadTransfers(),
      };
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _addExpense() async {
    final saved = await showExpenseForm(
      context: context,
      repository: widget.repository,
      currentUserId: widget.currentUserId,
      permissions: widget.permissions,
    );
    if (!mounted || !saved) return;
    _notify('تمت إضافة بند العهدة');
    setState(() {
      _tab = CustodyTab.moves;
      _movesPage = 0;
    });
    await Future.wait([_loadBalance(), _loadMoves()]);
  }

  Future<void> _requestCustody() async {
    final sent = await showRequestForm(
      context: context,
      repository: widget.repository,
    );
    if (!mounted || !sent) return;
    _notify('تم إرسال طلب العهدة إلى المدير');
    setState(() {
      _tab = CustodyTab.requests;
      _requestsPage = 0;
    });
    await _loadRequests();
  }

  Future<void> _transfer() async {
    final sent = await showTransferForm(
      context: context,
      repository: widget.repository,
      userId: widget.currentUserId,
    );
    if (!mounted || !sent) return;
    _notify('تم إرسال التحويل؛ سيتغير الرصيد بعد تأكيد الاستلام');
    setState(() {
      _tab = CustodyTab.transfers;
      _transfersPage = 0;
    });
    await Future.wait([_loadBalance(), _loadTransfers()]);
  }

  Future<void> _receive(CustodyTransferItem item) async {
    final received = await confirmReceiveTransfer(
      context,
      widget.repository,
      item,
    );
    if (!mounted || !received) return;
    _notify('تم استلام التحويل وإضافته إلى عهدتك');
    await Future.wait([_loadBalance(), _loadTransfers(), _loadMoves()]);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (CustodyTab.moves, 'الحركات', 0),
      if (_canRequest)
        (
          CustodyTab.requests,
          'الطلبات',
          _requests?.items.where((item) => item.status == 'PENDING').length ??
              0,
        ),
      if (_canTransfer) (CustodyTab.transfers, 'التحويلات', _awaitingReceipt),
    ];
    final balance = _balance;
    return AppRefreshPage(
      onRefresh: _load,
      children: [
        PageHeader(title: 'العهدة', subtitle: _isOwn ? null : 'عرض عهدة موظف'),
        const SizedBox(height: 14),
        if (_error != null && balance == null)
          MessagePanel(message: _error!, onRetry: _load)
        else ...[
          if (balance != null)
            BalanceHero(
              remaining: money(balance.remaining),
              pendingIncoming: money(balance.pendingIncoming),
              pendingOutgoing: money(balance.pendingOutgoing),
            )
          else
            const _BalancePlaceholder(),
          if (_canAdd || _canRequest || _canTransfer) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (_canAdd)
                  Expanded(
                    child: QuickActionTile(
                      label: 'إضافة بند',
                      icon: LucideIcons.plus,
                      primary: true,
                      onTap: _addExpense,
                    ),
                  ),
                if (_canRequest) ...[
                  if (_canAdd) const SizedBox(width: 10),
                  Expanded(
                    child: QuickActionTile(
                      label: 'طلب عهدة',
                      icon: LucideIcons.filePlus2,
                      onTap: _requestCustody,
                    ),
                  ),
                ],
                if (_canTransfer) ...[
                  if (_canAdd || _canRequest) const SizedBox(width: 10),
                  Expanded(
                    child: QuickActionTile(
                      label: 'تحويل',
                      icon: LucideIcons.arrowLeftRight,
                      onTap: _transfer,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 22),
          if (tabs.length > 1) ...[
            LedgerTabs<CustodyTab>(
              value: _tab,
              tabs: tabs,
              onChanged: (tab) => setState(() => _tab = tab),
            ),
            const SizedBox(height: 10),
          ],
          if (_error != null) ...[
            MessagePanel(message: _error!, onRetry: _reloadTab),
            const SizedBox(height: 10),
          ],
          ...switch (_tab) {
            CustodyTab.moves => _movesTab(context),
            CustodyTab.requests => _requestsTab(context),
            CustodyTab.transfers => _transfersTab(context),
          },
        ],
      ],
    );
  }

  // --- Movements -----------------------------------------------------------

  List<Widget> _movesTab(BuildContext context) {
    final options = _filterOptions;
    String? name(List<ExpenseFilterOption>? list, String? id) =>
        list?.where((item) => item.id == id).firstOrNull?.name;
    final summary = [
      ?name(options?.centers, _filters.centerId),
      ?name(options?.categories, _filters.categoryId),
      if (_filters.status != null) _statusLabel(_filters.status!),
      if (_filters.dateFrom != null || _filters.dateTo != null)
        '${_filters.dateFrom == null ? '…' : shortDate(_filters.dateFrom!)} إلى ${_filters.dateTo == null ? '…' : shortDate(_filters.dateTo!)}',
    ].join(' · ');
    final page = _moves;
    return [
      AppFilterBar(
        activeCount: _filters.isActive ? 1 : 0,
        summary: summary,
        onOpen: _openMoveFilters,
        onClear: () {
          setState(() {
            _filters = const ExpenseFilterState();
            _movesPage = 0;
          });
          _reloadTab();
        },
      ),
      const SizedBox(height: 10),
      AppDataTable<LedgerItem>(
        columns: ledgerColumns(aggregate: false),
        rows: page?.items ?? const [],
        loading: _loading,
        rowColor: (item) => ledgerRowColor(item, showSnag: false),
        cells: (item) =>
            ledgerCells(context, item, aggregate: false, viewerId: _owner),
        onTap: (item) => showLedgerDetail(
          context,
          item: item,
          repository: widget.repository,
          viewerId: _owner,
          footer:
              _canTransfer &&
                  item.kind == LedgerKind.transfer &&
                  item.recipientId == _owner &&
                  item.approval != 'تم الاستلام'
              ? AppSheetActions(
                  primaryLabel: 'الاستلام من تبويب التحويلات',
                  primaryIcon: LucideIcons.arrowLeftRight,
                  onPrimary: () {
                    Navigator.pop(context);
                    setState(() => _tab = CustodyTab.transfers);
                  },
                )
              : null,
        ),
        empty: _filters.isActive
            ? AppEmptyState(
                icon: LucideIcons.searchX,
                title: 'لا توجد بنود مطابقة',
                message: 'غيّر الفلاتر أو امسحها لعرض كل الحركات.',
              )
            : AppEmptyState(
                icon: LucideIcons.inbox,
                title: 'لا توجد حركات بعد',
                message: 'أول ما تستلم تمويل أو تسجّل بند صرف، هيظهر هنا.',
                action: _canAdd
                    ? AppAddButton(label: 'إضافة بند', onPressed: _addExpense)
                    : null,
              ),
      ),
      if (page != null) ...[
        const SizedBox(height: 12),
        AppPagination(
          page: _movesPage,
          size: _pageSize,
          total: page.total,
          disabled: _loading,
          onChanged: (index) {
            setState(() => _movesPage = index);
            _reloadTab();
          },
        ),
      ],
    ];
  }

  Future<void> _openMoveFilters() async {
    final options = _filterOptions;
    final result = await showAppFilterSheet<(ExpenseFilterState, int)>(
      context: context,
      subtitle: 'حركات العهدة',
      initial: (_filters, _pageSize),
      empty: (const ExpenseFilterState(), _pageSize),
      isActive: (value) => value.$1.isActive,
      fields: (context, draft, update) {
        final (filters, size) = draft;
        String? blank(String? value) =>
            value == null || value.isEmpty ? null : value;
        return AppFilterGrid(
          children: [
            _filterSelect(
              label: 'المشروع / مركز التكلفة',
              all: 'كل المراكز',
              value: filters.centerId,
              options: options?.centers ?? const [],
              onChanged: (value) => update((
                ExpenseFilterState(
                  centerId: blank(value),
                  categoryId: filters.categoryId,
                  status: filters.status,
                  dateFrom: filters.dateFrom,
                  dateTo: filters.dateTo,
                ),
                size,
              )),
            ),
            _filterSelect(
              label: 'بند الصرف',
              all: 'كل البنود',
              value: filters.categoryId,
              options: options?.categories ?? const [],
              onChanged: (value) => update((
                ExpenseFilterState(
                  centerId: filters.centerId,
                  categoryId: blank(value),
                  status: filters.status,
                  dateFrom: filters.dateFrom,
                  dateTo: filters.dateTo,
                ),
                size,
              )),
            ),
            AppSelect<String>(
              compact: true,
              label: 'حالة البند',
              value: filters.status ?? '',
              options: const [
                AppSelectOption(value: '', label: 'كل الحالات'),
                AppSelectOption(value: 'APPROVED', label: 'معتمد'),
                AppSelectOption(value: 'REJECTED', label: 'مرفوض'),
              ],
              onChanged: (value) => update((
                ExpenseFilterState(
                  centerId: filters.centerId,
                  categoryId: filters.categoryId,
                  status: blank(value),
                  dateFrom: filters.dateFrom,
                  dateTo: filters.dateTo,
                ),
                size,
              )),
            ),
            appPageSizeField(
              value: size,
              onChanged: (value) => update((filters, value)),
            ),
            AppDateFilterField(
              label: 'من تاريخ',
              value: filters.dateFrom,
              onChanged: (value) => update((
                ExpenseFilterState(
                  centerId: filters.centerId,
                  categoryId: filters.categoryId,
                  status: filters.status,
                  dateFrom: value,
                  dateTo: filters.dateTo,
                ),
                size,
              )),
            ),
            AppDateFilterField(
              label: 'إلى تاريخ',
              value: filters.dateTo,
              onChanged: (value) => update((
                ExpenseFilterState(
                  centerId: filters.centerId,
                  categoryId: filters.categoryId,
                  status: filters.status,
                  dateFrom: filters.dateFrom,
                  dateTo: value,
                ),
                size,
              )),
            ),
          ],
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() {
      _filters = result.$1;
      _pageSize = result.$2;
      _movesPage = 0;
    });
    await _reloadTab();
  }

  // --- Requests ------------------------------------------------------------

  List<Widget> _requestsTab(BuildContext context) {
    final page = _requests;
    return [
      AppFilterBar(
        activeCount: _unpaidOnly ? 1 : 0,
        summary: _unpaidOnly ? 'لم تُصرف فقط' : '',
        onOpen: () => _openToggleFilter(
          subtitle: 'طلبات العهدة',
          label: 'الصرف',
          all: 'كل الطلبات',
          only: 'لم تُصرف فقط',
          value: _unpaidOnly,
          apply: (value) {
            _unpaidOnly = value;
            _requestsPage = 0;
          },
        ),
        onClear: () {
          setState(() {
            _unpaidOnly = false;
            _requestsPage = 0;
          });
          _reloadTab();
        },
      ),
      const SizedBox(height: 10),
      AppDataTable<CustodyRequestItem>(
        columns: requestColumns,
        rows: page?.items ?? const [],
        loading: _loading && page == null,
        rowColor: (item) =>
            item.status == 'REJECTED' ? AppTokens.dangerTint : null,
        cells: (item) => requestCells(context, item),
        onTap: (item) => showRequestDetail(context, item),
        empty: AppEmptyState(
          icon: LucideIcons.filePlus2,
          title: _unpaidOnly
              ? 'لا توجد طلبات لم تُصرف'
              : 'لا توجد طلبات حتى الآن',
          message: 'اطلب عهدة جديدة وتابع موافقتها وصرفها من هنا.',
          action: AppAddButton(label: 'طلب عهدة', onPressed: _requestCustody),
        ),
      ),
      if (page != null) ...[
        const SizedBox(height: 12),
        AppPagination(
          page: _requestsPage,
          size: _pageSize,
          total: page.total,
          disabled: _loading,
          onChanged: (index) {
            setState(() => _requestsPage = index);
            _reloadTab();
          },
        ),
      ],
    ];
  }

  // --- Transfers -----------------------------------------------------------

  List<Widget> _transfersTab(BuildContext context) {
    final page = _transfers;
    return [
      AppFilterBar(
        activeCount: _pendingOnly ? 1 : 0,
        summary: _pendingOnly ? 'المعلّقة فقط' : '',
        onOpen: () => _openToggleFilter(
          subtitle: 'تحويلات العهدة',
          label: 'حالة الاستلام',
          all: 'كل التحويلات',
          only: 'المعلّقة فقط',
          value: _pendingOnly,
          apply: (value) {
            _pendingOnly = value;
            _transfersPage = 0;
          },
        ),
        onClear: () {
          setState(() {
            _pendingOnly = false;
            _transfersPage = 0;
          });
          _reloadTab();
        },
      ),
      const SizedBox(height: 10),
      AppDataTable<CustodyTransferItem>(
        columns: transferColumns,
        rows: page?.items ?? const [],
        loading: _loading && page == null,
        cells: (item) =>
            transferCells(context, item, viewerId: _owner, onReceive: _receive),
        onTap: (item) => showTransferDetail(
          context,
          item,
          viewerId: _owner,
          onReceive: () => _receive(item),
        ),
        empty: AppEmptyState(
          icon: LucideIcons.arrowLeftRight,
          title: 'لا توجد تحويلات',
          message: 'حوّل جزءًا من عهدتك لزميل، أو استلم تحويلًا واردًا من هنا.',
          action: FilledButton.icon(
            onPressed: _transfer,
            icon: const Icon(LucideIcons.arrowLeftRight, size: 18),
            label: const Text('تحويل جديد'),
          ),
        ),
      ),
      if (page != null) ...[
        const SizedBox(height: 12),
        AppPagination(
          page: _transfersPage,
          size: _pageSize,
          total: page.total,
          disabled: _loading,
          onChanged: (index) {
            setState(() => _transfersPage = index);
            _reloadTab();
          },
        ),
      ],
    ];
  }

  /// Requests and transfers each have a single server filter plus page size.
  Future<void> _openToggleFilter({
    required String subtitle,
    required String label,
    required String all,
    required String only,
    required bool value,
    required void Function(bool value) apply,
  }) async {
    final result = await showAppFilterSheet<(bool, int)>(
      context: context,
      subtitle: subtitle,
      initial: (value, _pageSize),
      empty: (false, _pageSize),
      isActive: (draft) => draft.$1,
      fields: (context, draft, update) => AppFilterGrid(
        children: [
          AppSelect<bool>(
            compact: true,
            label: label,
            value: draft.$1,
            options: [
              AppSelectOption(value: false, label: all),
              AppSelectOption(value: true, label: only),
            ],
            onChanged: (next) => update((next ?? false, draft.$2)),
          ),
          appPageSizeField(
            value: draft.$2,
            onChanged: (size) => update((draft.$1, size)),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      apply(result.$1);
      _pageSize = result.$2;
    });
    await _reloadTab();
  }
}

Widget _filterSelect({
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
  onChanged: onChanged,
);

String _statusLabel(String status) => switch (status) {
  'APPROVED' => 'معتمد',
  'REJECTED' => 'مرفوض',
  _ => status,
};

class _BalancePlaceholder extends StatelessWidget {
  const _BalancePlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    height: 176,
    decoration: BoxDecoration(
      color: context.tokens.line,
      borderRadius: BorderRadius.circular(24),
    ),
  );
}
