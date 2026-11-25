import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_refresh_page.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/hr_repository.dart';
import '../domain/hr_models.dart';

/// The manager/HR landing page: today's team state and the few queues that
/// need action. Detailed administration remains on the web.
class HrDashboardScreen extends StatefulWidget {
  const HrDashboardScreen({
    super.key,
    required this.repository,
    required this.companyWideAttendance,
    required this.companyWideRequests,
    required this.canViewPayroll,
  });

  final HrRepository repository;
  final bool companyWideAttendance;
  final bool companyWideRequests;
  final bool canViewPayroll;

  @override
  State<HrDashboardScreen> createState() => _HrDashboardScreenState();
}

class _HrDashboardScreenState extends State<HrDashboardScreen> {
  List<HrTimesheetDay> _today = const [];
  List<HrRequest> _requests = const [];
  List<HrMissingBasic> _missing = const [];
  List<HrTeamFace> _faces = const [];
  String? _resetting;
  HrApprovalSummary _approvals = const HrApprovalSummary();
  bool _loading = true;
  bool _missingOpen = false;
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
      final now = widget.repository.clock.now() ?? DateTime.now();
      final results = await Future.wait<Object>([
        widget.repository.teamTimesheet(
          from: DateTime(now.year, now.month, now.day),
          to: DateTime(now.year, now.month, now.day),
          companyWide: widget.companyWideAttendance,
        ),
        widget.repository.teamRequests(companyWide: widget.companyWideRequests),
        widget.repository.approvalSummary(),
        // Someone without an employee record manages no one: no faces, not an error.
        widget.repository.teamFaces().catchError((_) => const <HrTeamFace>[]),
        if (widget.canViewPayroll) widget.repository.missingBasic(),
      ]);
      if (!mounted) return;
      setState(() {
        _today = results[0] as List<HrTimesheetDay>;
        _requests = results[1] as List<HrRequest>;
        _approvals = results[2] as HrApprovalSummary;
        _faces = results[3] as List<HrTeamFace>;
        _missing = widget.canViewPayroll
            ? results[4] as List<HrMissingBasic>
            : const [];
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetFace(HrTeamFace face) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة ضبط بصمة الوجه'),
        content: Text(
          'سيتم حذف بصمة وجه ${face.employee.name}، '
          'وسيُطلب منه تسجيلها من جديد عند البصمة القادمة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إعادة الضبط'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resetting = face.employee.id);
    try {
      await widget.repository.resetFace(face.employee.id);
      final faces = await widget.repository.teamFaces();
      if (!mounted) return;
      setState(() => _faces = faces);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت إعادة ضبط بصمة وجه ${face.employee.name}')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _resetting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests.where((item) => item.status == 'PENDING').length;
    final present = _today
        .where(
          (day) =>
              const {'PRESENT', 'MISSION', 'PERMISSION'}.contains(day.status),
        )
        .length;
    final absent = _today.where((day) => day.status == 'ABSENT').length;
    final leave = _today.where((day) => day.status == 'LEAVE').length;
    final people = _today
        .map((day) => day.employee?.id)
        .whereType<String>()
        .toSet()
        .length;
    return AppRefreshPage(
      onRefresh: _load,
      children: [
        const PageHeader(
          title: 'لوحة الموارد البشرية',
          subtitle: 'ملخص الفريق والإجراءات المطلوبة اليوم',
        ),
        const SizedBox(height: 14),
        if (_error != null)
          MessagePanel(message: _error!, onRetry: _load)
        else ...[
          _AttendanceHero(
            loading: _loading,
            people: people,
            present: present,
            absent: absent,
            leave: leave,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CompactStat(
                  label: 'طلبات للمراجعة',
                  value: pending,
                  icon: LucideIcons.clipboardCheck,
                  attention: pending > 0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactStat(
                  label: 'أجهزة وبصمات',
                  value: _approvals.waiting,
                  icon: LucideIcons.fingerprint,
                  attention: _approvals.waiting > 0,
                ),
              ),
            ],
          ),
          if (_faces.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TeamFaces(
              faces: _faces,
              resetting: _resetting,
              onReset: _resetFace,
            ),
          ],
          if (widget.canViewPayroll) ...[
            const SizedBox(height: 12),
            _MissingBasicList(
              rows: _missing,
              open: _missingOpen,
              onToggle: () => setState(() => _missingOpen = !_missingOpen),
            ),
          ],
        ],
      ],
    );
  }
}

class _AttendanceHero extends StatelessWidget {
  const _AttendanceHero({
    required this.loading,
    required this.people,
    required this.present,
    required this.absent,
    required this.leave,
  });

