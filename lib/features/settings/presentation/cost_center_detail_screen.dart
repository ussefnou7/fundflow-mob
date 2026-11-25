import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/format/arabic_search.dart';
import '../../../core/format/exact_decimal.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_filter.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../../extracts/domain/extract_models.dart';
import '../../extracts/presentation/contractor_extract_screen.dart';
import '../data/settings_repository.dart';
import '../domain/cost_center_financial_detail.dart';
import 'settings_widgets.dart';

/// The single cost centre file, as on the web: what the client owes, what the
/// contractors are owed, the cash and the profit, then a tab for each. Every
/// figure comes from the server. The phone only reads; the contract is edited
/// on the web.
class CostCenterDetailScreen extends StatefulWidget {
  const CostCenterDetailScreen({
    super.key,
    required this.repository,
    required this.centerId,
    required this.onBack,
    this.canViewContract = false,
    this.onEdit,
  });

  final SettingsRepository repository;
  final String centerId;
  final VoidCallback onBack;

  /// CLIENT_CONTRACT_VIEW: the contract tab and its card.
  final bool canViewContract;

  /// Opens the centre's edit sheet; true when it saved.
  final Future<bool> Function()? onEdit;

  @override
  State<CostCenterDetailScreen> createState() => _CostCenterDetailScreenState();
}

enum _Tab { client, contract, contractors, extracts, snag, administrative }

class _CostCenterDetailScreenState extends State<CostCenterDetailScreen> {
  CostCenterFinancialDetail? _detail;
  _Tab? _tab;
  String? _error;
  bool _loading = true;

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
      final detail = await widget.repository.costCenterFinancial(
        widget.centerId,
      );
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    if (await widget.onEdit?.call() == true) await _load();
  }

  bool _showContract(CostCenterFinancialDetail detail) =>
      widget.canViewContract && detail.center.type != 'OFFICE';

  List<(_Tab, String, int)> _tabs(CostCenterFinancialDetail detail) => [
    if (detail.client != null)
      (_Tab.client, 'كشف حساب العميل', detail.client!.movements.length),
    if (_showContract(detail)) (_Tab.contract, 'العقد', 0),
    (_Tab.contractors, 'المقاولون', detail.contractors.items.length),
    (_Tab.extracts, 'مستخلصات المقاولين', detail.extracts.length),
    (_Tab.snag, 'الـ Snag', detail.snag.items.length),
    (
      _Tab.administrative,
      'المصروفات الإدارية',
      detail.administrative.items.length,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (_error != null && detail == null) {
      return ListView(
        padding: const EdgeInsets.all(AppSpace.md),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(LucideIcons.arrowRight, size: 17),
              label: const Text('مراكز التكلفة'),
            ),
          ),
          MessagePanel(message: _error!, onRetry: _load),
        ],
      );
    }
    if (detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final center = detail.center;
    final tab =
        _tab ?? (detail.client != null ? _Tab.client : _Tab.contractors);
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
          AccountHero(
            title: center.name,
            subtitle:
                '${center.code} · ${center.type == 'OFFICE' ? 'مكتب' : 'مشروع'}',
            backTooltip: 'العودة لمراكز التكلفة',
            onBack: widget.onBack,
            active: center.active,
            metrics: const [],
            onEdit: widget.onEdit == null ? null : _edit,
            editTooltip: 'تعديل مركز التكلفة',
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: 12),
          _SummaryCards(
            detail: detail,
            showContract: _showContract(detail),
            onOpen: (target) => setState(() => _tab = target),
          ),
          const SizedBox(height: 16),
          LedgerTabs<_Tab>(
            value: tab,
            tabs: _tabs(detail),
            onChanged: (value) => setState(() => _tab = value),
          ),
          const SizedBox(height: 12),
          switch (tab) {
            _Tab.client => _ClientStatement(client: detail.client!),
            _Tab.contract => _ContractTab(
              repository: widget.repository,
              centerId: center.id,
            ),
            _Tab.contractors => _ContractorsTable(detail: detail),
            _Tab.extracts => _CenterExtracts(extracts: detail.extracts),
            _Tab.snag => _SnagTab(detail: detail),
            _Tab.administrative => _SpendingTable(
              lines: detail.administrative.items,
              empty: 'لا توجد مصروفات إدارية على هذا المركز',
            ),
          },
        ],
      ),
    );
  }
}

String _money(String value) => accountMoney(value);
String _abs(String value) => accountMoney(value.replaceFirst('-', ''));
bool _negative(String value) =>
    (ExactDecimal.tryParse(value) ?? ExactDecimal.zero).compareTo(
      ExactDecimal.zero,
    ) <
    0;
