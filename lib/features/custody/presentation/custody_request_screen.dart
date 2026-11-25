import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_filter.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_refresh_page.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../treasury/data/treasury_repository.dart';
import '../../treasury/domain/treasury_models.dart';
import '../data/custody_repository.dart';
import '../domain/custody_models.dart';
import 'custody_requests_transfers.dart';
import 'custody_widgets.dart';

/// Company custody requests for managers: review them, and fund an approved
/// request straight from a treasury, linked to the request.
class CustodyRequestScreen extends StatefulWidget {
  const CustodyRequestScreen({
    super.key,
    required this.repository,
    required this.permissions,
    this.treasury,
  });

  final CustodyRepository repository;
  final Set<String> permissions;

  /// Present when the user can see treasuries; funding also needs TREASURY_OPERATE.
  final TreasuryRepository? treasury;

  @override
  State<CustodyRequestScreen> createState() => _CustodyRequestScreenState();
}

class _CustodyRequestScreenState extends State<CustodyRequestScreen> {
  PageData<CustodyRequestItem>? _page;
  bool _unpaidOnly = false;
  int _pageIndex = 0;
  int _pageSize = 20;
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  bool get _canApprove =>
      widget.permissions.contains('CUSTODY_REQUEST_APPROVE');
  bool get _canFund =>
      widget.treasury != null &&
      widget.permissions.contains('TREASURY_OPERATE');
  bool get _canCreate => widget.permissions.contains('CUSTODY_REQUEST_CREATE');

