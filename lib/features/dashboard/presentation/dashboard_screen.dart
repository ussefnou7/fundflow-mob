import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_refresh_page.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/domain/custody_models.dart' show money;
import '../../custody/presentation/custody_widgets.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_models.dart';

/// Shell page labels the board opens; they must match the drawer's labels.
abstract final class BoardTargets {
  static const approvals = 'طلبات الموافقة';
  static const custodyRequests = 'طلبات العهدة';
  static const aggregateCustody = 'مجمع العهد';
  static const treasuries = 'الخزن';
  static const extracts = 'المستخلصات';
  static const purchaseRequests = 'طلبات الشراء';
  static const purchaseOrders = 'أوامر الشراء';
  static const receipts = 'أوامر الاستلام';
  static const cashPurchases = 'الفواتير النقدية';
  static const leads = 'العملاء';
  static const inspections = 'المعاينات';
  static const followUps = 'متابعات اليوم';
  static const meetings = 'الاجتماعات';
}

const _months = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

String _whole(String value) => money(value).replaceFirst(RegExp(r'\.00$'), '');

String _compact(double value) {
  String trim(double v) =>
      v.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  if (value >= 1e6) return '${trim(value / 1e6)}M';
  if (value >= 1e3) return '${trim(value / 1e3)}K';
  return trim(value);
}

/// لوحة المتابعة: each section is drawn only when the API returns it, which is
/// when the viewer holds the permission of the screen it summarises.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.onOpen,
  });
  final DashboardRepository repository;
  final ValueChanged<String> onOpen;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  FollowUpBoard? _board;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final board = await widget.repository.load();
      if (mounted) setState(() => _board = board);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    final open = widget.onOpen;
    return AppRefreshPage(
      onRefresh: _load,
      children: [
        const PageHeader(title: 'لوحة المتابعة'),
        const SizedBox(height: AppSpace.md),
        if (_error != null)
          MessagePanel(message: _error!, onRetry: _load)
        else if (board == null)
          const Padding(
            padding: EdgeInsets.all(AppSpace.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (board.liquidity != null)
            _LiquidityHero(
              liquidity: board.liquidity!,
              today: board.today,
              onOpen: open,
            ),
          _Inbox(items: board.inbox, onOpen: open),
          if (board.alerts.isNotEmpty)
            _Alerts(alerts: board.alerts, onOpen: open),
          if (board.liquidity?.treasuries != null)
            _Treasuries(rows: board.liquidity!.treasuries!, onOpen: open),
          if (board.payables != null)
            _PayablesCard(payables: board.payables!, onOpen: open),
          if (board.purchasing != null)
            _PurchasingSection(purchasing: board.purchasing!, onOpen: open),
          if (board.custodyExpenseTrend != null)
            _TrendSection(
              trend: board.custodyExpenseTrend!,
              today: board.today,
            ),
          if (board.crm != null) _CrmSection(crm: board.crm!, onOpen: open),
          const SizedBox(height: AppSpace.lg),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- shared pieces

class _SectionHead extends StatelessWidget {
  const _SectionHead(this.title, {this.meta, this.link, this.onLink});
  final String title;
  final String? meta;
  final String? link;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: tokens.ink,
              ),
            ),
          ),
          if (meta != null)
            Text(
              meta!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tokens.muted,
              ),
            ),
          if (link != null) _LinkButton(label: link!, onTap: onLink),
        ],
      ),
    );
  }
}

/// «label ‹»: a small pill link in the page's own font, with the arrow pointing on.
class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.tokens.brand;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: brand,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronLeft, size: 14, color: brand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context, {Color? color}) =>
    BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.tokens.line),
      boxShadow: [
        BoxShadow(
          color: context.tokens.brandStrong.withValues(alpha: .035),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

enum _Tone { danger, warning, info, brand }

(Color, Color) _toneColors(BuildContext context, _Tone tone) => switch (tone) {
  _Tone.danger => (AppTokens.danger, AppTokens.dangerTint),
  _Tone.warning => (AppTokens.warning, AppTokens.warningTint),
  _Tone.info => (AppTokens.info, AppTokens.infoTint),
  _Tone.brand => (context.tokens.brand, context.tokens.wash),
};

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.tone});
  final IconData icon;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _toneColors(context, tone);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 16, color: fg),
    );
  }
}

