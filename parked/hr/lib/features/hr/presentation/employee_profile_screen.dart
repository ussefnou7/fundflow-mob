import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_refresh_page.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/hr_repository.dart';
import '../domain/hr_models.dart';
import 'hr_widgets.dart';

/// «ملف الموظف»: the employee's own file, read only; HR edits it on the web.
class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key, required this.repository});
  final HrRepository repository;

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  HrEmployeeProfile? _profile;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final profile = await widget.repository.profile();
      if (mounted) setState(() => _profile = profile);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final tokens = context.tokens;
    String date(String? value) => value == null ? '—' : hrDate(value);
    String place(HrEmployeeProfile p) => switch (p.attendanceType) {
      'SINGLE' => p.location?.name ?? '—',
      'MULTI' => p.locationSet?.name ?? '—',
      _ => 'غير مقيد بموقع',
    };
    return AppRefreshPage(
      onRefresh: _load,
      children: [
        const PageHeader(title: 'ملف الموظف'),
        const SizedBox(height: 14),
        if (_error != null && p == null)
          MessagePanel(message: _error!, onRetry: _load)
        else if (p == null)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _ProfileHero(profile: p),
          _Section(
            title: 'البيانات الوظيفية',
            icon: LucideIcons.briefcase,
            rows: [
              ('كود الموظف', p.code),
              ('القسم', p.department?.name ?? '—'),
              ('المسمى الوظيفي', p.jobTitle ?? '—'),
              ('المدير المباشر', p.manager?.name ?? '—'),
              ('تاريخ التعيين', date(p.hireDate)),
              ('نوع العقد', contractTypeLabel(p.contractType)),
              if (p.contractEndDate != null)
                ('نهاية العقد', date(p.contractEndDate)),
              if (p.terminationDate != null)
                ('تاريخ انتهاء الخدمة', date(p.terminationDate)),
              ('الحالة', employeeStatusLabel(p.status)),
            ],
          ),
          _Section(
            title: 'الحضور',
            icon: LucideIcons.fingerprint,
            rows: [
              ('الوردية', p.shift?.name ?? '—'),
              ('طريقة الحضور', attendanceTypeLabel(p.attendanceType)),
              ('موقع العمل', place(p)),
              ('مركز التكلفة', p.costCenter?.name ?? '—'),
            ],
          ),
          _Section(
            title: 'البيانات الشخصية',
            icon: LucideIcons.idCard,
            rows: [
              ('الرقم القومي / جواز السفر', p.nationalId ?? '—'),
              ('الهاتف', p.phone ?? '—'),
              ('البريد الإلكتروني', p.email ?? '—'),
              ('تاريخ الميلاد', date(p.birthDate)),
              if (p.username != null) ('اسم المستخدم', p.username!),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(LucideIcons.info, size: 15, color: tokens.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'لتعديل أي بيانات تواصل مع إدارة الموارد البشرية.',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile});
  final HrEmployeeProfile profile;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final initials = profile.fullName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [tokens.brand, tokens.brandStrong, tokens.brandDeep],
          stops: const [0, .55, 1],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: .25)),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (profile.jobTitle != null)
                  Text(
                    profile.jobTitle!,
                    style: const TextStyle(
                      color: Color(0xDDFFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(
                  [
                    profile.code,
                    if (profile.department != null) profile.department!.name,
                  ].join(' · '),
                  style: const TextStyle(
                    color: Color(0xB8FFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: profile.status == 'ACTIVE'
                  ? Colors.white.withValues(alpha: .14)
                  : AppTokens.dangerTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              employeeStatusLabel(profile.status),
              style: TextStyle(
                color: profile.status == 'ACTIVE'
                    ? Colors.white
                    : AppTokens.danger,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.rows});
  final String title;
  final IconData icon;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: tokens.brand),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tokens.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.line),
            ),
            child: Column(
              children: [
                for (final (i, (label, value)) in rows.indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
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
        ],
      ),
    );
  }
}