bool _zero(String value) =>
    (ExactDecimal.tryParse(value) ?? ExactDecimal.zero).compareTo(
      ExactDecimal.zero,
    ) ==
    0;

String _date(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value.isEmpty ? '—' : value;
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

Widget _amount(String value, {bool strong = false, Color? color}) => Text(
  _money(value),
  textDirection: TextDirection.ltr,
  style: TextStyle(
    fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  ),
);

/// A card per question, then the side figures; each opens the tab behind it.
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({
    required this.detail,
    required this.showContract,
    required this.onOpen,
  });

  final CostCenterFinancialDetail detail;
  final bool showContract;
  final ValueChanged<_Tab> onOpen;

  @override
  Widget build(BuildContext context) {
    final client = detail.client;
    final owed = detail.clientOwed;
    final cashShort = _negative(detail.actual.difference);
    final contract = detail.contract;
    final overContract = contract != null && _negative(contract.remaining);
    final profits = detail.profits;
    final cards = <Widget>[
      if (client != null && owed != null)
        _SummaryCard(
          title: 'العميل',
          icon: LucideIcons.userRound,
          value: _abs(owed),
          caption: _negative(owed) ? 'رصيد دائن للعميل' : 'مستحق على العميل',
          color: const Color(0xff287f8d),
          rows: [('المحمَّل', client.charged), ('المحصَّل', client.credited)],
          onTap: () => onOpen(_Tab.client),
        ),
      _SummaryCard(
        title: 'المقاولون',
        icon: LucideIcons.hardHat,
        value: _money(detail.contractors.debt),
        caption: 'مستحق للمقاولين',
        color: AppTokens.warning,
        rows: [
          ('المستحق', detail.contractors.due),
          ('المدفوع', detail.contractors.paid),
        ],
        onTap: () => onOpen(_Tab.contractors),
      ),
      _SummaryCard(
        title: 'النقدية',
        icon: LucideIcons.banknote,
        value: _abs(detail.actual.difference),
        caption: cashShort ? 'تمويل الشركة للمشروع' : 'صافي النقدية في المشروع',
        color: cashShort ? AppTokens.danger : AppTokens.success,
        rows: [
          ('الداخل', detail.actual.deposits),
          ('الخارج', detail.actual.spent),
        ],
      ),
      if (profits != null)
        _SummaryCard(
          title: 'الأرباح',
          icon: LucideIcons.trendingUp,
          value: _money(profits.total),
          caption: 'إجمالي الربح',
          color: const Color(0xff5b4bb7),
          rows: [
            ('الأتعاب', profits.fees),
            ('فرق الأسعار', profits.priceDifference),
            ('التوفير من المقاولين', profits.savings),
          ],
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final card in cards) SizedBox(width: width, child: card),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MiniCard(
              label: 'الـ Snag',
              icon: LucideIcons.triangleAlert,
              value: _zero(detail.snag.total) ? null : detail.snag.total,
              onTap: () => onOpen(_Tab.snag),
            ),
            _MiniCard(
              label: 'المصروفات الإدارية',
              icon: LucideIcons.building2,
              value: _zero(detail.administrative.total)
                  ? null
                  : detail.administrative.total,
              onTap: () => onOpen(_Tab.administrative),
            ),
            if (showContract)
              _MiniCard(
                label: contract == null
                    ? 'قيمة العقد'
                    : overContract
                    ? 'تجاوز قيمة العقد'
                    : 'المتبقي من العقد',
                icon: LucideIcons.fileText,
                value: contract?.remaining.replaceFirst('-', ''),
                emptyText: 'لا يوجد عقد',
                warning: overContract,
                onTap: () => onOpen(_Tab.contract),
              ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.caption,
    required this.color,
    required this.rows,
    this.onTap,
  });

  final String title, value, caption;
  final IconData icon;
  final Color color;
  final List<(String, String)> rows;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final radius = BorderRadius.circular(20);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .09),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Color.alphaBlend(color.withValues(alpha: .035), Colors.white),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: color.withValues(alpha: .22)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, size: 16, color: color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: tokens.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        LucideIcons.chevronLeft,
                        size: 15,
                        color: tokens.muted,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: color,
                    fontSize: 20.5,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  caption,
                  style: TextStyle(
                    color: tokens.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                for (final (label, amount) in rows)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: tokens.muted, fontSize: 12),
                          ),
                        ),
                        Text(
                          _money(amount),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
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

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    this.emptyText = 'لا يوجد',
    this.warning = false,
  });

  final String label, emptyText;
  final IconData icon;
  final String? value;
  final bool warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = warning ? AppTokens.danger : tokens.ink;
    return Material(
      color: warning ? AppTokens.danger.withValues(alpha: .06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: warning ? AppTokens.danger.withValues(alpha: .3) : tokens.line,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: warning ? color : tokens.muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: tokens.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value == null ? emptyText : _money(value!),
                textDirection: value == null ? null : TextDirection.ltr,
                style: TextStyle(
                  color: value == null ? tokens.muted : color,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.note});
  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        if (note != null)
          Text(
            note!,
            style: TextStyle(color: context.tokens.muted, fontSize: 11.5),
          ),
      ],
    ),
  );
}