class _Number extends StatelessWidget {
  const _Number(this.text, {this.size = 14, this.color, this.weight});
  final String text;
  final double size;
  final Color? color;
  final FontWeight? weight;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textDirection: TextDirection.ltr,
    style: TextStyle(
      fontSize: size,
      fontWeight: weight ?? FontWeight.w800,
      color: color ?? context.tokens.brandStrong,
      height: 1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

/// Lays children two per row; a lone last child takes the whole row.
class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final pair = children.skip(i).take(2).toList();
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpace.xs),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: pair[0]),
                if (pair.length > 1) ...[
                  const SizedBox(width: AppSpace.xs),
                  Expanded(child: pair[1]),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

// ---------------------------------------------------------------- liquidity

class _LiquidityHero extends StatefulWidget {
  const _LiquidityHero({
    required this.liquidity,
    required this.today,
    required this.onOpen,
  });
  final Liquidity liquidity;
  final String today;
  final ValueChanged<String> onOpen;

  @override
  State<_LiquidityHero> createState() => _LiquidityHeroState();
}

class _LiquidityHeroState extends State<_LiquidityHero> {
  bool _hidden = false;

  String _mask(String value) => _hidden ? '••••••' : value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l = widget.liquidity;
    const soft = Color(0xB8FFFFFF);
    final totals = l.treasuryTotals;
    final day = int.tryParse(
      widget.today.length >= 10 ? widget.today.substring(8, 10) : '',
    );
    final month = int.tryParse(
      widget.today.length >= 7 ? widget.today.substring(5, 7) : '',
    );
    final tiles = <Widget>[
      if (l.custody != null)
        _HeroTile(
          label: 'العهد لدى الموظفين',
          icon: LucideIcons.wallet,
          value: _mask(_firstAmount(l.custody!.balances)),
          note: '${l.custody!.holders} عهدة نشطة',
          onTap: () => widget.onOpen(BoardTargets.aggregateCustody),
        ),
      if (l.monthCustodyExpenses != null)
        _HeroTile(
          label: 'مصروفات العهد',
          icon: LucideIcons.receipt,
          value: _mask(_firstAmount(l.monthCustodyExpenses!)),
          note: month == null || day == null
              ? null
              : '${_months[month - 1]} حتى يوم $day',
          onTap: () => widget.onOpen(BoardTargets.aggregateCustody),
        ),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  totals != null ? 'السيولة المتاحة في الخزائن' : 'السيولة',
                  style: const TextStyle(
                    color: soft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: _hidden ? 'إظهار المبالغ' : 'إخفاء المبالغ',
                onPressed: () => setState(() => _hidden = !_hidden),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .08),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(36, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                icon: Icon(
                  _hidden ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 18,
                ),
              ),
            ],
          ),
          if (totals != null) ...[
            InkWell(
              onTap: () => widget.onOpen(BoardTargets.treasuries),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, total)
                      in (totals.isEmpty
                              ? const [
                                  CurrencyAmount(
                                    code: '',
                                    arabicCode: '',
                                    amount: '0',
                                  ),
                                ]
                              : totals)
                          .indexed)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        _Number(
                          _mask(_whole(total.amount)),
                          size: i == 0 ? 36 : 17,
                          color: Colors.white,
                          weight: i == 0 ? FontWeight.w800 : FontWeight.w700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          total.arabicCode,
                          style: const TextStyle(
                            color: soft,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (tiles.isNotEmpty) _TwoColumns(children: tiles),
        ],
      ),
    );
  }

  static String _firstAmount(List<CurrencyAmount> rows) =>
      _whole(rows.isEmpty ? '0' : rows.first.amount);
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    this.note,
  });
  final String label;
  final IconData icon;
  final String value;
  final String? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .07),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: Colors.white.withValues(alpha: .09)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: const Color(0xFF8FE0B4)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xB8FFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            _Number(
              value,
              size: 16,
              color: Colors.white,
              weight: FontWeight.w700,
            ),
            if (note != null)
              Text(
                note!,
                style: const TextStyle(
                  color: Color(0xFFF5C38A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- required actions

class _Inbox extends StatelessWidget {
  const _Inbox({required this.items, required this.onOpen});
  final List<InboxItem> items;
  final ValueChanged<String> onOpen;

  static const _meta = <String, (String, IconData, _Tone, String)>{
    'APPROVALS': (
      'اعتمادات معلقة',
      LucideIcons.shieldCheck,
      _Tone.danger,
      BoardTargets.approvals,
    ),
    'MEASUREMENTS_PENDING': (
      'حصر بانتظار الاعتماد',
      LucideIcons.ruler,
      _Tone.warning,
      BoardTargets.approvals,
    ),
    'APPROVALS_TO_COMPLETE': (
      'مستندات معتمدة بانتظار الإتمام',
      LucideIcons.clipboardCheck,
      _Tone.info,
      BoardTargets.approvals,
    ),
    'CUSTODY_REQUESTS_UNPAID': (
      'طلبات عهدة غير مصروفة',
      LucideIcons.wallet,
      _Tone.warning,
      BoardTargets.custodyRequests,
    ),
    'PURCHASE_REQUESTS_WITHOUT_ORDER': (
      'طلبات شراء بلا أمر شراء',
      LucideIcons.shoppingCart,
      _Tone.warning,
      BoardTargets.purchaseRequests,
    ),
    'ORDERS_AWAITING_RECEIPT': (
      'أوامر شراء بانتظار الاستلام',
      LucideIcons.packageCheck,
      _Tone.info,
      BoardTargets.receipts,
    ),
    'FOLLOW_UPS_DUE': (
      'متابعات مستحقة',
      LucideIcons.userRoundCheck,
      _Tone.info,
      BoardTargets.followUps,
    ),
    'INSPECTIONS_TODAY': (
      'معاينات اليوم',
      LucideIcons.house,
      _Tone.brand,
      BoardTargets.inspections,
    ),
    'MEETINGS_TODAY': (
      'اجتماعات اليوم',
      LucideIcons.calendarDays,
      _Tone.brand,
      BoardTargets.meetings,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final shown = items
        .where((i) => _meta.containsKey(i.kind))
        .where((i) => i.kind == 'APPROVALS' || i.count > 0)
        .toList();
    final total = items.fold<int>(0, (sum, i) => sum + i.count);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead(
          'الإجراءات المطلوبة',
          meta: total == 0 ? 'لا توجد إجراءات مطلوبة' : '$total بندًا',
        ),
        _TwoColumns(
          children: [
            for (final item in shown)
              _ActionCard(
                item: item,
                meta: _meta[item.kind]!,
                onTap: () => onOpen(_meta[item.kind]!.$4),
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.item,
    required this.meta,
    required this.onTap,
  });
  final InboxItem item;
  final (String, IconData, _Tone, String) meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: _cardDecoration(context),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Count and icon share the first row; the label sits under them.
                Row(
                  children: [
                    Expanded(child: _Number('${item.count}', size: 22)),
                    _Tile(icon: meta.$2, tone: meta.$3),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  meta.$1,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
                if (item.amount != null)
                  _Number(
                    _whole(item.amount!),
                    size: 11,
                    color: tokens.muted,
                    weight: FontWeight.w600,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- alerts

class _Alerts extends StatelessWidget {
  const _Alerts({required this.alerts, required this.onOpen});
  final List<BoardAlert> alerts;
  final ValueChanged<String> onOpen;

  (String, String, String)? _text(BoardAlert a) => switch (a.kind) {
    'STALE_CUSTODY' => (
      '${a.count} عهدة دون تصفية منذ 7 أيام أو أكثر',
      a.subject == null
          ? ''
          : 'أقدمها: ${a.subject}${a.days == null ? '' : ' — ${a.days} يومًا'}',
      BoardTargets.aggregateCustody,
    ),
    'OVERDUE_EXTRACTS' => (
      '${a.count} مستخلص مقاول معتمد منذ 30 يومًا أو أكثر',
      a.amount == null ? '' : 'بإجمالي ${_whole(a.amount!)} دون سداد',
      BoardTargets.extracts,
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final rows = [
      for (final a in alerts)
        if (_text(a) case final text?) (a, text),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead('تنبيهات', meta: '${rows.length}'),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: _cardDecoration(context),
          child: Material(
            color: Colors.white,
            child: Column(
              children: [
                for (final (i, (alert, text)) in rows.indexed) ...[
                  if (i > 0) Divider(height: 1, color: tokens.line),
                  InkWell(
                    onTap: () => onOpen(text.$3),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: alert.level == 'DANGER'
                                  ? AppTokens.dangerTint
                                  : AppTokens.warningTint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '!',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: alert.level == 'DANGER'
                                    ? AppTokens.danger
                                    : AppTokens.warning,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text.$1,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.ink,
                                  ),
                                ),
                                if (text.$2.isNotEmpty)
                                  Text(
                                    text.$2,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: tokens.muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            LucideIcons.chevronLeft,
                            size: 16,
                            color: tokens.faint,
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
      ],
    );
  }
}

// ---------------------------------------------------------------- treasuries

class _Treasuries extends StatelessWidget {
  const _Treasuries({required this.rows, required this.onOpen});
  final List<TreasuryBalance> rows;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionHead(
        'أرصدة الخزائن',
        link: 'كل الخزائن',
        onLink: () => onOpen(BoardTargets.treasuries),
      ),
      AppDataTable<TreasuryBalance>(
        rows: rows,
        columns: const [
          AppTableColumn('الخزينة', 150),
          AppTableColumn('العملة', 64),
          AppTableColumn('الرصيد', 120, numeric: true),
        ],
        cells: (t) => [
          Text(
            t.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(t.arabicCode, style: TextStyle(color: context.tokens.muted)),
          _Number(_whole(t.balance), size: 13),
        ],
        onTap: (_) => onOpen(BoardTargets.treasuries),
        empty: const AppEmptyState(
          icon: LucideIcons.landmark,
          title: 'لا توجد خزائن نشطة',
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------- payables

class _PayablesCard extends StatelessWidget {
  const _PayablesCard({required this.payables, required this.onOpen});
  final Payables payables;
  final ValueChanged<String> onOpen;

  static const _ranges = {
    'UNDER_30': ('أقل من 30 يومًا', null),
    'FROM_30_TO_60': ('30 – 60 يومًا', Color(0xFFD69A4A)),
    'OVER_60': ('أكثر من 60 يومًا', AppTokens.danger),
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final total = double.tryParse(payables.total) ?? 0;
    Color colorOf(String range) => _ranges[range]?.$2 ?? tokens.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHead('المستحقات'),
        Container(
          decoration: _cardDecoration(context),
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'مستخلصات المقاولين غير المسددة',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: tokens.ink,
                      ),
                    ),
                  ),
                  _LinkButton(
                    label: 'التفاصيل',
                    onTap: () => onOpen(BoardTargets.extracts),
                  ),
                ],
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  _Number(_whole(payables.total), size: 26),
                  Text(
                    '${payables.extracts} مستخلص · ${payables.contractors} مقاول',
                    style: TextStyle(fontSize: 11.5, color: tokens.muted),
                  ),
                ],
              ),
              if (total > 0) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        for (final b in payables.aging)
                          if ((double.tryParse(b.amount) ?? 0) > 0)
                            Expanded(
                              flex: math.max(
                                1,
                                ((double.tryParse(b.amount) ?? 0) /
                                        total *
                                        1000)
                                    .round(),
                              ),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                color: colorOf(b.range),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (i, b) in payables.aging.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.sunken,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: colorOf(b.range),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    _ranges[b.range]?.$1 ?? b.range,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            _Number(
                              _whole(b.amount),
                              size: 13.5,
                              color: tokens.ink,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tokens.sunken,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.line),
          ),
          child: Row(
            children: [
              const _Tile(icon: LucideIcons.fileText, tone: _Tone.info),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مستخلصات العملاء غير المحصلة',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                    ),
                    Text(
                      'تظهر بعد اكتمال عقود العملاء ومستخلصاتهم',
                      style: TextStyle(fontSize: 11, color: tokens.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- mini figure cards

class _Mini extends StatelessWidget {
  const _Mini({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final _Tone tone;
  final String value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Ink(
      decoration: _cardDecoration(context),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              _Tile(icon: icon, tone: tone),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Number(value, size: 17),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.tokens.muted,
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

class _PurchasingSection extends StatelessWidget {
  const _PurchasingSection({required this.purchasing, required this.onOpen});
  final Purchasing purchasing;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionHead(
        'المشتريات والمخازن',
        link: 'أوامر الشراء',
        onLink: () => onOpen(BoardTargets.purchaseOrders),
      ),
      _TwoColumns(
        children: [
          _Mini(
            icon: LucideIcons.packageCheck,
            tone: _Tone.info,
            value: '${purchasing.openOrders}',
            label: 'بانتظار الاستلام',
            onTap: () => onOpen(BoardTargets.receipts),
          ),
          _Mini(
            icon: LucideIcons.shieldCheck,
            tone: _Tone.warning,
            value: '${purchasing.ordersAwaitingApproval}',
            label: 'بانتظار الاعتماد',
            onTap: () => onOpen(BoardTargets.purchaseOrders),
          ),
          if (purchasing.monthCashPurchases != null)
            _Mini(
              icon: LucideIcons.wallet,
              tone: _Tone.brand,
              value: _whole(purchasing.monthCashPurchases!),
              label: 'مشتريات نقدية هذا الشهر',
              onTap: () => onOpen(BoardTargets.cashPurchases),
            ),
        ],
      ),
    ],
  );
}

class _CrmSection extends StatelessWidget {
  const _CrmSection({required this.crm, required this.onOpen});
  final CrmSummary crm;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionHead(
        'العملاء المحتملون',
        link: 'كل العملاء',
        onLink: () => onOpen(BoardTargets.leads),
      ),
      _TwoColumns(
        children: [
          _Mini(
            icon: LucideIcons.users,
            tone: _Tone.brand,
            value: '${crm.newLeadsThisWeek}',
            label: 'جديد هذا الأسبوع',
            onTap: () => onOpen(BoardTargets.leads),
          ),
          _Mini(
            icon: LucideIcons.calendarDays,
            tone: _Tone.info,
            value: '${crm.upcomingInspections}',
            label: 'معاينة قادمة',
            onTap: () => onOpen(BoardTargets.inspections),
          ),
          _Mini(
            icon: LucideIcons.clock,
            tone: _Tone.danger,
            value: '${crm.overdueFollowUps}',
            label: 'متابعة متأخرة',
            onTap: () => onOpen(BoardTargets.followUps),
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------- custody expense trend

class _TrendSection extends StatefulWidget {
  const _TrendSection({required this.trend, required this.today});
  final List<MonthTotal> trend;
  final String today;

  @override
  State<_TrendSection> createState() => _TrendSectionState();
}

class _TrendSectionState extends State<_TrendSection> {
  int? _selected;

  static const _axis = 36.0;
  static const _plotHeight = 150.0;

  /// A clean top for the axis: 1, 2, 2.5 or 5 times a power of ten, in 4 steps.
  static double _niceTop(double max) {
    if (max <= 0) return 4;
    final raw = max / 4;
    final pow = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final step = [
      1,
      2,
      2.5,
      5,
      10,
    ].map((m) => m * pow).firstWhere((m) => m >= raw);
    return step * 4;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final trend = widget.trend;
    final first = trend.expand((m) => m.totals).firstOrNull;
    final code = first?.code;
    final values = [
      for (final m in trend)
        double.tryParse(
              m.totals.where((t) => t.code == code).firstOrNull?.amount ?? '0',
            ) ??
            0,
    ];
    final empty = values.every((v) => v == 0);
    final last = trend.length - 1;
    final day = widget.today.length >= 10
        ? int.tryParse(widget.today.substring(8, 10))
        : null;
    final complete = values.take(math.max(0, last)).toList();
    final average = complete.isEmpty
        ? 0.0
        : complete.reduce((a, b) => a + b) / complete.length;
    final top = _niceTop(values.fold(0.0, math.max));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead('مصروفات العهد — آخر 6 شهور', meta: first?.arabicCode),
        Container(
          decoration: _cardDecoration(context),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: empty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'لا توجد مصروفات عهد معتمدة في آخر 6 شهور',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: tokens.muted),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _Kpi(
                            label:
                                '${_months[trend[last].month - 1]}${day == null ? '' : ' حتى يوم $day'}',
                            value: _whole(values[last].toStringAsFixed(2)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Kpi(
                            label: 'متوسط الشهور المكتملة',
                            value: _whole(average.toStringAsFixed(2)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: _plotHeight,
                      child: LayoutBuilder(
                        builder: (context, box) => _plot(
                          context,
                          box.maxWidth,
                          values,
                          top,
                          average,
                          last,
                          day,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: _axis),
                      child: Row(
                        children: [
                          for (final (i, m) in trend.indexed)
                            Expanded(
                              child: Text(
                                _months[m.month - 1],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: i == last
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  color: i == last
                                      ? tokens.brandStrong
                                      : tokens.muted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _plot(
    BuildContext context,
    double width,
    List<double> values,
    double top,
    double average,
    int last,
    int? day,
  ) {
    final tokens = context.tokens;
    final trend = widget.trend;
    final columnWidth = (width - _axis) / trend.length;
    double y(double v) => v / top * _plotHeight;
    final selected = _selected;
    // RTL: column i is laid from the right edge, after the axis.
    double centreFromRight(int i) => _axis + (i + .5) * columnWidth;
    final label = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: tokens.muted,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var k = 0; k <= 4; k++)
          Positioned(
            left: 0,
            right: 0,
            bottom: y(top / 4 * k),
            child: Container(
              height: 1,
              color: k == 0 ? tokens.line : tokens.line.withValues(alpha: .55),
            ),
          ),
        for (var k = 0; k <= 4; k++)
          Positioned(
            right: 0,
            bottom: y(top / 4 * k) - 7,
            child: Text(k == 0 ? '0' : _compact(top / 4 * k), style: label),
          ),
        if (average > 0)
          Positioned(
            left: 0,
            right: _axis,
            bottom: y(average),
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DashedLine(tokens.brandStrong.withValues(alpha: .35)),
            ),
          ),
        if (average > 0)
          Positioned(
            left: 0,
            bottom: y(average) + 2,
            child: Text(
              'المتوسط',
              style: label.copyWith(
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
          ),
        Positioned.fill(
          right: _axis,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, v) in values.indexed)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        setState(() => _selected = _selected == i ? null : i),
                    child: Semantics(
                      button: true,
                      label:
                          '${_months[trend[i].month - 1]} ${trend[i].year}: ${_whole(v.toStringAsFixed(2))}',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (i == last)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: _Number(_compact(v), size: 10.5),
                            ),
                          _Bar(
                            height: math.max(v > 0 ? 2 : 0, y(v)),
                            partial: i == last,
                            active: selected == i,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (selected != null)
          Positioned(
            // Columns in the left half open their tooltip to the right, into the chart.
            right: selected < values.length / 2
                ? centreFromRight(selected) + 14
                : null,
            left: selected >= values.length / 2
                ? width - centreFromRight(selected) + 14
                : null,
            bottom: math.max(0, y(values[selected]) - 26),
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: tokens.brandStrong,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .25),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_months[trend[selected].month - 1]} ${trend[selected].year}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xBFFFFFFF),
                      ),
                    ),
                    _Number(
                      _whole(values[selected].toStringAsFixed(2)),
                      size: 13,
                      color: Colors.white,
                    ),
                    if (selected == last)
                      Text(
                        'الشهر الجاري${day == null ? '' : ' — حتى يوم $day'}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF5C38A),
                        ),
                      )
                    else if (selected > 0 && values[selected - 1] > 0)
                      Text(
                        '${_signedPercent(values[selected], values[selected - 1])} عن ${_months[trend[selected - 1].month - 1]}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF5C38A),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _signedPercent(double now, double before) {
    final pct = ((now - before) / before * 100).round();
    return '${pct > 0 ? '+' : ''}$pct%';
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: context.tokens.sunken,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: context.tokens.muted,
          ),
        ),
        _Number(value, size: 15),
      ],
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.height,
    required this.partial,
    required this.active,
  });
  final double height;
  final bool partial;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final fill = active
        ? tokens.brandStrong
        : tokens.brand.withValues(alpha: .78);
    return AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.feedback),
      width: 18,
      height: height,
      decoration: BoxDecoration(
        color: partial ? null : fill,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        border: partial ? Border.all(color: fill, width: 1.5) : null,
      ),
      // The running month is hatched: it is not over, so it must not read as a fall.
      child: partial
          ? ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(3),
              ),
              child: CustomPaint(painter: _Hatch(fill, tokens.washStrong)),
            )
          : null,
    );
  }
}

class _Hatch extends CustomPainter {
  _Hatch(this.stripe, this.ground);
  final Color stripe;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    final paint = Paint()
      ..color = stripe
      ..strokeWidth = 3;
    for (var x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Hatch old) =>
      old.stripe != stripe || old.ground != ground;
}

class _DashedLine extends CustomPainter {
  _DashedLine(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + 4, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLine old) => old.color != color;
}
