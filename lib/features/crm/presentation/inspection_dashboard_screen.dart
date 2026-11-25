import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/time/server_clock.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../custody/domain/custody_models.dart' show money;
import '../../custody/presentation/custody_widgets.dart';
import '../data/crm_repository.dart';
import '../domain/crm_models.dart';
import 'inspection_detail_screen.dart';

class InspectionDashboardScreen extends StatefulWidget {
  const InspectionDashboardScreen({
    super.key,
    required this.repository,
    required this.permissions,
    this.onOpenAll,
  });

  final CrmRepository repository;
  final Set<String> permissions;
  final VoidCallback? onOpenAll;

  @override
  State<InspectionDashboardScreen> createState() =>
      _InspectionDashboardScreenState();
}

class _InspectionDashboardScreenState extends State<InspectionDashboardScreen> {
  CrmDashboardPeriod _period = CrmDashboardPeriod.today;
  CrmInspectionDashboard? _dashboard;
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
      final dashboard = await widget.repository.inspectionDashboard(_period);
      if (mounted) setState(() => _dashboard = dashboard);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openInspection(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionDetailScreen(
          repository: widget.repository,
          id: id,
          permissions: widget.permissions,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          const PageHeader(
            title: 'متابعة المعاينات',
            subtitle: 'نظرة سريعة على المواعيد والتنفيذ والتحصيل',
          ),
          const SizedBox(height: AppSpace.sm),
          AppSegmented<CrmDashboardPeriod>(
            value: _period,
            options: const [
              (CrmDashboardPeriod.today, 'اليوم', null),
              (CrmDashboardPeriod.week, 'الأسبوع', null),
              (CrmDashboardPeriod.month, 'الشهر', null),
            ],
            onChanged: _loading
                ? null
                : (period) {
                    if (period == _period) return;
                    setState(() => _period = period);
                    _load();
                  },
          ),
          const SizedBox(height: AppSpace.md),
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _load)
          else if (dashboard == null)
            const Padding(
              padding: EdgeInsets.all(AppSpace.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            AnimatedOpacity(
              opacity: _loading ? .55 : 1,
              duration: AppMotion.feedback,
              child: _DashboardBody(
                dashboard: dashboard,
                onOpenAll: widget.onOpenAll,
                onOpenInspection: _openInspection,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.dashboard,
    required this.onOpenInspection,
    this.onOpenAll,
  });
  final CrmInspectionDashboard dashboard;
  final ValueChanged<String> onOpenInspection;
  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context) {
    final kpis = dashboard.kpis;
    return Column(
      children: [
        _KpiGrid(kpis: kpis),
        const SizedBox(height: AppSpace.md),
        _ScheduleCard(
          rows: dashboard.today,
          onOpenAll: onOpenAll,
          onOpenInspection: onOpenInspection,
        ),
        const SizedBox(height: AppSpace.md),
        _StatusCard(statuses: dashboard.statuses),
        const SizedBox(height: AppSpace.md),
        _EngineersCard(engineers: dashboard.engineers),
        const SizedBox(height: AppSpace.md),
        _FinancialCard(financial: dashboard.financial),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis});
  final CrmDashboardKpis kpis;

  @override
  Widget build(BuildContext context) => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 2,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 1.68,
    children: [
      _KpiCard(
        label: 'معاينات الفترة',
        value: '${kpis.total}',
        icon: LucideIcons.calendarDays,
        color: context.tokens.brand,
        tint: context.tokens.wash,
      ),
      _KpiCard(
        label: 'تم التنفيذ',
        value: '${kpis.done}',
        icon: LucideIcons.circleCheck,
        color: AppTokens.success,
        tint: AppTokens.successTint,
      ),
      _KpiCard(
        label: 'تحتاج متابعة',
        value: '${kpis.overdue}',
        icon: LucideIcons.clockAlert,
        color: AppTokens.warning,
        tint: AppTokens.warningTint,
      ),
      _KpiCard(
        label: 'تحصيل الفترة',
        value: _amount(kpis.collected),
        icon: LucideIcons.badgeDollarSign,
        color: AppTokens.info,
        tint: AppTokens.infoTint,
        suffix: 'ج.م',
      ),
    ],
  );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.tint,
    this.suffix,
  });
  final String label, value;
  final String? suffix;
  final IconData icon;
  final Color color, tint;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: _card(context, color: tint),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.tokens.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: context.tokens.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (suffix != null) ...[
                    const SizedBox(width: 3),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        suffix!,
                        style: TextStyle(
                          color: context.tokens.muted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.rows,
    required this.onOpenInspection,
    this.onOpenAll,
  });
  final List<CrmDashboardSchedule> rows;
  final ValueChanged<String> onOpenInspection;
  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'جدول اليوم',
    icon: LucideIcons.clock3,
    action: onOpenAll == null
        ? null
        : _TextLink(label: 'كل المعاينات', onTap: onOpenAll!),
    child: rows.isEmpty
        ? const _EmptyLine(text: 'لا توجد معاينات اليوم')
        : Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                _ScheduleRow(
                  row: rows[index],
                  onTap: () => onOpenInspection(rows[index].id),
                ),
                if (index != rows.length - 1)
                  Divider(height: 1, color: context.tokens.line),
              ],
            ],
          ),
  );
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({required this.row, required this.onTap});
  final CrmDashboardSchedule row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = serverWallTime(row.scheduledAt);
    final time = date == null
        ? '—'
        : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 49,
                child: Text(
                  time,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: context.tokens.brand,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.tokens.brand,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.leadName,
                      style: TextStyle(
                        color: context.tokens.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${row.area ?? 'بدون منطقة'}  ·  ${row.engineer}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.tokens.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronLeft,
                size: 17,
                color: context.tokens.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.statuses});
  final List<CrmDashboardStatus> statuses;

  @override
  Widget build(BuildContext context) {
    final total = statuses.fold<int>(0, (sum, item) => sum + item.count);
    final entries = [
      for (final item in statuses)
        (item: item, color: _statusColor(context, item.status)),
    ];
    return _SectionCard(
      title: 'حالات المعاينات',
      icon: LucideIcons.chartPie,
      child: statuses.isEmpty
          ? const _EmptyLine(text: 'لا توجد بيانات للفترة')
          : Row(
              children: [
                SizedBox(
                  width: 122,
                  height: 122,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size.square(122),
                        painter: _DonutPainter(
                          values: [
                            for (final entry in entries) entry.item.count,
                          ],
                          colors: [for (final entry in entries) entry.color],
                          trackColor: context.tokens.line,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$total',
                            style: TextStyle(
                              color: context.tokens.ink,
                              fontSize: 22,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'إجمالي',
                            style: TextStyle(
                              color: context.tokens.muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    children: [
                      for (final entry in entries)
                        _StatusLegend(item: entry.item, color: entry.color),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend({required this.item, required this.color});
  final CrmDashboardStatus item;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            crmInspectionStatusLabels[item.status] ?? item.status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.tokens.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '${item.count}',
          style: TextStyle(
            color: context.tokens.ink,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.values,
    required this.colors,
    required this.trackColor,
  });
  final List<int> values;
  final List<Color> colors;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 15.0;
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, track);
    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) return;
    const gap = .035;
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final fullSweep = values[index] / total * math.pi * 2;
      final sweep = math.max(0.0, fullSweep - gap);
      final paint = Paint()
        ..color = colors[index]
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.colors != colors ||
      oldDelegate.trackColor != trackColor;
}

Color _statusColor(BuildContext context, String status) => switch (status) {
  'DONE' => AppTokens.success,
  'CANCELLED' => AppTokens.danger,
  'NO_SHOW' => const Color(0xFFC96B5B),
  'RESCHEDULED' => AppTokens.warning,
  'BOOKED' => context.tokens.brand,
  _ => AppTokens.info,
};

class _EngineersCard extends StatelessWidget {
  const _EngineersCard({required this.engineers});
  final List<CrmEngineerPerformance> engineers;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'أداء المهندسين',
    icon: LucideIcons.usersRound,
    child: engineers.isEmpty
        ? const _EmptyLine(text: 'لا توجد بيانات أداء')
        : Column(
            children: [
              for (final item in engineers.take(5)) _EngineerRow(item: item),
            ],
          ),
  );
}

class _EngineerRow extends StatelessWidget {
  const _EngineerRow({required this.item});
  final CrmEngineerPerformance item;

  @override
  Widget build(BuildContext context) {
    final rate = item.inspections == 0
        ? 0
        : (item.done * 100 / item.inspections);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: context.tokens.wash,
            foregroundColor: context.tokens.brand,
            child: Text(
              item.engineer.trim().isEmpty ? 'م' : item.engineer.trim()[0],
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.engineer,
                  style: TextStyle(
                    color: context.tokens.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${item.done} مكتملة من ${item.inspections}  ·  ${rate.round()}%',
                  style: TextStyle(color: context.tokens.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${_amount(item.collected)} ج.م',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              color: context.tokens.brand,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialCard extends StatelessWidget {
  const _FinancialCard({required this.financial});
  final CrmDashboardFinancial financial;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'الملخص المالي',
    icon: LucideIcons.walletCards,
    child: GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _MoneyCell(label: 'المتفق عليه', value: financial.agreed),
        _MoneyCell(label: 'المحصل', value: financial.collected),
        _MoneyCell(label: 'المصروفات', value: financial.expenses),
        _MoneyCell(label: 'الصافي', value: financial.net, strong: true),
      ],
    ),
  );
}

class _MoneyCell extends StatelessWidget {
  const _MoneyCell({
    required this.label,
    required this.value,
    this.strong = false,
  });
  final String label, value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: strong ? context.tokens.wash : context.tokens.sunken,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.tokens.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(color: context.tokens.muted, fontSize: 10.5),
        ),
        Text(
          '${_amount(value)} ج.م',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: strong ? context.tokens.brand : context.tokens.ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.action,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: _card(context),
    child: Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: context.tokens.brand),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.tokens.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(99),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.tokens.brand,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 3),
          Icon(LucideIcons.chevronLeft, size: 14, color: context.tokens.brand),
        ],
      ),
    ),
  );
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Text(
      text,
      style: TextStyle(color: context.tokens.muted, fontSize: 12),
    ),
  );
}

BoxDecoration _card(BuildContext context, {Color? color}) => BoxDecoration(
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

String _amount(String value) => money(value).replaceFirst(RegExp(r'\.00$'), '');
