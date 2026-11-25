import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_filter.dart';
import '../../../core/widgets/app_refresh_page.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/hr_repository.dart';
import '../domain/hr_models.dart';
import '../application/punch_sensors.dart';
import 'attendance_punch_screen.dart';
import 'hr_approvals_screen.dart';
import 'hr_request_form.dart';
import 'hr_widgets.dart';

/// «سجل الحضور»: the employee's days for one month.
class AttendanceLogScreen extends StatefulWidget {
  const AttendanceLogScreen({
    super.key,
    required this.repository,
    this.sensors,
    this.showTeam = false,
    this.companyWide = false,
    this.showApprovals = false,
    this.onApprovalsChanged,
  });

  final HrRepository repository;
  final PunchSensors? sensors;
  final bool showTeam;
  final bool companyWide;
  final bool showApprovals;
  final VoidCallback? onApprovalsChanged;

  @override
  State<AttendanceLogScreen> createState() => _AttendanceLogScreenState();
}

class _AttendanceLogScreenState extends State<AttendanceLogScreen> {
  /// Opens on the server's month, known after the first answer.
  DateTime? _month;
  DateTime? _now;
  List<HrTimesheetDay> _days = const [];
  List<HrTimesheetDay> _teamDays = const [];
  bool _loading = true;
  String? _error;

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
      final now = _now = await widget.repository.serverNow();
      final month = _month ??= DateTime(now.year, now.month);
      final end = DateTime(month.year, month.month + 1, 0);
      final results = await Future.wait([
        widget.repository.timesheet(from: month, to: end),
        if (widget.showTeam)
          widget.repository.teamTimesheet(
            from: month,
            to: end,
            companyWide: widget.companyWide,
          ),
      ]);
      if (!mounted) return;
      setState(() {
        _days = results.first..sort((a, b) => b.workDate.compareTo(a.workDate));
        _teamDays = widget.showTeam
            ? (results.last..sort((a, b) {
                final byDate = b.workDate.compareTo(a.workDate);
                return byDate != 0
                    ? byDate
                    : (a.employee?.name ?? '').compareTo(
                        b.employee?.name ?? '',
                      );
              }))
            : const [];
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shift(int months) {
    final month = _month;
    if (month == null) return;
    setState(() => _month = DateTime(month.year, month.month + months));
    _load();
  }

  Future<void> _openDay(HrTimesheetDay day) async {
    final correct = await showAppSheet<bool>(
      context,
      builder: (context) => _DaySheet(day: day, repository: widget.repository),
    );
    if (correct != true || !mounted) return;
    final filed = await showHrRequestForm(
      context,
      repository: widget.repository,
      type: 'ATTENDANCE_CORRECTION',
      date: DateTime.tryParse(day.workDate),
    );
    if (filed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال طلب تصحيح الحضور')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final now = _now;
    final month = _month;
    final current =
        month == null ||
        now == null ||
        (month.year == now.year && month.month == now.month);
    final present = _days
        .where(
          (d) => const {'PRESENT', 'MISSION', 'PERMISSION'}.contains(d.status),
        )
        .length;
    final absent = _days.where((d) => d.status == 'ABSENT').length;
    final late = _days.fold<int>(
      0,
      (sum, d) => sum + d.lateMinutes + d.earlyLeaveMinutes,
    );
    final overtime = _days.fold<int>(0, (sum, d) => sum + d.overtimeMinutes);
    return AppRefreshPage(
      onRefresh: _load,
      children: [
        PageHeader(
          title: 'سجل الحضور',
          subtitle: 'حضوري ثم حضور الفريق في شاشة واحدة',
          action: widget.sensors == null
              ? null
              : FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        body: SafeArea(
                          child: AttendancePunchScreen(
                            repository: widget.repository,
                            sensors: widget.sensors!,
                          ),
                        ),
                      ),
                    ),
                  ),
                  icon: const Icon(LucideIcons.fingerprint, size: 18),
                  label: const Text('تسجيل بصمة'),
                ),
        ),
        const SizedBox(height: 14),
        const _SectionHeading(
          title: 'حضوري',
          subtitle: 'ملخص وسجل الحضور الشخصي',
          icon: LucideIcons.userRound,
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tokens.line),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'الشهر السابق',
                onPressed: _loading ? null : () => _shift(-1),
                icon: const Icon(LucideIcons.chevronRight, size: 19),
              ),
              Expanded(
                child: Text(
                  month == null
                      ? '—'
                      : '${hrMonths[month.month - 1]} ${month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'الشهر التالي',
                onPressed: _loading || current ? null : () => _shift(1),
                icon: const Icon(LucideIcons.chevronLeft, size: 19),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppFilterGrid(
          children: [
            _Stat(
              label: 'أيام الحضور',
              value: '$present',
              icon: LucideIcons.userCheck,
            ),
            _Stat(
              label: 'أيام الغياب',
              value: '$absent',
              icon: LucideIcons.userX,
              color: absent > 0 ? AppTokens.danger : null,
            ),
            _Stat(
              label: 'التأخير والانصراف المبكر',
              value: hrDuration(late),
              icon: LucideIcons.clockAlert,
              color: late > 0 ? AppTokens.warning : null,
            ),
            _Stat(
              label: 'الوقت الإضافي',
              value: hrDuration(overtime),
              icon: LucideIcons.clockArrowUp,
              color: overtime > 0 ? AppTokens.success : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_error != null)
          MessagePanel(message: _error!, onRetry: _load)
        else
          AppDataTable<HrTimesheetDay>(
            columns: const [
              AppTableColumn('اليوم', 130),
              AppTableColumn('الحالة', 110),
              AppTableColumn('الحضور', 76),
              AppTableColumn('الانصراف', 76),
              AppTableColumn('ساعات العمل', 92),
              AppTableColumn('التأخير', 76),
              AppTableColumn('الإضافي', 76),
            ],
            rows: _days,
            loading: _loading,
            rowColor: (day) => day.status == 'ABSENT'
                ? AppTokens.dangerTint
                : day.missingPunch
                ? AppTokens.warningTint
                : null,
            onTap: _openDay,
            cells: (day) => [
              AppTableTitle(
                title: hrDayLabel(day.workDate),
                subtitle: day.shift?.name,
              ),
              dayStatusTag(day),
              _Time(day.checkIn),
              _Time(day.checkOut),
              _Minutes(day.workedMinutes, asDuration: true),
              _Minutes(
                day.lateMinutes + day.earlyLeaveMinutes,
                color: AppTokens.warning,
              ),
              _Minutes(day.overtimeMinutes, color: AppTokens.success),
            ],
            empty: const AppEmptyState(
              icon: LucideIcons.calendarX2,
              title: 'لا توجد أيام مسجلة لهذا الشهر',
            ),
          ),
        if (widget.showTeam) ...[
          const SizedBox(height: 18),
          _SectionHeading(
            title: 'حضور الفريق',
            subtitle: _teamDays.isEmpty
                ? 'لا توجد بيانات للفريق في هذه الفترة'
                : '${_teamDays.map((day) => day.employee?.id).whereType<String>().toSet().length} موظف',
            icon: LucideIcons.users,
          ),
          const SizedBox(height: 10),
          AppDataTable<HrTimesheetDay>(
            columns: const [
              AppTableColumn('الموظف', 150),
              AppTableColumn('اليوم', 110),
              AppTableColumn('الحالة', 110),
              AppTableColumn('الحضور', 76),
              AppTableColumn('الانصراف', 76),
              AppTableColumn('ساعات العمل', 92),
            ],
            rows: _teamDays,
            loading: _loading,
            rowColor: (day) => day.status == 'ABSENT'
                ? AppTokens.dangerTint
                : day.missingPunch
                ? AppTokens.warningTint
                : null,
            cells: (day) => [
              AppTableTitle(
                title: day.employee?.name ?? '—',
                subtitle: day.employee?.code,
              ),
              Text(hrDayLabel(day.workDate)),
              dayStatusTag(day),
              _Time(day.checkIn),
              _Time(day.checkOut),
              _Minutes(day.workedMinutes, asDuration: true),
            ],
            empty: const AppEmptyState(
              icon: LucideIcons.users,
              title: 'لا توجد بيانات حضور للفريق',
            ),
          ),
        ],
        if (widget.showApprovals) ...[
          const SizedBox(height: 18),
          const _SectionHeading(
            title: 'موافقات الحضور',
            subtitle: 'ربط الأجهزة والبصمات المعلقة',
            icon: LucideIcons.clipboardCheck,
          ),
          const SizedBox(height: 10),
          HrApprovalsScreen(
            repository: widget.repository,
            onChanged: widget.onApprovalsChanged,
            embedded: true,
          ),
        ],
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: context.tokens.wash,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: context.tokens.brandStrong),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: context.tokens.muted),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: 80,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color ?? tokens.brand),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color ?? tokens.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Time extends StatelessWidget {
  const _Time(this.value);
  final DateTime? value;

  @override
  Widget build(BuildContext context) => Text(
    hrClock(value),
    textDirection: TextDirection.ltr,
    style: TextStyle(
      color: value == null ? context.tokens.muted : context.tokens.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

class _Minutes extends StatelessWidget {
  const _Minutes(this.minutes, {this.color, this.asDuration = false});
  final int minutes;
  final Color? color;
  final bool asDuration;

  @override
  Widget build(BuildContext context) => Text(
    minutes == 0 ? '—' : (asDuration ? hrDuration(minutes) : '$minutes د'),
    textDirection: asDuration ? TextDirection.ltr : null,
    style: TextStyle(
      color: minutes == 0
          ? context.tokens.muted
          : (color ?? context.tokens.ink),
      fontWeight: minutes == 0 ? FontWeight.w500 : FontWeight.w800,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

/// One day: its figures, the deductions or overtime it produced and the raw
/// punches. Pops true when the employee asks to correct it.
class _DaySheet extends StatefulWidget {
  const _DaySheet({required this.day, required this.repository});
  final HrTimesheetDay day;
  final HrRepository repository;

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  late final Future<List<HrPunch>> _punches = () {
    final date = DateTime.tryParse(widget.day.workDate);
    return date == null
        ? Future.value(const <HrPunch>[])
        : widget.repository.punches(from: date, to: date);
  }();

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final tokens = context.tokens;
    final rows = <(String, String)>[
      if (day.shift != null)
        (
          'الوردية',
          '${day.shift!.name} · ${hrRange(hrClock(day.shiftStart), hrClock(day.shiftEnd))}',
        ),
      ('الحضور', hrClock(day.checkIn)),
      ('الانصراف', hrClock(day.checkOut)),
      ('الساعات المقررة', hrDuration(day.plannedMinutes)),
      ('ساعات العمل', hrDuration(day.workedMinutes)),
      if (day.lateMinutes > 0) ('التأخير', '${day.lateMinutes} دقيقة'),
      if (day.earlyLeaveMinutes > 0)
        ('الانصراف المبكر', '${day.earlyLeaveMinutes} دقيقة'),
      if (day.permissionMinutes > 0)
        ('الإذن', '${day.permissionMinutes} دقيقة'),
      if (day.overtimeMinutes > 0)
        (
          'الوقت الإضافي',
          '${day.overtimeMinutes} دقيقة · المعتمد ${day.approvedOvertimeMinutes}',
        ),
    ];
    return AppSheetScaffold(
      title: hrDayLabel(day.workDate),
      subtitle: day.locked ? 'يوم مغلق ضمن فترة مرتبات' : null,
      footer: day.locked
          ? null
          : AppSheetActions(
              primaryLabel: 'طلب تصحيح حضور',
              primaryIcon: LucideIcons.fingerprint,
              onPrimary: () => Navigator.pop(context, true),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: dayStatusTag(day)),
          const SizedBox(height: 14),
          _Box(rows: rows),
          if (day.lines.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Heading('التأثير على المرتب'),
            for (final line in day.lines)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: line.lineType == 'OVERTIME'
                      ? AppTokens.successTint
                      : AppTokens.warningTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          lineTypeLabel(line.lineType),
                          if (line.minutes != null) '${line.minutes} دقيقة',
                          if (line.occurrence != null)
                            'المرة ${line.occurrence}',
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    AppTag(
                      lineStatusLabel(line.status),
                      tone: line.status == 'APPLIED'
                          ? AppTone.neutral
                          : line.status == 'DRAFT'
                          ? AppTone.info
                          : AppTone.danger,
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
          _Heading('بصمات اليوم'),
          FutureBuilder<List<HrPunch>>(
            future: _punches,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(minHeight: 2),
                );
              }
              final punches = snapshot.data!;
              if (punches.isEmpty) {
                return Text(
                  'لا توجد بصمات لهذا اليوم',
                  style: TextStyle(color: tokens.muted, fontSize: 13),
                );
              }
              return _Box(
                rows: [
                  for (final punch in punches)
                    (
                      punch.punchType == 'IN' ? 'حضور' : 'انصراف',
                      [
                        hrClock(punch.punchedAt),
                        if (punch.location != null) punch.location!.name,
                        if (punch.status == 'PENDING') 'معلّقة',
                        if (punch.status == 'REJECTED') 'مرفوضة',
                      ].join(' · '),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: context.tokens.muted,
      ),
    ),
  );
}

class _Box extends StatelessWidget {
  const _Box({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: tokens.sunken,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        children: [
          for (final (i, (label, value)) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: tokens.line)),
              ),
              child: Row(
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
    );
  }
}
