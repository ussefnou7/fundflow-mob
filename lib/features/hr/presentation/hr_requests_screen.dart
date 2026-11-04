import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_filter.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_refresh_page.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/hr_repository.dart';
import '../domain/hr_models.dart';
import 'hr_request_form.dart';
import 'hr_widgets.dart';

enum _RequestsTab { mine, team, balances }

/// Every request flow in one place: mine, the team's approval queue and my
/// balances. Tabs appear only when they are useful to the signed-in user.
class HrRequestsScreen extends StatefulWidget {
  const HrRequestsScreen({
    super.key,
    required this.repository,
    this.canCreate = true,
    this.showTeam = false,
    this.companyWide = false,
  });
  final HrRepository repository;
  final bool canCreate;
  final bool showTeam;
  final bool companyWide;

  @override
  State<HrRequestsScreen> createState() => _HrRequestsScreenState();
}

class _HrRequestsScreenState extends State<HrRequestsScreen> {
  List<HrRequest> _requests = const [];
  List<HrRequest> _teamRequests = const [];
  HrRequestOptions? _options;
  _RequestsTab _tab = _RequestsTab.mine;
  String _type = '';
  String _status = '';
  int _page = 0;
  int _pageSize = 10;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!widget.canCreate && widget.showTeam) _tab = _RequestsTab.team;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object?>([
        widget.canCreate
            ? widget.repository.requests()
            : Future.value(const <HrRequest>[]),
        widget.canCreate
            ? widget.repository.requestOptions()
            : Future.value(null),
        widget.showTeam
            ? widget.repository.teamRequests(companyWide: widget.companyWide)
            : Future.value(const <HrRequest>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _requests = (results.first as List<HrRequest>)
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
              a.createdAt ?? DateTime(0),
            ),
          );
        _options = results[1] as HrRequestOptions?;
        if (widget.showTeam) {
          _teamRequests = (results[2] as List<HrRequest>)
            ..sort((a, b) {
              final pending =
                  (b.status == 'PENDING' ? 1 : 0) -
                  (a.status == 'PENDING' ? 1 : 0);
              return pending != 0
                  ? pending
                  : (b.createdAt ?? DateTime(0)).compareTo(
                      a.createdAt ?? DateTime(0),
                    );
            });
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<HrRequest> get _filtered => _requests
      .where(
        (r) =>
            (_type.isEmpty || r.requestType == _type) &&
            (_status.isEmpty || r.status == _status),
      )
      .toList(growable: false);

  Future<void> _create() async {
    final filed = await showHrRequestForm(
      context,
      repository: widget.repository,
    );
    if (!filed || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم إرسال الطلب')));
    setState(() => _page = 0);
    await _load();
  }

  Future<void> _open(HrRequest request) async {
    final cancelled = await showAppSheet<bool>(
      context,
      builder: (context) =>
          _RequestDetail(request: request, repository: widget.repository),
    );
    if (cancelled == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إلغاء الطلب')));
      await _load();
    }
  }

  Future<void> _openTeam(HrRequest request) async {
    final changed = await showAppSheet<bool>(
      context,
      builder: (context) => _RequestDetail(
        request: request,
        repository: widget.repository,
        allowDecision: request.decidable,
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _openFilters() async {
    final result = await showAppFilterSheet<(String, String, int)>(
      context: context,
      subtitle: 'الطلبات',
      initial: (_type, _status, _pageSize),
      empty: ('', '', _pageSize),
      isActive: (draft) => draft.$1.isNotEmpty || draft.$2.isNotEmpty,
      fields: (context, draft, update) => AppFilterGrid(
        children: [
          AppSelect<String>(
            compact: true,
            label: 'نوع الطلب',
            value: draft.$1,
            options: [
              const AppSelectOption(value: '', label: 'كل الأنواع'),
              for (final type in const [
                'LEAVE',
                'PERMISSION',
                'MISSION',
                'ATTENDANCE_CORRECTION',
              ])
                AppSelectOption(value: type, label: requestTypeLabel(type)),
            ],
            onChanged: (value) => update((value ?? '', draft.$2, draft.$3)),
          ),
          AppSelect<String>(
            compact: true,
            label: 'الحالة',
            value: draft.$2,
            options: const [
              AppSelectOption(value: '', label: 'كل الحالات'),
              AppSelectOption(value: 'PENDING', label: 'قيد المراجعة'),
              AppSelectOption(value: 'APPROVED', label: 'مقبول'),
              AppSelectOption(value: 'REJECTED', label: 'مرفوض'),
              AppSelectOption(value: 'CANCELLED', label: 'ملغى'),
            ],
            onChanged: (value) => update((draft.$1, value ?? '', draft.$3)),
          ),
          appPageSizeField(
            value: draft.$3,
            onChanged: (size) => update((draft.$1, draft.$2, size)),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _type = result.$1;
      _status = result.$2;
      _pageSize = result.$3;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final filtered = _filtered;
    final visible = filtered
        .skip(_page * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    final summary = [
      if (_type.isNotEmpty) requestTypeLabel(_type),
      if (_status.isNotEmpty)
        switch (_status) {
          'PENDING' => 'قيد المراجعة',
          'APPROVED' => 'مقبول',
          'REJECTED' => 'مرفوض',
          _ => 'ملغى',
        },
    ].join(' · ');
    return AppRefreshPage(
      onRefresh: _load,
      children: [
        PageHeader(
          title: 'الطلبات',
          subtitle: 'طلباتي وموافقات الفريق والأرصدة',
          action: widget.canCreate && _tab == _RequestsTab.mine
              ? FilledButton.icon(
                  onPressed: _create,
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('طلب جديد'),
                )
              : null,
        ),
        const SizedBox(height: 14),
        LedgerTabs<_RequestsTab>(
          value: _tab,
          tabs: [
            if (widget.canCreate)
              (_RequestsTab.mine, 'طلباتي', _requests.length),
            if (widget.showTeam)
              (
                _RequestsTab.team,
                'موافقات الفريق',
                _teamRequests.where((item) => item.status == 'PENDING').length,
              ),
            if (widget.canCreate)
              (
                _RequestsTab.balances,
                'الأرصدة',
                _options?.balances.length ?? 0,
              ),
          ],
          onChanged: (tab) => setState(() {
            _tab = tab;
            _page = 0;
          }),
        ),
        const SizedBox(height: 14),
        if (_tab == _RequestsTab.balances && _options != null) ...[
          _Balances(options: _options!),
        ] else if (_tab == _RequestsTab.team) ...[
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _load)
          else if (_loading && _teamRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_teamRequests.isEmpty)
            const AppEmptyState(
              icon: LucideIcons.clipboardCheck,
              title: 'لا توجد طلبات للفريق',
              message: 'ستظهر هنا الطلبات التي تحتاج قرارك.',
            )
          else
            for (final request in _teamRequests) ...[
              _RequestCard(
                request: request,
                showEmployee: true,
                onTap: () => _openTeam(request),
              ),
              const SizedBox(height: 10),
            ],
        ] else if (_tab == _RequestsTab.mine) ...[
          AppFilterBar(
            activeCount: summary.isEmpty ? 0 : 1,
            summary: summary,
            onOpen: _openFilters,
            onClear: () => setState(() {
              _type = '';
              _status = '';
              _page = 0;
            }),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _load)
          else if (_loading && _requests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (visible.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tokens.line),
              ),
              child: AppEmptyState(
                icon: LucideIcons.fileText,
                title: summary.isEmpty
                    ? 'لا توجد طلبات حتى الآن'
                    : 'لا توجد طلبات مطابقة',
                message: summary.isEmpty
                    ? 'قدّم طلب إجازة أو إذن أو مأمورية وتابع قراره من هنا.'
                    : null,
              ),
            )
          else ...[
            for (final request in visible) ...[
              _RequestCard(request: request, onTap: () => _open(request)),
              const SizedBox(height: 10),
            ],
            AppPagination(
              page: _page,
              size: _pageSize,
              total: filtered.length,
              onChanged: (page) => setState(() => _page = page),
            ),
          ],
        ],
      ],
    );
  }
}

String requestPeriod(HrRequest r) {
  if (r.fromTime != null) {
    final time = r.toTime == null
        ? hrTime(r.fromTime)
        : hrRange(hrTime(r.fromTime), hrTime(r.toTime));
    return '${hrDate(r.fromDate)} · $time';
  }
  if (r.toDate == null || r.toDate == r.fromDate) return hrDate(r.fromDate);
  return hrRange(hrDate(r.fromDate), hrDate(r.toDate!));
}

String? requestExtent(HrRequest r) {
  if (r.days != null && r.days != '0') return '${r.days} يوم';
  if (r.minutes != null && r.minutes! > 0) return '${r.minutes} دقيقة';
  return null;
}

class _Balances extends StatelessWidget {
  const _Balances({required this.options});
  final HrRequestOptions options;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final permissions = options.permissions;
    final cards = <Widget>[
      for (final balance in options.balances)
        _BalanceCard(
          title: balance.leaveType?.name ?? 'إجازة',
          value: balance.availableDays,
          unit: 'يوم متاح',
          detail:
              'مستحق ${balance.entitledDays} · مستخدم ${balance.usedDays} · معلّق ${balance.pendingDays}',
        ),
      if (permissions != null)
        _BalanceCard(
          title: 'الأذونات',
          value: '${permissions.usedMinutes}',
          unit: permissions.maxMinutes == null
              ? 'دقيقة مستخدمة'
              : 'من ${permissions.maxMinutes} دقيقة',
          detail:
              '${permissions.usedCount}${permissions.maxCount == null ? '' : ' من ${permissions.maxCount}'} مرة في الفترة',
          muted: true,
        ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الأرصدة',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: tokens.muted,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, index) => cards[index],
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.detail,
    this.muted = false,
  });

  final String title;
  final String value;
  final String unit;
  final String detail;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: 176,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: muted ? Colors.white : tokens.wash,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: muted ? tokens.line : tokens.brand.withValues(alpha: .25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: tokens.ink,
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: tokens.brandStrong,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: tokens.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onTap,
    this.showEmployee = false,
  });
  final HrRequest request;
  final VoidCallback onTap;
  final bool showEmployee;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final extent = requestExtent(request);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: request.status == 'REJECTED'
              ? AppTokens.danger.withValues(alpha: .25)
              : tokens.line,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tokens.wash,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      requestTypeIcon(request.requestType),
                      size: 19,
                      color: tokens.brandStrong,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.leaveType?.name ??
                              requestTypeLabel(request.requestType),
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (showEmployee && request.employee != null)
                          Text(
                            '${request.employee!.name} · ${request.employee!.code}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: tokens.brandStrong,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        Text(
                          requestPeriod(request),
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  requestStatusTag(request.status),
                ],
              ),
              if (extent != null ||
                  request.punchType != null ||
                  request.attachmentName != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (request.leaveType != null)
                      AppTag(requestTypeLabel(request.requestType)),
                    if (extent != null)
                      AppTag(extent, icon: LucideIcons.hourglass),
                    if (request.punchType != null)
                      AppTag(
                        request.punchType == 'IN' ? 'بصمة حضور' : 'بصمة انصراف',
                        icon: LucideIcons.fingerprint,
                      ),
                    if (request.attachmentName != null)
                      const AppTag('مرفق', icon: LucideIcons.paperclip),
                  ],
                ),
              ],
              if (request.reason?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  request.reason!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.7,
                    color: tokens.muted,
                  ),
                ),
              ],
              if (request.status == 'REJECTED' &&
                  request.reviewNote?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTokens.dangerTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.reviewNote!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF7A1A12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestDetail extends StatefulWidget {
  const _RequestDetail({
    required this.request,
    required this.repository,
    this.allowDecision = false,
  });
  final HrRequest request;
  final HrRepository repository;
  final bool allowDecision;

  @override
  State<_RequestDetail> createState() => _RequestDetailState();
}

class _RequestDetailState extends State<_RequestDetail> {
  bool _busy = false;
  String? _error;

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.cancel(widget.request);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decide(bool approve) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.decideRequest(widget.request, approve: approve);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final tokens = context.tokens;
    final rows = <(String, String)>[
      ('نوع الطلب', requestTypeLabel(r.requestType)),
      if (r.leaveType != null) ('نوع الإجازة', r.leaveType!.name),
      ('الفترة', requestPeriod(r)),
      if (requestExtent(r) != null) ('المدة', requestExtent(r)!),
      if (r.punchType != null)
        ('البصمة', r.punchType == 'IN' ? 'حضور' : 'انصراف'),
      ('السبب', r.reason?.isNotEmpty == true ? r.reason! : '—'),
      if (r.attachmentName != null) ('المرفق', r.attachmentName!),
      if (r.createdAt != null)
        (
          'تاريخ التقديم',
          '${hrDate(r.createdAt!.toIso8601String())} · ${hrClock(r.createdAt)}',
        ),
      if (r.reviewedBy != null) ('صاحب القرار', r.reviewedBy!),
      if (r.reviewedAt != null)
        (
          'تاريخ القرار',
          '${hrDate(r.reviewedAt!.toIso8601String())} · ${hrClock(r.reviewedAt)}',
        ),
    ];
    return AppSheetScaffold(
      title: 'تفاصيل الطلب',
      subtitle: r.leaveType?.name ?? requestTypeLabel(r.requestType),
      closeEnabled: !_busy,
      footer: widget.allowDecision
          ? AppSheetActions(
              primaryLabel: 'اعتماد الطلب',
              primaryIcon: LucideIcons.check,
              busy: _busy,
              busyLabel: 'جارٍ الحفظ…',
              onPrimary: () => _decide(true),
              secondaryLabel: 'رفض',
              onSecondary: () => _decide(false),
            )
          : r.cancellable
          ? AppSheetActions(
              primaryLabel: 'إلغاء الطلب',
              primaryIcon: LucideIcons.ban,
              destructive: true,
              busy: _busy,
              busyLabel: 'جارٍ الإلغاء…',
              onPrimary: _cancel,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: requestStatusTag(r.status)),
          const SizedBox(height: 14),
          Container(
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
          if (r.reviewNote?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: r.status == 'REJECTED'
                    ? AppTokens.dangerTint
                    : AppTokens.infoTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ملاحظة القرار: ${r.reviewNote}',
                style: const TextStyle(fontSize: 13, height: 1.7),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppTokens.danger)),
          ],
        ],
      ),
    );
  }
}