class _ClientStatement extends StatelessWidget {
  const _ClientStatement({required this.client});
  final ClientAccount client;

  @override
  Widget build(BuildContext context) {
    if (client.movements.isEmpty) {
      return const AppDataTable<ClientMovement>(
        rows: [],
        columns: [],
        cells: _noCells,
        empty: AppEmptyState(
          icon: LucideIcons.receiptText,
          title: 'لا توجد حركات على حساب العميل',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading('الشهور'),
        AppDataTable(
          rows: client.months,
          columns: const [
            AppTableColumn('الشهر', 78),
            AppTableColumn('المحمَّل', 92, numeric: true),
            AppTableColumn('المغطّى', 92, numeric: true),
            AppTableColumn('الباقي', 92, numeric: true),
          ],
          cells: (month) => [
            Text(month.month, textDirection: TextDirection.ltr),
            _amount(month.charged),
            _amount(month.covered),
            _amount(month.remaining, strong: true),
          ],
        ),
        const SizedBox(height: 14),
        const _Heading('كشف الحركات'),
        AppDataTable<ClientMovement>(
          rows: client.movements,
          columns: const [
            AppTableColumn('التاريخ', 100),
            AppTableColumn('النوع', 140),
            AppTableColumn('البيان', 190),
            AppTableColumn('المحمَّل', 110, numeric: true),
            AppTableColumn('المحصَّل', 110, numeric: true),
            AppTableColumn('الرصيد', 120, numeric: true),
          ],
          cells: (line) => [
            Text(_date(line.date), textDirection: TextDirection.ltr),
            AppTableTitle(
              title: clientMovementKindLabels[line.kind] ?? line.kind,
              subtitle: line.shownReference,
            ),
            AppTableTitle(
              title: line.description?.isNotEmpty == true
                  ? line.description!
                  : '—',
              subtitle: line.party,
            ),
            _zero(line.charge) ? const Text('—') : _amount(line.charge),
            _zero(line.credit) ? const Text('—') : _amount(line.credit),
            _amount(line.balance, strong: true),
          ],
        ),
      ],
    );
  }
}

List<Widget> _noCells(Object? _) => const [];

class _ContractorsTable extends StatefulWidget {
  const _ContractorsTable({required this.detail});
  final CostCenterFinancialDetail detail;

  @override
  State<_ContractorsTable> createState() => _ContractorsTableState();
}

class _ContractorsTableState extends State<_ContractorsTable> {
  static const _size = 20;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final rows = widget.detail.contractors.items;
    final visible = rows
        .skip(_page * _size)
        .take(_size)
        .toList(growable: false);
    return Column(
      children: [
        AppDataTable<CenterContractorLine>(
          rows: visible,
          empty: const AppEmptyState(
            icon: LucideIcons.hardHat,
            title: 'لا يوجد مقاولون على هذا المركز',
          ),
          columns: const [
            AppTableColumn('المقاول', 160),
            AppTableColumn('المستحق', 110, numeric: true),
            AppTableColumn('المدفوع من الشركة', 120, numeric: true),
            AppTableColumn('المدفوع من العميل', 120, numeric: true),
            AppTableColumn('الرصيد المستحق', 120, numeric: true),
          ],
          cells: (line) => [
            Text(line.contractorName, maxLines: 2),
            _amount(line.due),
            _amount(line.paidByCompany),
            _amount(line.paidByClient),
            _amount(line.debt, strong: true),
          ],
        ),
        if (rows.length > _size) ...[
          const SizedBox(height: 10),
          AppPagination(
            page: _page,
            size: _size,
            total: rows.length,
            onChanged: (page) => setState(() => _page = page),
          ),
        ],
      ],
    );
  }
}

class _SpendingTable extends StatefulWidget {
  const _SpendingTable({required this.lines, required this.empty});
  final List<CenterSpendingLine> lines;
  final String empty;

