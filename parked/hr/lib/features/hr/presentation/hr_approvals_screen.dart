import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_refresh_page.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/hr_repository.dart';
import '../domain/hr_models.dart';
import 'hr_widgets.dart';

enum _Tab { devices, punches }

/// «موافقات الحضور»: what waits for the direct manager, or HR without one:
/// requests to bind a phone, and punches from a phone that is not the
/// employee's.
class HrApprovalsScreen extends StatefulWidget {
  const HrApprovalsScreen({
    super.key,
    required this.repository,
    this.onChanged,
    this.embedded = false,
  });

  final HrRepository repository;

  /// After a decision, so the drawer's count follows.
  final VoidCallback? onChanged;
  final bool embedded;

  @override
  State<HrApprovalsScreen> createState() => _HrApprovalsScreenState();
}

class _HrApprovalsScreenState extends State<HrApprovalsScreen> {
  _Tab _tab = _Tab.devices;
  List<HrDeviceRequest> _requests = const [];
  List<HrPunch> _punches = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

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
      final (requests, punches) = await (
        widget.repository.deviceRequests(),
        widget.repository.heldPunches(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _punches = punches;
        // Open on whatever waits when the phones are done.
        if (requests.isEmpty && punches.isNotEmpty) _tab = _Tab.punches;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide({
    required String id,
    required bool approve,
    required _Decision decision,
    required Future<void> Function(String? note) send,
    required String done,
  }) async {
    final note = await showAppSheet<String>(
      context,
      builder: (context) =>
          _DecisionSheet(decision: decision, approve: approve),
    );
    if (note == null || !mounted) return;
    setState(() => _busy.add(id));
    try {
      await send(note);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      widget.onChanged?.call();
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _decideRequest(HrDeviceRequest request, {required bool approve}) =>
      _decide(
        id: request.id,
        approve: approve,
        decision: _Decision.device(request),
        send: (note) => widget.repository.decideDeviceRequest(
          request,
          approve: approve,
          note: note,
        ),
        done: approve
            ? 'تم ربط جهاز ${request.employee.name}'
            : 'تم رفض طلب الربط',
      );

  void _decidePunch(HrPunch punch, {required bool approve}) => _decide(
    id: punch.id,
    approve: approve,
    decision: _Decision.punch(punch),
    send: (note) =>
        widget.repository.decidePunch(punch, approve: approve, note: note),
    done: approve ? 'تم اعتماد البصمة' : 'تم رفض البصمة',
  );

  @override
  Widget build(BuildContext context) {
    final devices = _tab == _Tab.devices;
    final empty = devices ? _requests.isEmpty : _punches.isEmpty;
    final children = <Widget>[
      if (!widget.embedded) ...[
        const PageHeader(
          title: 'موافقات الحضور',
          subtitle: 'طلبات ربط الأجهزة والبصمات من أجهزة غير مربوطة',
        ),
        const SizedBox(height: 14),
      ],
      LedgerTabs<_Tab>(
        value: _tab,
        tabs: [
          (_Tab.devices, 'ربط الأجهزة', _requests.length),
          (_Tab.punches, 'البصمات', _punches.length),
        ],
        onChanged: (tab) => setState(() => _tab = tab),
      ),
      const SizedBox(height: 12),
      if (_error != null)
        MessagePanel(message: _error!, onRetry: _load)
      else if (_loading && empty)
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (empty)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.tokens.line),
          ),
          child: devices
              ? const AppEmptyState(
                  icon: LucideIcons.smartphone,
                  title: 'لا توجد طلبات ربط',
                  message: 'تظهر هنا طلبات ربط الأجهزة من فريقك.',
                )
              : const AppEmptyState(
                  icon: LucideIcons.fingerprint,
                  title: 'لا توجد بصمات معلّقة',
                  message:
                      'تظهر هنا البصمات من أجهزة غير مربوطة بحسابات أصحابها.',
                ),
        )
      else if (devices)
        for (final request in _requests) ...[
          _ApprovalCard(
            name: request.employee.name,
            detail:
                '${request.employee.code} · ${request.requestedAt == null ? '' : '${hrDayLabel(_iso(request.requestedAt!))} ${hrClock(request.requestedAt)}'}',
            icon: LucideIcons.smartphone,
            lines: [
              [
                request.model ?? request.deviceName,
                request.platform == 'IOS' ? 'iOS' : 'Android',
                if (request.appVersion != null) 'إصدار ${request.appVersion}',
              ].join(' · '),
            ],
            tags: [
              if (request.takenByOther)
                const AppTag(
                  'مربوط بحساب آخر',
                  tone: AppTone.warning,
                  icon: LucideIcons.userX,
                ),
              if (request.replacesPhone != null)
                AppTag(
                  'بدل ${request.replacesPhone}',
                  icon: LucideIcons.repeat,
                ),
            ],
            busy: _busy.contains(request.id),
            onApprove: () => _decideRequest(request, approve: true),
            onReject: () => _decideRequest(request, approve: false),
          ),
          const SizedBox(height: 10),
        ]
      else
        for (final punch in _punches) ...[
          _ApprovalCard(
            name: punch.employee?.name ?? '—',
            detail:
                '${punch.employee?.code ?? ''} · ${hrDayLabel(punch.dateTrx)}',
            icon: punch.punchType == 'IN'
                ? LucideIcons.logIn
                : LucideIcons.logOut,
            trailing: hrClock(punch.punchedAt),
            lines: [
              [
                punch.punchType == 'IN' ? 'حضور' : 'انصراف',
                if (punch.location != null) punch.location!.name,
                if (punch.distanceM != null) 'على بعد ${punch.distanceM} م',
              ].join(' · '),
              if (punch.note != null) 'ملاحظة: ${punch.note}',
            ],
            tags: [
              for (final flag in punch.trustFlags)
                AppTag(trustFlagLabel(flag), tone: AppTone.warning),
            ],
            busy: _busy.contains(punch.id),
            onApprove: () => _decidePunch(punch, approve: true),
            onReject: () => _decidePunch(punch, approve: false),
          ),
          const SizedBox(height: 10),
        ],
    ];
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return AppRefreshPage(onRefresh: _load, children: children);
  }
}

String _iso(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${two(day.month)}-${two(day.day)}';

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.name,
    required this.detail,
    required this.icon,
    required this.lines,
    required this.tags,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    this.trailing,
  });

  final String name;
  final String detail;
  final IconData icon;
  final List<String> lines;
  final List<Widget> tags;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  /// A time shown large at the card's end.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.washStrong,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 19, color: tokens.brandStrong),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tokens.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in lines)
            Text(
              line,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.7,
                color: tokens.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: tags),
          ],
          Divider(height: 22, color: tokens.line),
          if (busy)
            const Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTokens.danger,
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
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    icon: const Icon(LucideIcons.check, size: 17),
                    label: const Text('موافقة'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// What the decision sheet says about the item and what deciding does.
class _Decision {
  const _Decision({
    required this.subtitle,
    required this.approveTitle,
    required this.rejectTitle,
    required this.approveEffect,
    required this.rejectEffect,
  });

  factory _Decision.device(HrDeviceRequest request) => _Decision(
    subtitle:
        '${request.employee.name} · ${request.model ?? request.deviceName}',
    approveTitle: 'الموافقة على ربط الجهاز',
    rejectTitle: 'رفض ربط الجهاز',
    approveEffect: [
      'يُربط الجهاز بحساب ${request.employee.name} ويدخل منه بالبصمة.',
      if (request.takenByOther)
        'يُلغى ربط الجهاز بالحساب الآخر ويصل لصاحبه إشعار.',
      if (request.replacesPhone != null)
        // The Latin name last, with nothing after it to flip around in RTL.
        'يُلغى ربط جهازه السابق: ${request.replacesPhone}',
      'تُعتمد بصماته المعلّقة من هذا الجهاز.',
    ].join('\n'),
    rejectEffect:
        'يبقى كل شيء كما هو، ويصل للموظف إشعار بالرفض وملاحظتك إن وُجدت.',
  );

  factory _Decision.punch(HrPunch punch) => _Decision(
    subtitle:
        '${punch.employee?.name ?? ''} · ${punch.punchType == 'IN' ? 'حضور' : 'انصراف'} ${hrClock(punch.punchedAt)}',
    approveTitle: 'اعتماد البصمة',
    rejectTitle: 'رفض البصمة',
    approveEffect: 'تُحتسب البصمة في يوم الموظف ويصله إشعار بالاعتماد.',
    rejectEffect: 'لا تُحتسب البصمة، ويصل للموظف إشعار بالرفض وملاحظتك.',
  );

  final String subtitle;
  final String approveTitle;
  final String rejectTitle;
  final String approveEffect;
  final String rejectEffect;
}

/// Confirms a decision with an optional note for the employee. Pops with the
/// note (possibly empty) or null when cancelled.
class _DecisionSheet extends StatefulWidget {
  const _DecisionSheet({required this.decision, required this.approve});
  final _Decision decision;
  final bool approve;

  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decision = widget.decision;
    final approve = widget.approve;
    return AppSheetScaffold(
      title: approve ? decision.approveTitle : decision.rejectTitle,
      subtitle: decision.subtitle,
      footer: AppSheetActions(
        primaryLabel: approve ? 'تأكيد الموافقة' : 'تأكيد الرفض',
        primaryIcon: approve ? LucideIcons.check : LucideIcons.x,
        destructive: !approve,
        onPrimary: () => Navigator.pop(context, _note.text.trim()),
        secondaryLabel: 'إلغاء',
        onSecondary: () => Navigator.pop(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: approve ? context.tokens.wash : AppTokens.dangerTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              approve ? decision.approveEffect : decision.rejectEffect,
              style: const TextStyle(fontSize: 13, height: 1.8),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(
              labelText: 'ملاحظة للموظف (اختياري)',
              alignLabelWithHint: true,
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}