  final bool loading;
  final int people;
  final int present;
  final int absent;
  final int leave;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [tokens.brand, tokens.brandStrong, tokens.brandDeep],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.users, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'حضور الفريق اليوم',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Text(
                  '$people موظف',
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeroValue(label: 'حضور', value: present),
              _HeroValue(label: 'غياب', value: absent),
              _HeroValue(label: 'إجازات', value: leave),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroValue extends StatelessWidget {
  const _HeroValue({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.attention,
  });

  final String label;
  final int value;
  final IconData icon;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = attention ? AppTokens.warning : tokens.brand;
    return Container(
      height: 100,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: attention ? AppTokens.warningTint : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: attention ? color.withValues(alpha: .3) : tokens.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Text(
            '$value',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// The manager's direct reports and their enrolled faces, each resettable.
class _TeamFaces extends StatelessWidget {
  const _TeamFaces({
    required this.faces,
    required this.resetting,
    required this.onReset,
  });

  final List<HrTeamFace> faces;
  final String? resetting;
  final ValueChanged<HrTeamFace> onReset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.scanFace, size: 19),
              SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'بصمات وجه الفريق',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'إعادة الضبط تطلب من الموظف تسجيل وجهه من جديد',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6C7B78)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(),
          for (final face in faces)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 17,
                backgroundColor: tokens.wash,
                child: Icon(
                  LucideIcons.userRound,
                  size: 16,
                  color: tokens.brand,
                ),
              ),
              title: Text(
                face.employee.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppTag(
                  face.enrolled ? 'مسجلة' : 'غير مسجلة',
                  tone: face.enrolled ? AppTone.success : AppTone.neutral,
                ),
              ),
              trailing: !face.enrolled
                  ? null
                  : resetting == face.employee.id
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton.icon(
                      onPressed: resetting == null ? () => onReset(face) : null,
                      icon: const Icon(LucideIcons.rotateCcw, size: 16),
                      label: const Text('إعادة ضبط'),
                    ),
            ),
        ],
      ),
    );
  }
}

class _MissingBasicList extends StatelessWidget {
  const _MissingBasicList({
    required this.rows,
    required this.open,
    required this.onToggle,
  });

  final List<HrMissingBasic> rows;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: rows.isEmpty
              ? tokens.line
              : AppTokens.warning.withValues(alpha: .35),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(LucideIcons.walletCards, size: 19),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'موظفون دون أجر أساسي',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'بيانات يجب استكمالها قبل إعداد الرواتب',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6C7B78),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppTag(
                    '${rows.length}',
                    tone: rows.isEmpty ? AppTone.neutral : AppTone.warning,
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: open ? .5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: const Icon(LucideIcons.chevronDown, size: 18),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: open
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: rows.isEmpty
                  ? const Text(
                      'بيانات الأجر الأساسي مكتملة لجميع الموظفين.',
                      style: TextStyle(fontSize: 12),
                    )
                  : Column(
                      children: [
                        const Divider(),
                        for (final row in rows)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 17,
                              backgroundColor: tokens.wash,
                              child: Icon(
                                LucideIcons.userRound,
                                size: 16,
                                color: tokens.brand,
                              ),
                            ),
                            title: Text(
                              row.fullName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              row.code,
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