  @override
  State<_SpendingTable> createState() => _SpendingTableState();
}

class _SpendingTableState extends State<_SpendingTable> {
  static const _size = 20;
  int _page = 0;

  @override
  void didUpdateWidget(covariant _SpendingTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.lines, widget.lines)) _page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.lines
        .skip(_page * _size)
        .take(_size)
        .toList(growable: false);
    return Column(
      children: [
        AppDataTable<CenterSpendingLine>(
          rows: visible,
          empty: AppEmptyState(icon: LucideIcons.receipt, title: widget.empty),
          columns: const [
            AppTableColumn('التاريخ', 100),
            AppTableColumn('المصدر', 80),
            AppTableColumn('البيان', 190),
            AppTableColumn('بند الصرف', 140),
            AppTableColumn('المبلغ', 110, numeric: true),
          ],
          cells: (line) => [
            Text(_date(line.date), textDirection: TextDirection.ltr),
            Text(centerSpendingSourceLabels[line.type] ?? line.type),
            Text(
              line.description?.isNotEmpty == true ? line.description! : '—',
              maxLines: 2,
            ),
            Text(line.categoryName ?? '—'),
            _amount(line.amount, strong: true),
          ],
        ),
        if (widget.lines.length > _size) ...[
          const SizedBox(height: 10),
          AppPagination(
            page: _page,
            size: _size,
            total: widget.lines.length,
            onChanged: (page) => setState(() => _page = page),
          ),
        ],
      ],
    );
  }
}

class _SnagTab extends StatelessWidget {
  const _SnagTab({required this.detail});
  final CostCenterFinancialDetail detail;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SpendingTable(
        lines: detail.snag.items,
        empty: 'لا توجد مصروفات Snag على هذا المركز',
      ),
      if (detail.snag.unmarked.isNotEmpty) ...[
        const SizedBox(height: 14),
        const _Heading(
          'اتجاهها Snag بلا علامة',
          note:
              'هذه المصروفات محمَّلة على العميل لأنها غير معلَّمة Snag. '
              'علِّمها من بند العهدة أو حركة الخزنة إن كانت على الشركة.',
        ),
        _SpendingTable(lines: detail.snag.unmarked, empty: ''),
      ],
    ],
  );
}

/// The client contract, read only; it is created and changed on the web.
class _ContractTab extends StatefulWidget {
  const _ContractTab({required this.repository, required this.centerId});
  final SettingsRepository repository;
  final String centerId;

  @override
  State<_ContractTab> createState() => _ContractTabState();
}

class _ContractTabState extends State<_ContractTab> {
  late Future<ClientContract?> _contract = widget.repository.clientContract(
    widget.centerId,
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<ClientContract?>(
    future: _contract,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return MessagePanel(
          message: snapshot.error.toString(),
          onRetry: () => setState(() {
            _contract = widget.repository.clientContract(widget.centerId);
          }),
        );
      }
      final contract = snapshot.data;
      if (contract == null) {
        return const AppDataTable<Object>(
          rows: [],
          columns: [],
          cells: _noCells,
          empty: AppEmptyState(
            icon: LucideIcons.fileText,
            title: 'لا يوجد عقد لهذا المشروع',
            message: 'يُسجَّل العقد من نسخة الويب.',
          ),
        );
      }
      final tokens = context.tokens;
      final advance = contract.advanceAmount == null
          ? '—'
          : '${_money(contract.advanceAmount!)}'
                '${contract.advancePercent == null ? '' : ' · ${contract.advancePercent}%'}';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'عقد رقم ${contract.contractNo}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'تاريخ العقد ${_date(contract.contractDate)}',
                            style: TextStyle(color: tokens.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    AppTag(
                      clientContractStatusLabels[contract.status] ??
                          contract.status,
                      tone: switch (contract.status) {
                        'ACTIVE' => AppTone.success,
                        'ENDED' => AppTone.neutral,
                        _ => AppTone.warning,
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final half = (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (label, value) in [
                          ('قيمة العقد', _money(contract.contractValue)),
                          ('الإضافات', _money(contract.additionsTotal)),
                          ('إجمالي العقد', _money(contract.totalValue)),
                          ('المقدَّم', advance),
                          ('البداية', _date(contract.fromDate)),
                          ('النهاية', _date(contract.toDate)),
                          ('المدة', '${contract.durationDays} يوم'),
                          ('صور العقد', '${contract.attachmentCount}'),
                        ])
                          SizedBox(
                            width: half,
                            child: _Fact(label: label, value: value),
                          ),
                      ],
                    );
                  },
                ),
                if (contract.terms?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    'الشروط',
                    style: TextStyle(
                      color: tokens.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(contract.terms!),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _Heading('ملاحق العقد'),
          AppDataTable(
            rows: contract.addenda,
            empty: const AppEmptyState(
              icon: LucideIcons.filePlus2,
              title: 'لا توجد ملاحق',
            ),
            columns: const [
              AppTableColumn('البيان', 190),
              AppTableColumn('القيمة', 110, numeric: true),
              AppTableColumn('أضافه', 120),
              AppTableColumn('التاريخ', 100),
            ],
            cells: (item) => [
              Text(item.description, maxLines: 2),
              _amount(item.amount, strong: true),
              Text(item.creatorName),
              Text(_date(item.createdAt), textDirection: TextDirection.ltr),
            ],
          ),
        ],
      );
    },
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: context.tokens.canvas,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: context.tokens.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.tokens.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ],
    ),
  );
}