  /// A new request goes to the manager; the list shows it at once.
  Future<void> _create() async {
    final sent = await showRequestForm(
      context: context,
      repository: widget.repository,
    );
    if (!mounted || !sent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال طلب العهدة إلى المدير')),
    );
    setState(() => _pageIndex = 0);
    await _load();
  }

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
      final page = await widget.repository.requests(
        page: _pageIndex,
        size: _pageSize,
        unpaid: _unpaidOnly,
      );
      if (mounted) setState(() => _page = page);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _review(CustodyRequestItem item, {required bool approve}) async {
    final reason = await showAppSheet<String>(
      context,
      builder: (context) => _ReviewSheet(item: item, approve: approve),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy.add(item.id));
    try {
      await widget.repository.reviewRequest(
        id: item.id,
        decision: approve ? 'APPROVED' : 'REJECTED',
        reason: approve ? null : reason,
      );
      if (!mounted) return;
      _notify(approve ? 'تمت الموافقة على الطلب' : 'تم رفض الطلب');
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  Future<void> _fund(CustodyRequestItem item) async {
    final funded = await showAppSheet<bool>(
      context,
      tall: true,
      dismissible: false,
      builder: (context) =>
          _FundSheet(treasury: widget.treasury!, request: item),
    );
    if (funded != true || !mounted) return;
    _notify('تم تسجيل الصرف وبانتظار مراجعة الخزنة');
    await _load();
  }

  Future<void> _openFilters() async {
    final result = await showAppFilterSheet<(bool, int)>(
      context: context,
      subtitle: 'طلبات العهدة',
      initial: (_unpaidOnly, _pageSize),
      empty: (false, _pageSize),
      isActive: (draft) => draft.$1,
      fields: (context, draft, update) => AppFilterGrid(
        children: [
          AppSelect<bool>(
            compact: true,
            label: 'الصرف',
            value: draft.$1,
            options: const [
              AppSelectOption(value: false, label: 'كل الطلبات'),
              AppSelectOption(value: true, label: 'لم تُصرف فقط'),
            ],
            onChanged: (value) => update((value ?? false, draft.$2)),
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
      _unpaidOnly = result.$1;
      _pageSize = result.$2;
      _pageIndex = 0;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final items = page?.items ?? const <CustodyRequestItem>[];
    return AppRefreshPage(
      onRefresh: _load,
      children: [
        PageHeader(
          title: 'طلبات العهدة',
          // Without CUSTODY_REQUEST_VIEW the server lists the user's own only.
          subtitle: widget.permissions.contains('CUSTODY_REQUEST_VIEW')
              ? null
              : 'طلباتك فقط',
          action: _canCreate
              ? AppAddButton(label: 'طلب عهدة', onPressed: _create)
              : null,
        ),
        const SizedBox(height: 14),
        AppFilterBar(
          activeCount: _unpaidOnly ? 1 : 0,
          summary: _unpaidOnly ? 'لم تُصرف فقط' : '',
          onOpen: _openFilters,
          onClear: () {
            setState(() {
              _unpaidOnly = false;
              _pageIndex = 0;
            });
            _load();
          },
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          MessagePanel(message: _error!, onRetry: _load),
          const SizedBox(height: 12),
        ],
        if (items.isEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.tokens.line),
            ),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : AppEmptyState(
                    icon: LucideIcons.filePlus2,
                    title: _unpaidOnly
                        ? 'لا توجد طلبات لم تُصرف'
                        : 'لا توجد طلبات حتى الآن',
                    message: 'تظهر هنا طلبات العهدة التي يرسلها الموظفون.',
                  ),
          )
        else
          AnimatedOpacity(
            opacity: _loading ? .55 : 1,
            duration: AppMotion.duration(context, AppMotion.feedback),
            child: Column(
              children: [
                for (final item in items) ...[
                  _RequestCard(
                    item: item,
                    busy: _busy.contains(item.id),
                    onOpen: () => showRequestDetail(context, item),
                    onApprove: _canApprove && item.status == 'PENDING'
                        ? () => _review(item, approve: true)
                        : null,
                    onReject: _canApprove && item.status == 'PENDING'
                        ? () => _review(item, approve: false)
                        : null,
                    onFund: _canFund && item.awaitingFunding
                        ? () => _fund(item)
                        : null,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        if (page != null) ...[
          const SizedBox(height: 4),
          AppPagination(
            page: _pageIndex,
            size: _pageSize,
            total: page.total,
            disabled: _loading,
            onChanged: (index) {
              setState(() => _pageIndex = index);
              _load();
            },
          ),
        ],
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.item,
    required this.busy,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
    required this.onFund,
  });

  final CustodyRequestItem item;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onFund;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final initials = item.requesterName
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join();
    final hasActions = onApprove != null || onReject != null || onFund != null;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: item.status == 'REJECTED'
              ? AppTokens.danger.withValues(alpha: .25)
              : tokens.line,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: tokens.washStrong,
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: tokens.brandStrong,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.requesterName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${item.centerName} · ${shortDate(item.createdAt)}',
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
                  requestStatusTag(item),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AppMoney(money(item.amount), size: 24),
                  const SizedBox(width: 6),
                  Text(
                    'ج.م',
                    style: TextStyle(
                      color: tokens.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (item.description?.isNotEmpty == true)
                Text(
                  item.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.7,
                    color: tokens.muted,
                  ),
                ),
              if (item.status != 'PENDING' && item.reviewerName != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${item.status == 'REJECTED' ? 'رفضه' : 'وافق عليه'} ${item.reviewerName}'
                  '${item.reviewedAt == null ? '' : ' · ${shortDate(item.reviewedAt!)}'}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (item.status == 'REJECTED' &&
                  item.reviewReason?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTokens.dangerTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.reviewReason!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF7A1A12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (item.status == 'APPROVED' &&
                  item.fundingStatus == 'PENDING') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.hourglass,
                      size: 14,
                      color: AppTokens.info,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'الصرف بانتظار مراجعة الخزنة',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              if (hasActions) ...[
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
                      if (onReject != null) ...[
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
                      ],
                      if (onApprove != null)
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
                      if (onFund != null)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onFund,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              backgroundColor: tokens.brandStrong,
                            ),
                            icon: const Icon(LucideIcons.landmark, size: 17),
                            label: const Text('صرف من الخزنة'),
                          ),
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirms an approval, or collects the reason the backend requires to reject.
/// Pops with the reason (empty for approvals) or null when cancelled.
class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.item, required this.approve});
  final CustodyRequestItem item;
  final bool approve;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: widget.approve ? 'الموافقة على الطلب' : 'رفض طلب العهدة',
    subtitle: '${widget.item.requesterName} · ${widget.item.centerName}',
    footer: AppSheetActions(
      primaryLabel: widget.approve ? 'تأكيد الموافقة' : 'تأكيد الرفض',
      primaryIcon: widget.approve ? LucideIcons.check : LucideIcons.x,
      destructive: !widget.approve,
      onPrimary: () {
        if (_form.currentState?.validate() ?? true) {
          Navigator.pop(context, _reason.text.trim());
        }
      },
      secondaryLabel: 'إلغاء',
      onSecondary: () => Navigator.pop(context),
    ),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: AppMoney('${money(widget.item.amount)} ج.م', size: 26)),
          const SizedBox(height: 6),
          Text(
            widget.approve
                ? 'بعد الموافقة يصبح الطلب جاهزًا للصرف من الخزنة.'
                : 'سيظهر سبب الرفض للموظف صاحب الطلب.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: context.tokens.muted),
          ),
          if (!widget.approve) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _reason,
              autofocus: true,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'سبب الرفض *',
                alignLabelWithHint: true,
                counterText: '',
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

/// Funds an approved request from a treasury. The movement carries the
/// request id, so the request reads «قيد الصرف» until the treasury approves it.
class _FundSheet extends StatefulWidget {
  const _FundSheet({required this.treasury, required this.request});
  final TreasuryRepository treasury;
  final CustodyRequestItem request;

  @override
  State<_FundSheet> createState() => _FundSheetState();
}

class _FundSheetState extends State<_FundSheet> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: widget.request.amount);
  late final _description = TextEditingController(
    text: 'صرف طلب عهدة · ${widget.request.requesterName}',
  );
  List<TreasuryAccount> _treasuries = const [];
  String? _treasuryId;
  String _method = 'CASH';
  String _date = formatIsoDate(clock.now());
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.treasury
        .list()
        .then((list) {
          if (!mounted) return;
          final active = list.where((item) => item.active).toList();
          setState(() {
            _treasuries = active;
            _treasuryId =
                active.where((item) => item.defaultTreasury).firstOrNull?.id ??
                (active.length == 1 ? active.first.id : null);
          });
        })
        .catchError((Object error) {
          if (mounted) setState(() => _error = error.toString());
        })
        .whenComplete(() {
          if (mounted) setState(() => _loading = false);
        });
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.treasury.createMovement(
        treasuryId: _treasuryId!,
        type: 'CUSTODY_FUNDING',
        amount: _amount.text,
        entryDate: _date,
        description: _description.text,
        method: _method,
        recipientId: widget.request.requesterId,
        custodyRequestId: widget.request.id,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _treasuries
        .where((item) => item.id == _treasuryId)
        .firstOrNull;
    return AppSheetScaffold(
      title: 'صرف طلب العهدة',
      subtitle:
          '${widget.request.requesterName} · ${widget.request.centerName}',
      closeEnabled: !_busy,
      onClose: () => Navigator.pop(context, false),
      footer: AppSheetActions(
        primaryLabel: 'تسجيل الصرف',
        primaryIcon: LucideIcons.landmark,
        busy: _busy,
        busyLabel: 'جارٍ التسجيل…',
        onPrimary: _loading ? null : _submit,
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
            AppSelect<String>(
              label: 'الخزنة *',
              value: _treasuryId,
              enabled: !_busy && !_loading,
              placeholder: _loading ? 'جارٍ التحميل…' : 'اختر الخزنة',
              options: [
                for (final treasury in _treasuries)
                  AppSelectOption(
                    value: treasury.id,
                    label: treasury.name,
                    subtitle:
                        '${treasury.code} · رصيد ${money(treasury.balance)}',
                    fieldLabel: treasury.name,
                  ),
              ],
              onChanged: (value) => setState(() => _treasuryId = value),
              validator: (value) => value == null ? 'اختر الخزنة' : null,
            ),
            const SizedBox(height: 14),
            AppAmountField(
              controller: _amount,
              enabled: !_busy,
              hint: 'مبلغ الطلب',
              hintValue: money(widget.request.amount),
              currency:
                  selected?.currencyCode == null ||
                      selected!.currencyCode == 'EGP'
                  ? 'ج.م'
                  : selected.currencyCode,
              validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                  ? 'أدخل مبلغًا صحيحًا أكبر من صفر'
                  : null,
            ),
            const SizedBox(height: 14),
            Text(
              'طريقة الدفع',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.tokens.ink,
              ),
            ),
            const SizedBox(height: 6),
            AppSegmented<String>(
              value: _method,
              options: const [
                ('CASH', 'كاش', LucideIcons.banknote),
                ('BANK_TRANSFER', 'تحويل بنكي', LucideIcons.landmark),
                ('CHEQUE', 'شيك', LucideIcons.fileText),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _method = value),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: _busy
                  ? null
                  : () async {
                      final picked = await showAppDatePicker(
                        context: context,
                        initialDate: DateTime.tryParse(_date) ?? clock.now(),
                        firstDate: DateTime(2020),
                        lastDate: clock.now(),
                      );
                      if (picked != null) {
                        setState(() => _date = formatIsoDate(picked));
                      }
                    },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'تاريخ الصرف *',
                  suffixIcon: Icon(LucideIcons.calendarDays, size: 18),
                ),
                child: Text(shortDate(_date)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              enabled: !_busy,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'البيان',
                counterText: '',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'تُسجّل الحركة على الخزنة وتنتظر مراجعتها، ثم تُضاف إلى عهدة الموظف.',
              style: TextStyle(
                fontSize: 12,
                height: 1.7,
                color: context.tokens.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
