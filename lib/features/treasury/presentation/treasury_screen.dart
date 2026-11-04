import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/media/invoice_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_filter.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/data/custody_repository.dart';
import '../../custody/domain/custody_models.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/treasury_repository.dart';
import '../domain/treasury_models.dart';

enum _TreasuryTab { movements, ledger, loans, contributions }

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({
    super.key,
    required this.repository,
    required this.custody,
    required this.permissions,
  });
  final TreasuryRepository repository;
  final CustodyRepository custody;
  final Set<String> permissions;

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  List<TreasuryAccount> _treasuries = const [];
  TreasuryMovementPage? _movements;
  TreasuryLedgerPage? _ledger;
  TreasuryLedgerSummary? _ledgerSummary;
  IntercompanyLoanPage? _loans;
  IntercompanyTransferPage? _contributions;
  IntercompanyOptions? _intercompanyOptions;
  ExpenseOptions? _custodyOptions;
  DirectExpenseOptions? _expenseOptions;
  _TreasuryTab _tab = _TreasuryTab.movements;
  String? _treasuryId;
  String _status = '';
  String _direction = '';
  int _page = 0;
  int _pageSize = 20;
  bool _loading = true;
  bool _quickActionsOpen = false;
  String? _error;

  bool get _canOperate => widget.permissions.contains('TREASURY_OPERATE');
  bool get _canApprove => widget.permissions.contains('TREASURY_APPROVE');
  bool get _canViewIntercompany =>
      widget.permissions.contains('INTERCOMPANY_VIEW');
  TreasuryAccount? get _selected =>
      _treasuries.where((item) => item.id == _treasuryId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.repository.list(),
        widget.custody.expenseOptions(),
        widget.repository.expenseOptions(),
        if (_canViewIntercompany) widget.repository.intercompanyOptions(),
      ]);
      if (!mounted) return;
      final treasuries = results[0] as List<TreasuryAccount>;
      setState(() {
        _treasuries = treasuries;
        _custodyOptions = results[1] as ExpenseOptions;
        _expenseOptions = results[2] as DirectExpenseOptions;
        _intercompanyOptions = _canViewIntercompany
            ? results[3] as IntercompanyOptions
            : null;
        _treasuryId ??=
            treasuries.where((item) => item.defaultTreasury).firstOrNull?.id ??
            treasuries.firstOrNull?.id;
      });
      await _loadActive(showLoader: false);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadActive({bool showLoader = true}) async {
    final id = _treasuryId;
    if (id == null) return;
    setState(() {
      if (showLoader) _loading = true;
      _error = null;
    });
    try {
      switch (_tab) {
        case _TreasuryTab.movements:
          final value = await widget.repository.movements(
            treasuryId: id,
            status: _status,
            page: _page,
            size: _pageSize,
          );
          if (mounted) setState(() => _movements = value);
        case _TreasuryTab.ledger:
          final values = await Future.wait([
            widget.repository.ledger(
              treasuryId: id,
              direction: _direction,
              page: _page,
              size: _pageSize,
            ),
            widget.repository.ledgerSummary(treasuryId: id),
          ]);
          if (mounted) {
            setState(() {
              _ledger = values[0] as TreasuryLedgerPage;
              _ledgerSummary = values[1] as TreasuryLedgerSummary;
            });
          }
        case _TreasuryTab.loans:
          final value = await widget.repository.loans(
            page: _page,
            size: _pageSize,
          );
          if (mounted) setState(() => _loans = value);
        case _TreasuryTab.contributions:
          final value = await widget.repository.contributions(
            page: _page,
            size: _pageSize,
          );
          if (mounted) setState(() => _contributions = value);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted && showLoader) setState(() => _loading = false);
    }
  }

  void _selectTab(_TreasuryTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _page = 0;
      _error = null;
    });
    _loadActive();
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pickTreasury() async {
    final id = await showAppSheet<String>(
      context,
      builder: (context) => AppSheetScaffold(
        title: 'اختيار الخزنة',
        subtitle: 'لكل خزنة رصيدها وحركاتها',
        child: Column(
          children: [
            for (final treasury in _treasuries)
              _TreasuryOption(
                treasury: treasury,
                selected: treasury.id == _treasuryId,
                onTap: () => Navigator.pop(context, treasury.id),
              ),
          ],
        ),
      ),
    );
    if (id == null || id == _treasuryId || !mounted) return;
    setState(() {
      _treasuryId = id;
      _page = 0;
    });
    await _loadActive();
  }

  Future<void> _newMovement([String? initialType]) async {
    final selected = _selected;
    if (selected == null) return;
    final saved = await showAppSheet<bool>(
      context,
      tall: true,
      dismissible: false,
      builder: (context) => _MovementSheet(
        repository: widget.repository,
        treasury: selected,
        treasuries: _treasuries,
        custodyOptions: _custodyOptions,
        expenseOptions: _expenseOptions,
        canOperate: _canOperate,
        canApprove: _canApprove,
        initialType: initialType,
      ),
    );
    if (saved == true && mounted) {
      _notify('تم إرسال حركة الخزنة للمراجعة');
      setState(() {
        _tab = _TreasuryTab.movements;
        _page = 0;
      });
      await _initialize();
    }
  }

  Future<void> _openMovement(TreasuryMovement movement) async {
    final decision = await showAppSheet<(String, String)>(
      context,
      builder: (context) => _MovementDetail(
        movement: movement,
        canReview: _canApprove && movement.status == 'PENDING',
      ),
    );
    if (decision == null || !mounted) return;
    try {
      await widget.repository.review(
        movement,
        decision.$1,
        reason: decision.$2,
      );
      if (!mounted) return;
      _notify(decision.$1 == 'APPROVED' ? 'تم اعتماد الحركة' : 'تم رفض الحركة');
      await _initialize();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _openIntercompanyTransfer({
    required String purpose,
    IntercompanyLoan? loan,
  }) async {
    final options = _intercompanyOptions;
    if (options == null) return;
    final saved = await showAppSheet<bool>(
      context,
      tall: true,
      dismissible: false,
      builder: (context) => _IntercompanyTransferSheet(
        repository: widget.repository,
        options: options,
        purpose: purpose,
        loan: loan,
      ),
    );
    if (saved == true && mounted) {
      _notify(
        purpose == 'CONTRIBUTION'
            ? 'تم تسجيل المساهمة'
            : purpose == 'LOAN_REPAYMENT'
            ? 'تم تسجيل دفعة السلفة'
            : 'تم تسجيل السلفة الجديدة',
      );
      setState(() {
        _tab = purpose == 'CONTRIBUTION'
            ? _TreasuryTab.contributions
            : _TreasuryTab.loans;
        _page = 0;
      });
      await _initialize();
    }
  }

  Future<void> _reverseTransfer(IntercompanyTransfer transfer) async {
    final saved = await showAppSheet<bool>(
      context,
      dismissible: false,
      builder: (context) => _ReverseSheet(
        title: 'عكس التحويل',
        subtitle: '${transfer.from.companyName} ← ${transfer.to.companyName}',
        today: _intercompanyOptions?.today ?? formatIsoDate(DateTime.now()),
        onSave: (date, reason) => widget.repository.reverseIntercompanyTransfer(
          transferId: transfer.id,
          entryDate: date,
          reason: reason,
        ),
      ),
    );
    if (saved == true && mounted) {
      _notify('تم عكس التحويل');
      await _loadActive();
    }
  }

  Future<void> _reverseOperation(TreasuryLedgerEntry entry) async {
    final saved = await showAppSheet<bool>(
      context,
      dismissible: false,
      builder: (context) => _ReverseSheet(
        title: 'عكس الحركة',
        subtitle: entry.referenceNo,
        today: _expenseOptions?.today ?? formatIsoDate(DateTime.now()),
        onSave: (date, reason) => widget.repository.reverseOperation(
          operationId: entry.operationId,
          entryDate: date,
          reason: reason,
        ),
      ),
    );
    if (saved == true && mounted) {
      _notify('تم عكس الحركة');
      await _loadActive();
    }
  }

  bool _canReverseTransfer(IntercompanyTransfer transfer) {
    final options = _intercompanyOptions;
    if (options == null ||
        transfer.status != 'EXECUTED' ||
        transfer.reversedTransferId != null ||
        transfer.reversalTransferId != null) {
      return false;
    }
    bool approves(String companyId) => options.companies.any(
      (company) => company.id == companyId && company.canApprove,
    );
    return approves(transfer.from.companyId) && approves(transfer.to.companyId);
  }

  bool _canRepayLoan(IntercompanyLoan loan) {
    final options = _intercompanyOptions;
    if (options == null) return false;
    bool canAct(String companyId, bool request) => options.companies.any(
      (company) =>
          company.id == companyId &&
          (request ? company.canRequest : company.canApprove),
    );
    return canAct(loan.borrowerCompanyId, false) ||
        canAct(loan.lenderCompanyId, true);
  }

  Future<void> _openFilters() async {
    final (label, value, options) = switch (_tab) {
      _TreasuryTab.movements => (
        'حالة الحركة',
        _status,
        const [
          AppSelectOption(value: '', label: 'كل الحالات'),
          AppSelectOption(value: 'PENDING', label: 'بانتظار الموافقة'),
          AppSelectOption(value: 'EXECUTED', label: 'معتمدة'),
          AppSelectOption(value: 'REJECTED', label: 'مرفوضة'),
          AppSelectOption(value: 'REVERSED', label: 'معكوسة'),
        ],
      ),
      _TreasuryTab.ledger => (
        'اتجاه الحركة',
        _direction,
        const [
          AppSelectOption(value: '', label: 'كل الحركات'),
          AppSelectOption(value: 'IN', label: 'وارد'),
          AppSelectOption(value: 'OUT', label: 'منصرف'),
        ],
      ),
      _ => ('', '', const <AppSelectOption<String>>[]),
    };
    final result = await showAppFilterSheet<(String, int)>(
      context: context,
      subtitle: _tabLabel(_tab),
      initial: (value, _pageSize),
      empty: ('', _pageSize),
      isActive: (draft) => draft.$1.isNotEmpty,
      fields: (context, draft, update) => AppFilterGrid(
        children: [
          if (options.isNotEmpty)
            AppSelect<String>(
              compact: true,
              label: label,
              value: draft.$1,
              options: options,
              onChanged: (next) => update((next ?? '', draft.$2)),
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
      if (_tab == _TreasuryTab.movements) _status = result.$1;
      if (_tab == _TreasuryTab.ledger) _direction = result.$1;
      _pageSize = result.$2;
      _page = 0;
    });
    await _loadActive();
  }

  String get _filterSummary => switch (_tab) {
    _TreasuryTab.movements when _status.isNotEmpty => _statusLabel(_status),
    _TreasuryTab.ledger when _direction.isNotEmpty =>
      _direction == 'IN' ? 'وارد' : 'منصرف',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    if (_loading && selected == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && selected == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Center(
          child: MessagePanel(message: _error!, onRetry: _initialize),
        ),
      );
    }
    if (selected == null) {
      return const Center(child: Text('لا توجد خزنة متاحة لهذه الشركة'));
    }
    final pending =
        _movements?.items.where((item) => item.status == 'PENDING').length ?? 0;
    final page = _activePage;
    final canStartIntercompany =
        _intercompanyOptions?.companies.any(
          (company) => company.canApprove || company.canRequest,
        ) ??
        false;
    return RefreshIndicator(
      onRefresh: () => _loadActive(showLoader: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.md,
          AppSpace.md,
          40,
        ),
        children: [
          const PageHeader(title: 'الخزن'),
          const SizedBox(height: 14),
          _TreasuryHero(
            treasury: selected,
            onSwitch: _treasuries.length > 1 ? _pickTreasury : null,
          ),
          if (_canOperate || _canApprove) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _quickActionsOpen = !_quickActionsOpen),
                    icon: Icon(
                      _quickActionsOpen
                          ? LucideIcons.chevronUp
                          : LucideIcons.zap,
                      size: 16,
                    ),
                    label: Text(
                      _quickActionsOpen ? 'إخفاء الإجراءات' : 'إجراءات سريعة',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _newMovement,
                  icon: const Icon(LucideIcons.plus, size: 17),
                  label: const Text('حركة جديدة'),
                ),
              ],
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _quickActionsOpen
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _QuickActions(
                  canOperate: _canOperate,
                  canApprove: _canApprove,
                  onSelected: _newMovement,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          LedgerTabs<_TreasuryTab>(
            value: _tab,
            tabs: [
              (
                _TreasuryTab.movements,
                'حركات الخزنة',
                _canApprove ? pending : 0,
              ),
              (_TreasuryTab.ledger, 'كشف الحساب', 0),
              if (_canViewIntercompany) (_TreasuryTab.loans, 'سلف', 0),
              if (_canViewIntercompany)
                (_TreasuryTab.contributions, 'مساهمات', 0),
            ],
            onChanged: _selectTab,
          ),
          const SizedBox(height: 10),
          if (_tab == _TreasuryTab.loans && canStartIntercompany) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: () =>
                    _openIntercompanyTransfer(purpose: 'LOAN_DISBURSEMENT'),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('سلفة جديدة'),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_tab == _TreasuryTab.contributions && canStartIntercompany) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: () =>
                    _openIntercompanyTransfer(purpose: 'CONTRIBUTION'),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('مساهمة جديدة'),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (_tab == _TreasuryTab.ledger && _ledgerSummary != null) ...[
            _LedgerSummaryGrid(summary: _ledgerSummary!),
            const SizedBox(height: 10),
          ],
          AppFilterBar(
            activeCount: _filterSummary.isEmpty ? 0 : 1,
            summary: _filterSummary,
            onOpen: _openFilters,
            onClear: () {
              setState(() {
                _status = '';
                _direction = '';
                _page = 0;
              });
              _loadActive();
            },
          ),
          const SizedBox(height: 10),
          if (_error != null) ...[
            MessagePanel(message: _error!, onRetry: _loadActive),
            const SizedBox(height: 10),
          ],
          _activeTable(context),
          if (page != null) ...[
            const SizedBox(height: 12),
            AppPagination(
              page: _page,
              size: _pageSize,
              total: page,
              disabled: _loading,
              onChanged: (index) {
                setState(() => _page = index);
                _loadActive();
              },
            ),
          ],
        ],
      ),
    );
  }

  int? get _activePage => switch (_tab) {
    _TreasuryTab.movements => _movements?.total,
    _TreasuryTab.ledger => _ledger?.total,
    _TreasuryTab.loans => _loans?.total,
    _TreasuryTab.contributions => _contributions?.total,
  };

  Widget _activeTable(BuildContext context) {
    final tokens = context.tokens;
    final empty = AppEmptyState(
      icon: _filterSummary.isEmpty ? LucideIcons.inbox : LucideIcons.searchX,
      title: 'لا توجد بيانات مطابقة',
      message: _filterSummary.isEmpty
          ? null
          : 'غيّر الفلاتر أو امسحها لعرض كل البيانات.',
    );
    return switch (_tab) {
      _TreasuryTab.movements => AppDataTable<TreasuryMovement>(
        columns: const [
          AppTableColumn('الحركة', 170),
          AppTableColumn('المبلغ', 118, numeric: true),
          AppTableColumn('الحالة', 140),
          AppTableColumn('التاريخ', 96),
          AppTableColumn('الخزنة', 130),
          AppTableColumn('البيان / المستلم', 190),
          AppTableColumn('أنشأها', 120),
          AppTableColumn('المراجعة', 120),
        ],
        rows: _movements?.items ?? const [],
        loading: _loading,
        empty: empty,
        rowColor: (item) =>
            item.status == 'REJECTED' ? AppTokens.dangerTint : null,
        onTap: _openMovement,
        cells: (item) => [
          AppTableTitle(
            title: _typeLabel(item.type),
            subtitle: item.method == null ? null : _methodLabel(item.method!),
            dot: _typeColor(item.type),
          ),
          AppMoney(
            '${_typeSign(item.type)}${money(item.amount)}',
            tone: item.status == 'REJECTED'
                ? AppMoneyTone.voided
                : _typeSign(item.type) == '+'
                ? AppMoneyTone.incoming
                : AppMoneyTone.plain,
          ),
          _statusTag(item.status),
          Text(
            shortDate(item.entryDate),
            style: TextStyle(color: tokens.muted),
          ),
          Text(item.treasuryName, maxLines: 2, overflow: TextOverflow.ellipsis),
          AppTableTitle(
            title: item.description?.isNotEmpty == true
                ? item.description!
                : 'بدون بيان',
            subtitle: item.recipientName ?? item.destinationTreasuryName,
          ),
          Text(item.creatorName ?? '—'),
          item.status == 'PENDING' && _canApprove
              ? const AppTag('بانتظارك', tone: AppTone.warning)
              : Text(
                  item.reviewerName ?? '—',
                  style: TextStyle(color: tokens.muted),
                ),
        ],
      ),
      _TreasuryTab.ledger => AppDataTable<TreasuryLedgerEntry>(
        columns: [
          const AppTableColumn('الحركة', 170),
          const AppTableColumn('المبلغ', 118, numeric: true),
          const AppTableColumn('الرصيد بعدها', 124, numeric: true),
          const AppTableColumn('التاريخ', 96),
          const AppTableColumn('المرجع', 120),
          const AppTableColumn('البيان', 210),
          if (_canApprove) const AppTableColumn('إجراء', 96),
        ],
        rows: _ledger?.items ?? const [],
        loading: _loading,
        empty: empty,
        cells: (entry) => [
          AppTableTitle(
            title: _ledgerTypeLabel(entry.type),
            subtitle: entry.direction == 'IN' ? 'وارد' : 'منصرف',
            dot: entry.direction == 'IN' ? AppTokens.success : AppTokens.danger,
          ),
          AppMoney(
            '${entry.direction == 'IN' ? '+' : '−'}${money(entry.amount)}',
            tone: entry.direction == 'IN'
                ? AppMoneyTone.incoming
                : AppMoneyTone.plain,
          ),
          AppMoney(money(entry.balanceAfter)),
          Text(
            shortDate(entry.entryDate),
            style: TextStyle(color: tokens.muted),
          ),
          Text(entry.referenceNo, style: TextStyle(color: tokens.muted)),
          Text(
            entry.description.isEmpty ? '—' : entry.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (_canApprove)
            entry.status == 'EXECUTED' &&
                    entry.reversedOperationId == null &&
                    _reversibleOperationKinds.contains(entry.type)
                ? OutlinedButton.icon(
                    onPressed: () => _reverseOperation(entry),
                    icon: const Icon(LucideIcons.undo2, size: 15),
                    label: const Text('عكس'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTokens.danger,
                    ),
                  )
                : const SizedBox.shrink(),
        ],
      ),
      _TreasuryTab.loans => _LoanCards(
        loans: _loans?.items ?? const [],
        loading: _loading,
        empty: empty,
        canRepay: _canRepayLoan,
        onRepay: (loan) =>
            _openIntercompanyTransfer(purpose: 'LOAN_REPAYMENT', loan: loan),
      ),
      _TreasuryTab.contributions => _ContributionCards(
        transfers: _contributions?.items ?? const [],
        loading: _loading,
        empty: empty,
        canReverse: _canReverseTransfer,
        onReverse: _reverseTransfer,
      ),
    };
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.canOperate,
    required this.canApprove,
    required this.onSelected,
  });
  final bool canOperate;
  final bool canApprove;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final actions = <(String, String, String, IconData)>[
      if (canOperate)
        (
          'DIRECT_EXPENSE',
          'إضافة صرف مباشر',
          'مستند أو فاتورة',
          LucideIcons.receipt,
        ),
      if (canApprove)
        (
          'CUSTODY_RETURN',
          'رد إلى الخزنة',
          'استرجاع متبقي عهدة',
          LucideIcons.undo2,
        ),
      if (canOperate)
        (
          'CUSTODY_FUNDING',
          'تحويل إلى عهدة',
          'صرف عهدة لموظف',
          LucideIcons.wallet,
        ),
      if (canOperate)
        ('DEPOSIT', 'إيداع بالخزنة', 'تغذية رصيد الخزنة', LucideIcons.plus),
      if (canOperate)
        ('CORRECTION', 'تصحيح رصيد', 'تسوية عجز أو زيادة', LucideIcons.scale),
    ];
    final tokens = context.tokens;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 2.45,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return Material(
          color: tokens.sunken,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: tokens.line),
          ),
          child: InkWell(
            onTap: () => onSelected(action.$1),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: tokens.line),
                    ),
                    child: Icon(action.$4, size: 15, color: tokens.brand),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.ink,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          action.$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: tokens.muted, fontSize: 8.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoanCards extends StatelessWidget {
  const _LoanCards({
    required this.loans,
    required this.loading,
    required this.empty,
    required this.canRepay,
    required this.onRepay,
  });
  final List<IntercompanyLoan> loans;
  final bool loading;
  final Widget empty;
  final bool Function(IntercompanyLoan) canRepay;
  final ValueChanged<IntercompanyLoan> onRepay;

  @override
  Widget build(BuildContext context) {
    if (loading && loans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (loans.isEmpty) return empty;
    final tokens = context.tokens;
    return Column(
      children: [
        for (final loan in loans) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: tokens.wash,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        LucideIcons.handCoins,
                        size: 19,
                        color: tokens.brand,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loan.borrowerCompanyName,
                            style: TextStyle(
                              color: tokens.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'من ${loan.lenderCompanyName}',
                            style: TextStyle(color: tokens.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    _loanTag(loan.status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CardMetric(
                        label: 'أصل السلفة',
                        value:
                            '${money(loan.principalAmount)} ${loan.currencyCode}',
                      ),
                    ),
                    Expanded(
                      child: _CardMetric(
                        label: 'المتبقي',
                        value:
                            '${money(loan.principalOutstanding)} ${loan.currencyCode}',
                        tone: AppTokens.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: _loanProgress(loan),
                    color: tokens.brand,
                    backgroundColor: tokens.line,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '${shortDate(loan.disbursedOn)}${loan.purpose.isEmpty ? '' : ' · ${loan.purpose}'}',
                  style: TextStyle(color: tokens.muted, fontSize: 11),
                ),
                if (canRepay(loan) &&
                    (loan.status == 'ACTIVE' ||
                        loan.status == 'PARTIALLY_REPAID')) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => onRepay(loan),
                    icon: const Icon(LucideIcons.handCoins, size: 17),
                    label: const Text('تسجيل دفعة'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

double _loanProgress(IntercompanyLoan loan) {
  final principal = double.tryParse(loan.principalAmount) ?? 0;
  final outstanding = double.tryParse(loan.principalOutstanding) ?? 0;
  if (principal <= 0) return 0;
  return ((principal - outstanding) / principal).clamp(0, 1);
}

class _ContributionCards extends StatelessWidget {
  const _ContributionCards({
    required this.transfers,
    required this.loading,
    required this.empty,
    required this.canReverse,
    required this.onReverse,
  });
  final List<IntercompanyTransfer> transfers;
  final bool loading;
  final Widget empty;
  final bool Function(IntercompanyTransfer) canReverse;
  final ValueChanged<IntercompanyTransfer> onReverse;

  @override
  Widget build(BuildContext context) {
    if (loading && transfers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (transfers.isEmpty) return empty;
    final tokens = context.tokens;
    return Column(
      children: [
        for (final transfer in transfers) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: transfer.status == 'REVERSED'
                  ? tokens.sunken
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'مساهمة',
                        style: TextStyle(
                          color: tokens.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    _intercompanyTag(transfer.status),
                  ],
                ),
                const SizedBox(height: 12),
                _TransferParty(
                  label: 'من',
                  company: transfer.from.companyName,
                  treasury: transfer.from.treasuryName,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Icon(
                    LucideIcons.arrowDown,
                    size: 16,
                    color: tokens.muted,
                  ),
                ),
                _TransferParty(
                  label: 'إلى',
                  company: transfer.to.companyName,
                  treasury: transfer.to.treasuryName,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CardMetric(
                        label: 'خرج',
                        value:
                            '${money(transfer.from.amount)} ${transfer.from.currencyCode}',
                      ),
                    ),
                    Expanded(
                      child: _CardMetric(
                        label: transfer.status == 'IN_TRANSIT'
                            ? 'متوقع'
                            : 'وصل',
                        value:
                            '${money(transfer.to.amount)} ${transfer.to.currencyCode}',
                        tone: AppTokens.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${shortDate(transfer.entryDate)} · ${transfer.description.isEmpty ? 'بدون بيان' : transfer.description}',
                  style: TextStyle(color: tokens.muted, fontSize: 11),
                ),
                if (canReverse(transfer)) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => onReverse(transfer),
                    icon: const Icon(LucideIcons.undo2, size: 16),
                    label: const Text('عكس الحركة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTokens.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TransferParty extends StatelessWidget {
  const _TransferParty({
    required this.label,
    required this.company,
    required this.treasury,
  });
  final String label;
  final String company;
  final String treasury;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 30,
        child: Text(
          label,
          style: TextStyle(color: context.tokens.muted, fontSize: 11),
        ),
      ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(company, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              treasury,
              style: TextStyle(color: context.tokens.muted, fontSize: 10.5),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CardMetric extends StatelessWidget {
  const _CardMetric({required this.label, required this.value, this.tone});
  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(color: context.tokens.muted, fontSize: 10.5),
      ),
      Text(
        value,
        textDirection: TextDirection.ltr,
        style: TextStyle(
          color: tone ?? context.tokens.ink,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _TreasuryHero extends StatelessWidget {
  const _TreasuryHero({required this.treasury, required this.onSwitch});
  final TreasuryAccount treasury;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const soft = Color(0xB8FFFFFF);
    final parts = money(treasury.balance).split('.');
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [tokens.brand, tokens.brandStrong, tokens.brandDeep],
          stops: const [0, .55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.brandStrong.withValues(alpha: .35),
            blurRadius: 30,
            offset: const Offset(0, 14),
            spreadRadius: -16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onSwitch,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        LucideIcons.landmark,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            treasury.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            [
                              treasury.code,
                              treasury.defaultTreasury
                                  ? 'افتراضية'
                                  : 'خزنة فرعية',
                              if (!treasury.active) 'غير نشطة',
                            ].join(' · '),
                            style: const TextStyle(
                              color: soft,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onSwitch != null)
                      const Row(
                        children: [
                          Text(
                            'تغيير',
                            style: TextStyle(
                              color: soft,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(LucideIcons.chevronDown, color: soft, size: 16),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'الرصيد المعتمد',
            style: TextStyle(
              color: soft,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: parts.first),
                      if (parts.length > 1)
                        TextSpan(
                          text: '.${parts[1]}',
                          style: const TextStyle(
                            fontSize: 22,
                            color: Color(0xB3FFFFFF),
                          ),
                        ),
                    ],
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                treasury.currencyCode,
                style: const TextStyle(
                  color: soft,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TreasuryOption extends StatelessWidget {
  const _TreasuryOption({
    required this.treasury,
    required this.selected,
    required this.onTap,
  });

  final TreasuryAccount treasury;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? tokens.wash : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? tokens.brand : tokens.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected ? tokens.brand : tokens.sunken,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.landmark,
                    size: 18,
                    color: selected ? Colors.white : tokens.ink,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        treasury.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${treasury.code}${treasury.defaultTreasury ? ' · افتراضية' : ''}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: tokens.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                AppMoney(
                  '${money(treasury.balance)} ${treasury.currencyCode}',
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LedgerSummaryGrid extends StatelessWidget {
  const _LedgerSummaryGrid({required this.summary});
  final TreasuryLedgerSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final items = [
      ('الرصيد الافتتاحي', summary.openingBalance, tokens.ink, null),
      ('الوارد', summary.inflows, AppTokens.success, LucideIcons.arrowDownLeft),
      ('المنصرف', summary.outflows, AppTokens.danger, LucideIcons.arrowUpRight),
      ('الرصيد الختامي', summary.closingBalance, tokens.brandStrong, null),
    ];
    return AppFilterGrid(
      children: [
        for (final (label, value, color, icon) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 13, color: color),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tokens.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${money(value)} ${summary.currencyCode}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A movement's details; managers approve or reject from its footer.
/// Pops with (decision, reason).
class _MovementDetail extends StatefulWidget {
  const _MovementDetail({required this.movement, required this.canReview});
  final TreasuryMovement movement;
  final bool canReview;

  @override
  State<_MovementDetail> createState() => _MovementDetailState();
}

class _MovementDetailState extends State<_MovementDetail> {
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  bool _rejecting = false;

  @override
  void dispose() {
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movement;
    final tokens = context.tokens;
    final sign = _typeSign(m.type);
    return AppSheetScaffold(
      title: 'تفاصيل حركة الخزنة',
      subtitle: '${_typeLabel(m.type)} · ${m.treasuryName}',
      footer: !widget.canReview
          ? null
          : _rejecting
          ? AppSheetActions(
              primaryLabel: 'تأكيد الرفض',
              primaryIcon: LucideIcons.x,
              destructive: true,
              onPrimary: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, ('REJECTED', _reason.text.trim()));
                }
              },
              secondaryLabel: 'إلغاء',
              onSecondary: () => setState(() => _rejecting = false),
            )
          : AppSheetActions(
              primaryLabel: 'اعتماد الحركة',
              onPrimary: () =>
                  Navigator.pop(context, ('APPROVED', _note.text.trim())),
              secondaryLabel: 'رفض',
              onSecondary: () => setState(() => _rejecting = true),
            ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _typeColor(m.type).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(_typeIcon(m.type), color: _typeColor(m.type)),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: AppMoney(
                '$sign${money(m.amount)}',
                size: 30,
                tone: m.status == 'REJECTED'
                    ? AppMoneyTone.voided
                    : sign == '+'
                    ? AppMoneyTone.incoming
                    : AppMoneyTone.plain,
              ),
            ),
            const SizedBox(height: 8),
            Center(child: _statusTag(m.status)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: tokens.sunken,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.line),
              ),
              child: Column(
                children: [
                  for (final (i, (label, value)) in [
                    ('التاريخ', shortDate(m.entryDate)),
                    if (m.method != null)
                      ('طريقة الدفع', _methodLabel(m.method!)),
                    if (m.recipientName != null) ('المستلم', m.recipientName!),
                    if (m.destinationTreasuryName != null)
                      ('الخزنة المستقبلة', m.destinationTreasuryName!),
                    if (m.centerName != null) ('مركز التكلفة', m.centerName!),
                    if (m.categoryName != null) ('بند الصرف', m.categoryName!),
                    if (m.contractorName != null)
                      ('المقاول', m.contractorName!),
                    if (m.depositKind != null)
                      ('نوع الإيداع', _depositKindLabel(m.depositKind!)),
                    ('البيان', m.description ?? '—'),
                    ('أنشأها', m.creatorName ?? '—'),
                    if (m.reviewerName != null) ('راجعها', m.reviewerName!),
                  ].indexed)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: i == 0
                            ? null
                            : Border(top: BorderSide(color: tokens.line)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              color: tokens.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              value,
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (m.reviewReason?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTokens.dangerTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  m.reviewReason!,
                  style: const TextStyle(
                    color: Color(0xFF7A1A12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (widget.canReview && !_rejecting) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة اختيارية',
                  alignLabelWithHint: true,
                ),
              ),
            ],
            if (_rejecting) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _reason,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'سبب الرفض *',
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'سبب الرفض مطلوب'
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReverseSheet extends StatefulWidget {
  const _ReverseSheet({
    required this.title,
    required this.subtitle,
    required this.today,
    required this.onSave,
  });
  final String title;
  final String subtitle;
  final String today;
  final Future<void> Function(String date, String reason) onSave;

  @override
  State<_ReverseSheet> createState() => _ReverseSheetState();
}

class _ReverseSheetState extends State<_ReverseSheet> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late String _date;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = widget.today.isEmpty ? formatIsoDate(DateTime.now()) : widget.today;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_date, _reason.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: widget.title,
    subtitle: widget.subtitle,
    closeEnabled: !_saving,
    onClose: () => Navigator.pop(context, false),
    footer: AppSheetActions(
      primaryLabel: 'تأكيد العكس',
      primaryIcon: LucideIcons.undo2,
      destructive: true,
      busy: _saving,
      busyLabel: 'جارٍ العكس…',
      onPrimary: _save,
    ),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            MessagePanel(message: _error!),
            const SizedBox(height: 12),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: _saving
                ? null
                : () async {
                    final picked = await showAppDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null && mounted) {
                      setState(() => _date = formatIsoDate(picked));
                    }
                  },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'التاريخ *',
                suffixIcon: Icon(LucideIcons.calendarDays, size: 18),
              ),
              child: Text(shortDate(_date)),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _reason,
            minLines: 3,
            maxLines: 5,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'السبب *',
              alignLabelWithHint: true,
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'سبب العكس مطلوب'
                : null,
          ),
        ],
      ),
    ),
  );
}

class _IntercompanyTransferSheet extends StatefulWidget {
  const _IntercompanyTransferSheet({
    required this.repository,
    required this.options,
    required this.purpose,
    this.loan,
  });
  final TreasuryRepository repository;
  final IntercompanyOptions options;
  final String purpose;
  final IntercompanyLoan? loan;

  @override
  State<_IntercompanyTransferSheet> createState() =>
      _IntercompanyTransferSheetState();
}

class _IntercompanyTransferSheetState
    extends State<_IntercompanyTransferSheet> {
  final _form = GlobalKey<FormState>();
  final _fromAmount = TextEditingController();
  final _toAmount = TextEditingController();
  final _description = TextEditingController();
  late String _mode;
  late String _fromCompanyId;
  late String _toCompanyId;
  String? _fromTreasuryId;
  String? _toTreasuryId;
  late String _entryDate;
  bool _saving = false;
  String? _error;

  List<IntercompanyCompanyOption> get _senders => widget.options.companies
      .where((company) => company.canApprove)
      .toList(growable: false);
  List<IntercompanyCompanyOption> get _requesters => widget.options.companies
      .where((company) => company.canRequest)
      .toList(growable: false);
  IntercompanyCompanyOption? _company(String id) =>
      widget.options.companies.where((company) => company.id == id).firstOrNull;

  @override
  void initState() {
    super.initState();
    _entryDate = widget.options.today.isEmpty
        ? formatIsoDate(DateTime.now())
        : widget.options.today;
    final loan = widget.loan;
    if (loan != null) {
      _fromCompanyId = loan.borrowerCompanyId;
      _toCompanyId = loan.lenderCompanyId;
      _mode = _company(_fromCompanyId)?.canApprove == true
          ? 'EXECUTE'
          : 'REQUEST';
    } else {
      _mode = _senders.isNotEmpty ? 'EXECUTE' : 'REQUEST';
      _setDefaultCompanies();
    }
  }

  void _setDefaultCompanies() {
    final fromChoices = _mode == 'EXECUTE'
        ? _senders
        : widget.options.companies;
    final toChoices = _mode == 'EXECUTE'
        ? widget.options.companies
        : _requesters;
    _fromCompanyId =
        fromChoices
            .where((company) => company.id == widget.options.activeCompanyId)
            .firstOrNull
            ?.id ??
        fromChoices.firstOrNull?.id ??
        '';
    _toCompanyId =
        toChoices
            .where((company) => company.id != _fromCompanyId)
            .firstOrNull
            ?.id ??
        '';
  }

  @override
  void dispose() {
    _fromAmount.dispose();
    _toAmount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createIntercompanyTransfer(
        mode: _mode,
        fromCompanyId: _fromCompanyId,
        toCompanyId: _toCompanyId,
        fromTreasuryId: _fromTreasuryId,
        toTreasuryId: _toTreasuryId!,
        fromAmount: _fromAmount.text.trim().isEmpty
            ? null
            : _fromAmount.text.trim(),
        toAmount: _toAmount.text.trim().isEmpty ? null : _toAmount.text.trim(),
        purpose: widget.purpose,
        loanId: widget.loan?.id,
        entryDate: _entryDate,
        description: _description.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _title => switch (widget.purpose) {
    'CONTRIBUTION' => 'مساهمة جديدة',
    'LOAN_REPAYMENT' => 'تسجيل دفعة سلفة',
    _ => 'سلفة جديدة',
  };

  @override
  Widget build(BuildContext context) {
    final fixedLoan = widget.loan != null;
    final fromCompanies = _mode == 'EXECUTE'
        ? _senders
        : widget.options.companies;
    final toCompanies = _mode == 'EXECUTE'
        ? widget.options.companies
        : _requesters;
    final fromTreasuries = _company(_fromCompanyId)?.treasuries ?? const [];
    final toTreasuries = _company(_toCompanyId)?.treasuries ?? const [];
    final fromCurrency = fromTreasuries
        .where((item) => item.id == _fromTreasuryId)
        .firstOrNull
        ?.currencyCode;
    final toCurrency = toTreasuries
        .where((item) => item.id == _toTreasuryId)
        .firstOrNull
        ?.currencyCode;
    return AppSheetScaffold(
      title: _title,
      subtitle: widget.purpose == 'CONTRIBUTION'
          ? 'تحويل بين شركتين بدون إنشاء دين'
          : 'تحويل بين الشركات مرتبط بالسلف',
      closeEnabled: !_saving,
      onClose: () => Navigator.pop(context, false),
      footer: AppSheetActions(
        primaryLabel: _title,
        primaryIcon: LucideIcons.send,
        busy: _saving,
        busyLabel: 'جارٍ الحفظ…',
        onPrimary: _save,
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              MessagePanel(message: _error!),
              const SizedBox(height: 12),
            ],
            AppSegmented<String>(
              value: _mode,
              options: const [
                ('EXECUTE', 'إرسال من شركتي', LucideIcons.send),
                ('REQUEST', 'طلب من شركة أخرى', LucideIcons.inbox),
              ],
              onChanged: fixedLoan || _saving
                  ? null
                  : (value) => setState(() {
                      _mode = value;
                      _fromTreasuryId = null;
                      _toTreasuryId = null;
                      _setDefaultCompanies();
                    }),
            ),
            const SizedBox(height: 14),
            AppSelect<String>(
              label: _mode == 'EXECUTE'
                  ? 'الشركة المُرسلة'
                  : 'الشركة المطلوب منها',
              value: _fromCompanyId.isEmpty ? null : _fromCompanyId,
              enabled: !fixedLoan && !_saving,
              options: [
                for (final company in fromCompanies)
                  if (company.id != _toCompanyId)
                    AppSelectOption(
                      value: company.id,
                      label: company.name,
                      subtitle: company.code,
                    ),
              ],
              onChanged: (value) => setState(() {
                _fromCompanyId = value ?? '';
                _fromTreasuryId = null;
              }),
              validator: (value) => value == null ? 'اختر الشركة' : null,
            ),
            const SizedBox(height: 12),
            AppSelect<String>(
              label: _mode == 'EXECUTE' ? 'الشركة المستلمة' : 'شركتك المستلمة',
              value: _toCompanyId.isEmpty ? null : _toCompanyId,
              enabled: !fixedLoan && !_saving,
              options: [
                for (final company in toCompanies)
                  if (company.id != _fromCompanyId)
                    AppSelectOption(
                      value: company.id,
                      label: company.name,
                      subtitle: company.code,
                    ),
              ],
              onChanged: (value) => setState(() {
                _toCompanyId = value ?? '';
                _toTreasuryId = null;
              }),
              validator: (value) => value == null ? 'اختر الشركة' : null,
            ),
            const SizedBox(height: 12),
            if (_mode == 'EXECUTE') ...[
              AppSelect<String>(
                label: 'خزنة المُرسل',
                value: _fromTreasuryId,
                enabled: !_saving && _fromCompanyId.isNotEmpty,
                options: [
                  for (final treasury in fromTreasuries)
                    if (widget.loan == null ||
                        treasury.currencyCode == widget.loan!.currencyCode)
                      AppSelectOption(
                        value: treasury.id,
                        label: treasury.name,
                        subtitle: '${treasury.code} · ${treasury.currencyCode}',
                      ),
                ],
                onChanged: (value) => setState(() => _fromTreasuryId = value),
                validator: (value) => value == null ? 'اختر الخزنة' : null,
              ),
              const SizedBox(height: 12),
            ],
            AppSelect<String>(
              label: 'خزنة المستلم',
              value: _toTreasuryId,
              enabled: !_saving && _toCompanyId.isNotEmpty,
              options: [
                for (final treasury in toTreasuries)
                  AppSelectOption(
                    value: treasury.id,
                    label: treasury.name,
                    subtitle: '${treasury.code} · ${treasury.currencyCode}',
                  ),
              ],
              onChanged: (value) => setState(() => _toTreasuryId = value),
              validator: (value) => value == null ? 'اختر الخزنة' : null,
            ),
            if (_mode == 'EXECUTE') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _fromAmount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      'المبلغ الذي يخرج${fromCurrency == null ? '' : ' ($fromCurrency)'}',
                ),
                validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                    ? 'أدخل مبلغًا صحيحًا'
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _toAmount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _mode == 'EXECUTE'
                    ? 'المبلغ المتوقع وصوله${toCurrency == null ? '' : ' ($toCurrency)'} (اختياري)'
                    : 'المبلغ المطلوب${toCurrency == null ? '' : ' ($toCurrency)'}',
              ),
              validator: _mode == 'REQUEST'
                  ? (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                        ? 'أدخل مبلغًا صحيحًا'
                        : null
                  : null,
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: _saving
                  ? null
                  : () async {
                      final picked = await showAppDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(_entryDate) ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null && mounted) {
                        setState(() => _entryDate = formatIsoDate(picked));
                      }
                    },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'التاريخ *',
                  suffixIcon: Icon(LucideIcons.calendarDays, size: 18),
                ),
                child: Text(shortDate(_entryDate)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              textAlign: TextAlign.right,
              decoration: const InputDecoration(
                labelText: 'البيان (اختياري)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementSheet extends StatefulWidget {
  const _MovementSheet({
    required this.repository,
    required this.treasury,
    required this.treasuries,
    required this.custodyOptions,
    required this.expenseOptions,
    required this.canOperate,
    required this.canApprove,
    this.initialType,
  });
  final TreasuryRepository repository;
  final TreasuryAccount treasury;
  final List<TreasuryAccount> treasuries;
  final ExpenseOptions? custodyOptions;
  final DirectExpenseOptions? expenseOptions;
  final bool canOperate;
  final bool canApprove;
  final String? initialType;

  @override
  State<_MovementSheet> createState() => _MovementSheetState();
}

class _MovementSheetState extends State<_MovementSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String _type = 'DEPOSIT';
  String _method = 'CASH';
  String? _centerId;
  String? _depositKind;
  String? _destinationTreasuryId;
  String? _recipientId;
  String? _categoryId;
  String _costDirection = 'PROJECTS';
  String _evidenceType = 'CONTRACTOR';
  String? _contractorId;
  String _entryDate = '';
  List<XFile> _invoices = const [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type =
        widget.initialType ??
        (widget.canOperate ? 'DEPOSIT' : 'CUSTODY_RETURN');
    _entryDate =
        widget.expenseOptions?.today ??
        widget.custodyOptions?.today ??
        formatIsoDate(DateTime.now());
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _directExpense => _type == 'DIRECT_EXPENSE';
  bool get _return => _type == 'CUSTODY_RETURN';

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_directExpense && _evidenceType == 'INVOICE' && _invoices.isEmpty) {
      setState(() => _error = 'اختر صورة فاتورة واحدة على الأقل');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_directExpense) {
        await widget.repository.createDirectExpense(
          treasuryId: widget.treasury.id,
          amount: _amount.text,
          entryDate: _entryDate,
          description: _description.text,
          method: _method,
          centerId: _centerId!,
          categoryId: _categoryId!,
          costDirection: _costDirection,
          evidenceType: _evidenceType,
          contractorId: _contractorId,
          invoicePaths: _invoices.map((file) => file.path).toList(),
        );
      } else if (_return) {
        await widget.repository.returnFromCustody(
          treasuryId: widget.treasury.id,
          ownerId: _recipientId!,
          amount: _amount.text,
          entryDate: _entryDate,
          description: _description.text,
          method: _method,
        );
      } else {
        await widget.repository.createMovement(
          treasuryId: widget.treasury.id,
          type: _type,
          amount: _amount.text,
          entryDate: _entryDate,
          description: _description.text,
          method: _method,
          recipientId: _recipientId,
          destinationTreasuryId: _destinationTreasuryId,
          centerId: _centerId,
          depositKind: _depositKind,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _selectType(String value) {
    setState(() {
      _type = value;
      _centerId = null;
      _depositKind = null;
      _destinationTreasuryId = null;
      _recipientId = null;
      _categoryId = null;
      _contractorId = null;
      _invoices = const [];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final people = (widget.custodyOptions?.people ?? const <CustodyPerson>[])
        .where((person) => person.active && person.custodyId != null)
        .toList(growable: false);
    final types = [
      ('DEPOSIT', widget.canOperate),
      ('DIRECT_EXPENSE', widget.canOperate),
      ('TREASURY_TRANSFER', widget.canOperate && widget.treasuries.length > 1),
      ('CUSTODY_FUNDING', widget.canOperate),
      if (widget.canApprove) ('CUSTODY_RETURN', true),
      ('CORRECTION', widget.canOperate),
    ];
    return AppSheetScaffold(
      title: 'حركة خزنة جديدة',
      subtitle: '${widget.treasury.name} · ${widget.treasury.code}',
      closeEnabled: !_saving,
      onClose: () => Navigator.pop(context, false),
      footer: AppSheetActions(
        primaryLabel: 'إرسال للموافقة',
        primaryIcon: LucideIcons.send,
        busy: _saving,
        busyLabel: 'جارٍ الإرسال…',
        onPrimary: _save,
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Label('نوع الحركة'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.3,
              children: [
                for (final (type, enabled) in types)
                  _TypeChoice(
                    type: type,
                    current: _type,
                    enabled: enabled,
                    onTap: _selectType,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              MessagePanel(message: _error!),
              const SizedBox(height: 12),
            ],
            AppAmountField(
              controller: _amount,
              enabled: !_saving,
              currency: widget.treasury.currencyCode,
              hint: _type == 'CORRECTION' || _type == 'DEPOSIT'
                  ? null
                  : 'رصيد الخزنة',
              hintValue: money(widget.treasury.balance),
              validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                  ? 'أدخل مبلغًا صحيحًا'
                  : null,
            ),
            if (_type != 'CORRECTION') ...[
              const SizedBox(height: 14),
              _Label(_return ? 'طريقة الاستلام' : 'طريقة الدفع'),
              AppSegmented<String>(
                value: _method,
                options: const [
                  ('CASH', 'كاش', LucideIcons.banknote),
                  ('BANK_TRANSFER', 'تحويل بنكي', LucideIcons.landmark),
                  ('CHEQUE', 'شيك', LucideIcons.fileText),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _method = value),
              ),
            ],
            const SizedBox(height: 14),
            if (_type == 'DEPOSIT') ...[
              _referenceSelect(
                'مركز التكلفة (اختياري)',
                _centerId,
                widget.expenseOptions?.centers ?? const [],
                (value) => setState(() => _centerId = value),
                required: false,
              ),
              const SizedBox(height: 12),
              _select(
                label: 'نوع الإيداع (اختياري)',
                value: _depositKind,
                options: _depositKinds,
                onChanged: (value) => setState(() => _depositKind = value),
                allowEmpty: true,
              ),
              const SizedBox(height: 12),
            ],
            if (_type == 'TREASURY_TRANSFER') ...[
              AppSelect<String>(
                label: 'الخزنة المستقبلة',
                value: _destinationTreasuryId,
                options: [
                  for (final item in widget.treasuries)
                    if (item.id != widget.treasury.id)
                      AppSelectOption(
                        value: item.id,
                        label: item.name,
                        subtitle: item.code,
                      ),
                ],
                onChanged: (value) =>
                    setState(() => _destinationTreasuryId = value),
                validator: (value) =>
                    value == null ? 'اختر الخزنة المستقبلة' : null,
              ),
              const SizedBox(height: 12),
            ],
            if (_type == 'CUSTODY_FUNDING' || _return) ...[
              AppSelect<String>(
                label: 'صاحب العهدة',
                value: _recipientId,
                placeholder: people.isEmpty
                    ? 'لا يوجد أصحاب عهدة متاحون'
                    : 'اختر صاحب العهدة',
                options: [
                  for (final person in people)
                    AppSelectOption(
                      value: person.id,
                      label: person.name,
                      subtitle: person.code,
                    ),
                ],
                onChanged: (value) => setState(() => _recipientId = value),
                validator: (value) => value == null ? 'اختر صاحب العهدة' : null,
              ),
              const SizedBox(height: 12),
            ],
            if (_directExpense) ...[
              _referenceSelect(
                'مركز التكلفة',
                _centerId,
                widget.expenseOptions?.centers ?? const [],
                (value) => setState(() => _centerId = value),
              ),
              const SizedBox(height: 12),
              _referenceSelect(
                'بند الصرف',
                _categoryId,
                widget.expenseOptions?.categories ?? const [],
                (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 12),
              _select(
                label: 'اتجاه التكلفة',
                value: _costDirection,
                options: const {
                  'ADMINISTRATION': 'إدارة',
                  'CUSTODY': 'عهدة',
                  'PROJECTS': 'مشروعات',
                  'SNAGLIST': 'عقبات',
                },
                onChanged: (value) => setState(() => _costDirection = value!),
              ),
              const SizedBox(height: 14),
              const _Label('نوع المستند'),
              AppSegmented<String>(
                value: _evidenceType,
                options: const [
                  ('CONTRACTOR', 'مقاول', LucideIcons.users),
                  ('INVOICE', 'فاتورة', LucideIcons.receipt),
                ],
                onChanged: (value) => setState(() {
                  _evidenceType = value;
                  _contractorId = null;
                  _invoices = const [];
                }),
              ),
              const SizedBox(height: 12),
              if (_evidenceType == 'CONTRACTOR')
                _referenceSelect(
                  'المقاول',
                  _contractorId,
                  widget.expenseOptions?.contractors ?? const [],
                  (value) => setState(() => _contractorId = value),
                )
              else
                OutlinedButton.icon(
                  onPressed: () async {
                    final images = await pickInvoiceImages(context);
                    if (mounted && images.isNotEmpty) {
                      setState(() => _invoices = images);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(LucideIcons.images, size: 18),
                  label: Text(
                    _invoices.isEmpty
                        ? 'اختيار صور الفواتير'
                        : '${_invoices.length} صورة مرفقة',
                  ),
                ),
              const SizedBox(height: 12),
            ],
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: _saving
                  ? null
                  : () async {
                      final picked = await showAppDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(_entryDate) ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _entryDate = formatIsoDate(picked));
                      }
                    },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'التاريخ *',
                  suffixIcon: Icon(LucideIcons.calendarDays, size: 18),
                ),
                child: Text(shortDate(_entryDate)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              textAlign: TextAlign.right,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: _directExpense || _return
                    ? 'البيان *'
                    : 'البيان (اختياري)',
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  (_directExpense || _return) &&
                      (value == null || value.trim().isEmpty)
                  ? 'البيان مطلوب'
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _select({
    required String label,
    required String? value,
    required Map<String, String> options,
    required ValueChanged<String?> onChanged,
    bool allowEmpty = false,
  }) => AppSelect<String>(
    label: label,
    value: value ?? (allowEmpty ? '' : null),
    options: [
      if (allowEmpty) const AppSelectOption(value: '', label: 'بدون تحديد'),
      for (final item in options.entries)
        AppSelectOption(value: item.key, label: item.value),
    ],
    onChanged: (selected) =>
        onChanged(selected?.isEmpty == true ? null : selected),
  );

  Widget _referenceSelect(
    String label,
    String? value,
    List<ExpenseReference> options,
    ValueChanged<String?> onChanged, {
    bool required = true,
  }) => AppSelect<String>(
    label: label,
    value: value ?? (!required ? '' : null),
    options: [
      if (!required) const AppSelectOption(value: '', label: 'بدون تحديد'),
      for (final item in options)
        AppSelectOption(value: item.id, label: item.name, subtitle: item.code),
    ],
    onChanged: (selected) =>
        onChanged(selected?.isEmpty == true ? null : selected),
    validator: required
        ? (value) => value == null ? 'هذا الحقل مطلوب' : null
        : null,
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
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

class _TypeChoice extends StatelessWidget {
  const _TypeChoice({
    required this.type,
    required this.current,
    required this.onTap,
    this.enabled = true,
  });
  final String type;
  final String current;
  final ValueChanged<String> onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final selected = type == current;
    return Material(
      color: selected ? tokens.wash : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? tokens.brand : tokens.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: enabled ? () => onTap(type) : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _typeIcon(type),
                size: 20,
                color: !enabled
                    ? tokens.line
                    : selected
                    ? tokens.brandStrong
                    : _typeColor(type),
              ),
              const SizedBox(height: 5),
              Text(
                _typeLabel(type),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: enabled ? tokens.ink : tokens.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _depositKinds = {
  'PROJECT_INFLOW': 'وارد مشروع',
  'FEES': 'أتعاب',
  'OPENING_BALANCE': 'رصيد افتتاحي',
  'ADVANCE_RECOVERY': 'سلفة مستردة',
  'LOAN_PROCEEDS': 'متحصلات سلفة',
};

const _reversibleOperationKinds = {
  'DEPOSIT',
  'DIRECT_EXPENSE',
  'TREASURY_TRANSFER',
  'CORRECTION',
};

String _depositKindLabel(String kind) => _depositKinds[kind] ?? kind;

String _tabLabel(_TreasuryTab tab) => switch (tab) {
  _TreasuryTab.movements => 'حركات الخزنة',
  _TreasuryTab.ledger => 'كشف الحساب',
  _TreasuryTab.loans => 'السلف بين الشركات',
  _TreasuryTab.contributions => 'المساهمات',
};

String _typeLabel(String type) => switch (type) {
  'DEPOSIT' => 'إيداع بالخزنة',
  'DIRECT_EXPENSE' => 'صرف مباشر',
  'TREASURY_TRANSFER' => 'تحويل بين الخزن',
  'CUSTODY_FUNDING' => 'تحويل إلى عهدة',
  'CUSTODY_RETURN' => 'رد إلى الخزنة',
  'CORRECTION' => 'تصحيح رصيد',
  _ => type,
};

/// Money entering the treasury reads +, money leaving reads −.
String _typeSign(String type) => switch (type) {
  'DEPOSIT' || 'CUSTODY_RETURN' => '+',
  'CORRECTION' => '',
  _ => '−',
};

IconData _typeIcon(String type) => switch (type) {
  'DEPOSIT' => LucideIcons.arrowDownLeft,
  'DIRECT_EXPENSE' => LucideIcons.receipt,
  'TREASURY_TRANSFER' => LucideIcons.arrowLeftRight,
  'CUSTODY_FUNDING' => LucideIcons.wallet,
  'CUSTODY_RETURN' => LucideIcons.undo2,
  'CORRECTION' => LucideIcons.scale,
  _ => LucideIcons.landmark,
};

Color _typeColor(String type) => switch (type) {
  'DEPOSIT' || 'CUSTODY_RETURN' => AppTokens.success,
  'TREASURY_TRANSFER' || 'CUSTODY_FUNDING' => AppTokens.info,
  'CORRECTION' => AppTokens.warning,
  _ => AppTokens.danger,
};

AppTag _statusTag(String status) => switch (status) {
  'PENDING' => const AppTag(
    'بانتظار الموافقة',
    tone: AppTone.warning,
    icon: LucideIcons.clock,
  ),
  'EXECUTED' => const AppTag(
    'معتمدة',
    tone: AppTone.success,
    icon: LucideIcons.check,
  ),
  'REJECTED' => const AppTag(
    'مرفوضة',
    tone: AppTone.danger,
    icon: LucideIcons.x,
  ),
  'REVERSED' => const AppTag('معكوسة', icon: LucideIcons.undo2),
  _ => AppTag(status),
};

String _statusLabel(String status) => switch (status) {
  'PENDING' => 'بانتظار الموافقة',
  'EXECUTED' => 'معتمدة',
  'REJECTED' => 'مرفوضة',
  'REVERSED' => 'معكوسة',
  _ => status,
};

String _methodLabel(String method) => switch (method) {
  'CASH' => 'كاش',
  'BANK_TRANSFER' => 'تحويل بنكي',
  'CHEQUE' => 'شيك',
  _ => method,
};

String _ledgerTypeLabel(String type) => switch (type) {
  'DEPOSIT' => 'إيداع خارجي',
  'DIRECT_EXPENSE' => 'مصروف مباشر',
  'TREASURY_TRANSFER' => 'تحويل بين الخزن',
  'CUSTODY_FUNDING' => 'تمويل عهدة',
  'CUSTODY_RETURN' => 'رد عهدة',
  'CUSTODY_TRANSFER' => 'تحويل عهدة',
  'CUSTODY_EXPENSE' => 'مصروف عهدة',
  'EXPENSE_REVERSAL' => 'عكس مصروف',
  'CORRECTION' => 'تصحيح',
  _ => type,
};

AppTag _loanTag(String status) => switch (status) {
  'ACTIVE' => const AppTag('قائمة', tone: AppTone.info),
  'PARTIALLY_REPAID' => const AppTag('مسددة جزئيًا', tone: AppTone.warning),
  'SETTLED' => const AppTag('مسددة بالكامل', tone: AppTone.success),
  'REVERSED' => const AppTag('معكوسة'),
  _ => AppTag(status),
};

AppTag _intercompanyTag(String status) => switch (status) {
  'REQUESTED' => const AppTag('بانتظار الإرسال', tone: AppTone.warning),
  'IN_TRANSIT' => const AppTag('في الطريق', tone: AppTone.info),
  'EXECUTED' => const AppTag('وصل', tone: AppTone.success),
  'RETURNED' => const AppTag('لم يصل', tone: AppTone.danger),
  'REVERSED' => const AppTag('معكوس'),
  'REJECTED' => const AppTag('مرفوض', tone: AppTone.danger),
  'CANCELLED' => const AppTag('ملغى'),
  _ => AppTag(status),
};