/// The centre's extracts: search, status filter and the expandable cards
/// shared with the extracts screen.
class _CenterExtracts extends StatefulWidget {
  const _CenterExtracts({required this.extracts});
  final List<ContractorExtract> extracts;

  @override
  State<_CenterExtracts> createState() => _CenterExtractsState();
}

class _CenterExtractsState extends State<_CenterExtracts> {
  final _search = TextEditingController();
  String _status = '';
  String? _expandedId;
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ContractorExtract> get _filtered {
    final query = normalizeArabic(_search.text);
    return widget.extracts
        .where((extract) {
          if (_status.isNotEmpty && extract.status != _status) return false;
          if (query.isEmpty) return true;
          return normalizeArabic(extract.contractorName).contains(query) ||
              '${extract.extractNo}'.contains(query) ||
              extract.extractDate.contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _openFilters() async {
    final result = await showAppFilterSheet<(String, int)>(
      context: context,
      subtitle: 'مستخلصات المركز',
      initial: (_status, _pageSize),
      empty: ('', _pageSize),
      isActive: (draft) => draft.$1.isNotEmpty,
      fields: (context, draft, update) => AppFilterGrid(
        children: [
          AppSelect<String>(
            compact: true,
            label: 'الحالة',
            value: draft.$1,
            options: const [
              AppSelectOption(value: '', label: 'كل الحالات'),
              AppSelectOption(value: 'PENDING', label: 'بانتظار الاعتماد'),
              AppSelectOption(value: 'APPROVED', label: 'معتمد'),
              AppSelectOption(value: 'REJECTED', label: 'مرفوض'),
            ],
            onChanged: (value) => update((value ?? '', draft.$2)),
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
      _status = result.$1;
      _pageSize = result.$2;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final filtered = _filtered;
    final lastPage = filtered.isEmpty ? 0 : (filtered.length - 1) ~/ _pageSize;
    if (_page > lastPage) _page = lastPage;
    final visible = filtered
        .skip(_page * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          textAlign: TextAlign.right,
          onChanged: (_) => setState(() => _page = 0),
          decoration: InputDecoration(
            hintText: 'ابحث بالمقاول أو رقم المستخلص…',
            fillColor: Colors.white,
            prefixIcon: const Icon(LucideIcons.search, size: 19),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: tokens.line),
            ),
          ),
        ),
        const SizedBox(height: 10),
        AppFilterBar(
          activeCount: _status.isEmpty ? 0 : 1,
          summary: switch (_status) {
            'PENDING' => 'بانتظار الاعتماد',
            'APPROVED' => 'معتمد',
            'REJECTED' => 'مرفوض',
            _ => '',
          },
          onOpen: _openFilters,
          onClear: () => setState(() {
            _status = '';
            _page = 0;
          }),
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tokens.line),
            ),
            child: const AppEmptyState(
              icon: LucideIcons.fileSpreadsheet,
              title: 'لا توجد مستخلصات مطابقة',
            ),
          )
        else
          for (final extract in visible) ...[
            RepaintBoundary(
              child: ContractorExtractCard(
                extract: extract,
                expanded: _expandedId == extract.id,
                showFinancials: true,
                onToggle: () => setState(() {
                  _expandedId = _expandedId == extract.id ? null : extract.id;
                }),
                onPrice: () {},
                onReject: () {},
              ),
            ),
            const SizedBox(height: 10),
          ],
        AppPagination(
          page: _page,
          size: _pageSize,
          total: filtered.length,
          onChanged: (page) => setState(() => _page = page),
        ),
      ],
    );
  }
}
