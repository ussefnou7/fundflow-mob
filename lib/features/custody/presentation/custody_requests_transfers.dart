import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/format/exact_decimal.dart';
import '../../../core/media/invoice_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../data/custody_repository.dart';
import '../domain/custody_models.dart';
import 'custody_ledger.dart';
import 'custody_widgets.dart';

// ---------------------------------------------------------------------------
// Requests
// ---------------------------------------------------------------------------

AppTag requestStatusTag(CustodyRequestItem item) => switch (item.status) {
  'PENDING' => const AppTag(
    'بانتظار الموافقة',
    tone: AppTone.warning,
    icon: LucideIcons.clock,
  ),
  'REJECTED' => const AppTag(
    'مرفوض',
    tone: AppTone.danger,
    icon: LucideIcons.x,
  ),
  _ => switch (item.fundingStatus) {
    'FUNDED' => const AppTag(
      'تم الصرف',
      tone: AppTone.success,
      icon: LucideIcons.check,
    ),
    'PENDING' => const AppTag(
      'قيد الصرف',
      tone: AppTone.info,
      icon: LucideIcons.hourglass,
    ),
    _ => const AppTag(
      'معتمد · لم يُصرف',
      tone: AppTone.info,
      icon: LucideIcons.check,
    ),
  },
};

const requestColumns = [
  AppTableColumn('الموقع', 180),
  AppTableColumn('المبلغ', 118, numeric: true),
  AppTableColumn('الحالة', 150),
  AppTableColumn('تاريخ الطلب', 104),
  AppTableColumn('الوصف', 200),
  AppTableColumn('المراجِع', 130),
];

List<Widget> requestCells(BuildContext context, CustodyRequestItem item) => [
  AppTableTitle(title: item.centerName),
  AppMoney(money(item.amount)),
  requestStatusTag(item),
  Text(
    shortDate(item.createdAt),
    style: TextStyle(color: context.tokens.muted),
  ),
  Text(
    item.description?.isNotEmpty == true ? item.description! : '—',
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  ),
  Text(item.reviewerName ?? '—', style: TextStyle(color: context.tokens.muted)),
];

Future<void> showRequestDetail(
  BuildContext context,
  CustodyRequestItem item, {
  Widget? footer,
}) => showAppSheet<void>(
  context,
  builder: (context) => AppSheetScaffold(
    title: 'تفاصيل طلب العهدة',
    subtitle: item.requesterName,
    footer: footer,
    child: RequestSummary(item: item),
  ),
);

/// The request's amount, status and the steps it went through.
class RequestSummary extends StatelessWidget {
  const RequestSummary({super.key, required this.item});
  final CustodyRequestItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final approved = item.status == 'APPROVED';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTokens.successTint,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              LucideIcons.filePlus2,
              color: AppTokens.success,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(child: AppMoney('${money(item.amount)} ج.م', size: 28)),
        if (item.description?.isNotEmpty == true)
          Text(
            item.description!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        const SizedBox(height: 10),
        Center(child: requestStatusTag(item)),
        const SizedBox(height: 18),
        _InfoBox([
          ('مقدّم الطلب', item.requesterName),
          ('الموقع', item.centerName),
          ('تاريخ الطلب', dateTimeLabel(item.createdAt)),
        ]),
        const SizedBox(height: 16),
        Text(
          'المتابعة',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: tokens.muted,
          ),
        ),
        const SizedBox(height: 8),
        _Steps([
          ('أُرسل الطلب إلى المدير', shortDate(item.createdAt), true, false),
          if (item.status == 'PENDING')
            ('بانتظار الموافقة', 'يصلك إشعار عند المراجعة', false, false)
          else
            (
              item.status == 'REJECTED'
                  ? 'رفضه ${item.reviewerName ?? ''}'
                  : 'وافق عليه ${item.reviewerName ?? ''}',
              item.reviewedAt == null ? null : dateTimeLabel(item.reviewedAt!),
              true,
              item.status == 'REJECTED',
            ),
          if (approved)
            (
              switch (item.fundingStatus) {
                'FUNDED' => 'تم الصرف إلى العهدة',
                'PENDING' => 'الصرف بانتظار مراجعة الخزنة',
                _ => 'بانتظار الصرف',
              },
              item.fundingStatus == 'FUNDED'
                  ? 'أُضيف المبلغ كتمويل عهدة'
                  : 'يُصرف من الخزنة بعد الموافقة',
              item.fundingStatus == 'FUNDED',
              false,
            ),
        ], reason: item.status == 'REJECTED' ? item.reviewReason : null),
      ],
    );
  }
}

Future<bool> showRequestForm({
  required BuildContext context,
  required CustodyRepository repository,
}) async =>
    await showAppSheet<bool>(
      context,
      dismissible: false,
      builder: (context) => _RequestForm(repository: repository),
    ) ??
    false;

class _RequestForm extends StatefulWidget {
  const _RequestForm({required this.repository});
  final CustodyRepository repository;

  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  List<NamedOption> _sites = const [];
  String? _siteId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.repository
        .requestSites()
        .then((sites) {
          if (mounted) setState(() => _sites = sites);
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
      await widget.repository.createRequest(
        centerId: _siteId!,
        amount: _amount.text,
        description: _description.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: 'طلب عهدة',
    subtitle: 'يُرسل إلى المدير للموافقة ثم الصرف',
    closeEnabled: !_busy,
    onClose: () => Navigator.pop(context, false),
    footer: AppSheetActions(
      primaryLabel: 'إرسال الطلب',
      primaryIcon: LucideIcons.send,
      busy: _busy,
      busyLabel: 'جارٍ الإرسال…',
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
          AppAmountField(
            controller: _amount,
            enabled: !_busy,
            validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                ? 'أدخل مبلغًا صحيحًا أكبر من صفر'
                : null,
          ),
          const SizedBox(height: 14),
          AppSelect<String>(
            label: 'الموقع *',
            value: _siteId,
            enabled: !_busy && !_loading,
            placeholder: _loading ? 'جارٍ التحميل…' : 'اختر الموقع',
            options: [
              for (final site in _sites)
                AppSelectOption(
                  value: site.id,
                  label: site.name,
                  subtitle: site.code,
                ),
            ],
            onChanged: (value) => setState(() => _siteId = value),
            validator: (value) => value == null ? 'اختر الموقع' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            enabled: !_busy,
            maxLength: 1000,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(
              labelText: 'الوصف (اختياري)',
              hintText: 'مثال: تمويل أعمال الخرسانة للدور الخامس',
              alignLabelWithHint: true,
              counterText: '',
            ),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Transfers
// ---------------------------------------------------------------------------

bool transferIncoming(CustodyTransferItem item, String viewerId) =>
    item.recipientId == viewerId;

AppTag transferStatusTag(CustodyTransferItem item) => item.receivedAt == null
    ? const AppTag(
        'بانتظار الاستلام',
        tone: AppTone.info,
        icon: LucideIcons.clock,
      )
    : const AppTag(
        'تم الاستلام',
        tone: AppTone.success,
        icon: LucideIcons.check,
      );

const transferColumns = [
  AppTableColumn('الطرف', 170),
  AppTableColumn('المبلغ', 112, numeric: true),
  AppTableColumn('الاستلام', 104),
  AppTableColumn('الحالة', 140),
  AppTableColumn('التاريخ', 104),
  AppTableColumn('الوصف', 190),
];

List<Widget> transferCells(
  BuildContext context,
  CustodyTransferItem item, {
  required String viewerId,
  required ValueChanged<CustodyTransferItem>? onReceive,
}) {
  final incoming = transferIncoming(item, viewerId);
  return [
    AppTableTitle(
      title: incoming
          ? 'وارد من ${item.senderName}'
          : 'صادر إلى ${item.recipientName}',
      dot: AppTokens.info,
    ),
    AppMoney(
      '${incoming ? '+' : '−'}${money(item.amount)}',
      tone: incoming ? AppMoneyTone.incoming : AppMoneyTone.plain,
    ),
    if (item.receivedAt != null)
      Text(
        shortDate(item.receivedAt!),
        style: TextStyle(color: context.tokens.muted),
      )
    else if (incoming && onReceive != null)
      FilledButton(
        onPressed: () => onReceive(item),
        style: FilledButton.styleFrom(
          minimumSize: const Size(72, 34),
          backgroundColor: context.tokens.brandStrong,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: const Text('استلام'),
      )
    else
      Text('عند المستلم', style: TextStyle(color: context.tokens.muted)),
    transferStatusTag(item),
    Text(
      shortDate(item.createdAt),
      style: TextStyle(color: context.tokens.muted),
    ),
    Text(
      item.description?.isNotEmpty == true ? item.description! : '—',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
  ];
}

Future<void> showTransferDetail(
  BuildContext context,
  CustodyTransferItem item, {
  required String viewerId,
  VoidCallback? onReceive,
}) {
  final incoming = transferIncoming(item, viewerId);
  return showAppSheet<void>(
    context,
    builder: (context) => AppSheetScaffold(
      title: 'تفاصيل التحويل',
      subtitle: incoming ? 'تحويل وارد' : 'تحويل صادر',
      footer: incoming && item.receivedAt == null && onReceive != null
          ? AppSheetActions(
              primaryLabel: 'استلام التحويل',
              onPrimary: () {
                Navigator.pop(context);
                onReceive();
              },
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AppMoney(
              '${incoming ? '+' : '−'}${money(item.amount)} ج.م',
              tone: incoming ? AppMoneyTone.incoming : AppMoneyTone.plain,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Center(child: transferStatusTag(item)),
          const SizedBox(height: 18),
          _InfoBox([
            ('المُرسل', item.senderName),
            ('المستلم', item.recipientName),
            ('تاريخ الإرسال', dateTimeLabel(item.createdAt)),
            if (item.receivedAt != null)
              ('تاريخ الاستلام', dateTimeLabel(item.receivedAt!)),
            if (item.description?.isNotEmpty == true)
              ('الوصف', item.description!),
          ]),
          if (item.receivedAt == null) ...[
            const SizedBox(height: 12),
            Text(
              'يتغير الرصيد بعد تأكيد المستلم.',
              style: TextStyle(fontSize: 12.5, color: context.tokens.muted),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Asks before adding an incoming transfer to the balance; true once received.
Future<bool> confirmReceiveTransfer(
  BuildContext context,
  CustodyRepository repository,
  CustodyTransferItem item,
) async =>
    await showAppSheet<bool>(
      context,
      builder: (context) => _ReceiveSheet(repository: repository, item: item),
    ) ??
    false;

class _ReceiveSheet extends StatefulWidget {
  const _ReceiveSheet({required this.repository, required this.item});
  final CustodyRepository repository;
  final CustodyTransferItem item;

  @override
  State<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<_ReceiveSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _receive() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.receiveTransfer(widget.item.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: 'استلام تحويل عهدة',
    subtitle: 'من ${widget.item.senderName}',
    closeEnabled: !_busy,
    footer: AppSheetActions(
      primaryLabel: 'تأكيد الاستلام',
      busy: _busy,
      busyLabel: 'جارٍ الاستلام…',
      onPrimary: _receive,
      secondaryLabel: 'لاحقًا',
      onSecondary: () => Navigator.pop(context, false),
    ),
    child: Column(
      children: [
        AppMoney('${money(widget.item.amount)} ج.م', size: 28),
        const SizedBox(height: 8),
        Text(
          'بعد الاستلام يُضاف المبلغ إلى رصيدك الحالي، ولا يمكن التراجع عنه من التطبيق.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.8,
            color: context.tokens.muted,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppTokens.danger)),
        ],
      ],
    ),
  );
}

Future<bool> showTransferForm({
  required BuildContext context,
  required CustodyRepository repository,
  required String userId,
}) async =>
    await showAppSheet<bool>(
      context,
      tall: true,
      dismissible: false,
      builder: (context) =>
          _TransferForm(repository: repository, userId: userId),
    ) ??
    false;

class _TransferForm extends StatefulWidget {
  const _TransferForm({required this.repository, required this.userId});
  final CustodyRepository repository;
  final String userId;

  @override
  State<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<_TransferForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  List<NamedOption> _recipients = const [];
  CustodyBalance? _balance;
  String? _recipientId;
  XFile? _image;
  bool _loading = true;
  bool _busy = false;
  bool _imageMissing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.repository.transferRecipients(),
        widget.repository.balance(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _recipients = results.first as List<NamedOption>;
        _balance = results.last as CustodyBalance;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _overBalance {
    final balance = ExactDecimal.tryParse(_balance?.remaining ?? '');
    final amount = ExactDecimal.tryParse(_amount.text);
    return balance != null && amount != null && amount.compareTo(balance) > 0;
  }

  Future<void> _pick({required bool camera}) async {
    final files = await pickInvoiceImages(
      context,
      camera: camera,
      single: true,
    );
    if (files.isNotEmpty && mounted) {
      setState(() {
        _image = files.first;
        _imageMissing = false;
      });
    }
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    setState(() => _imageMissing = _image == null);
    if (!valid || _image == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.createTransfer(
        recipientId: _recipientId!,
        amount: _amount.text,
        description: _description.text,
        imagePath: _image!.path,
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
    final tokens = context.tokens;
    return AppSheetScaffold(
      title: 'تحويل عهدة',
      subtitle: 'من عهدتك إلى عهدة موظف آخر',
      closeEnabled: !_busy,
      onClose: () => Navigator.pop(context, false),
      footer: AppSheetActions(
        primaryLabel: 'إرسال التحويل',
        primaryIcon: LucideIcons.arrowLeftRight,
        busy: _busy,
        busyLabel: 'جارٍ الإرسال…',
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
              label: 'المرسل إليه *',
              value: _recipientId,
              enabled: !_busy && !_loading,
              placeholder: _loading ? 'جارٍ التحميل…' : 'اختر الموظف',
              options: [
                for (final person in _recipients)
                  AppSelectOption(
                    value: person.id,
                    label: person.name,
                    subtitle: person.code,
                  ),
              ],
              onChanged: (value) => setState(() => _recipientId = value),
              validator: (value) => value == null ? 'اختر المرسل إليه' : null,
            ),
            const SizedBox(height: 14),
            AppAmountField(
              controller: _amount,
              enabled: !_busy,
              hint: _overBalance ? 'أكبر من رصيد عهدتك' : 'رصيد عهدتك الحالي',
              hintValue: _balance == null ? null : money(_balance!.remaining),
              warning: _overBalance,
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if ((double.tryParse(value ?? '') ?? 0) <= 0) {
                  return 'أدخل مبلغًا صحيحًا أكبر من صفر';
                }
                return _overBalance ? 'المبلغ أكبر من رصيد عهدتك' : null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'صورة التحويل *',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _imageMissing ? AppTokens.danger : tokens.ink,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 84,
              child: Row(
                children: [
                  if (_image != null)
                    SizedBox(
                      width: 84,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(_image!.path),
                              fit: BoxFit.cover,
                              cacheWidth: 300,
                              errorBuilder: (_, error, stack) =>
                                  const Icon(LucideIcons.fileImage),
                            ),
                            PositionedDirectional(
                              top: 4,
                              end: 4,
                              child: IconButton.filled(
                                tooltip: 'حذف الصورة',
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _image = null),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                                constraints: const BoxConstraints.tightFor(
                                  width: 24,
                                  height: 24,
                                ),
                                padding: EdgeInsets.zero,
                                icon: const Icon(LucideIcons.x, size: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    _PickTile(
                      icon: LucideIcons.camera,
                      label: 'تصوير',
                      error: _imageMissing,
                      onTap: _busy ? null : () => _pick(camera: true),
                    ),
                    const SizedBox(width: 8),
                    _PickTile(
                      icon: LucideIcons.images,
                      label: 'المعرض',
                      error: _imageMissing,
                      onTap: _busy ? null : () => _pick(camera: false),
                    ),
                  ],
                ],
              ),
            ),
            if (_imageMissing)
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text(
                  'أرفق صورة التحويل',
                  style: TextStyle(color: AppTokens.danger, fontSize: 12),
                ),
              ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              enabled: !_busy,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'الوصف (اختياري)',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: tokens.sunken,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.info, size: 16, color: AppTokens.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'يظهر المبلغ في «صادر معلّق»، ويتغير الرصيد بعد تأكيد المستلم.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.7,
                        color: tokens.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.error = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = error ? AppTokens.danger : tokens.brand;
    return Material(
      color: tokens.wash,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: .4)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.rows);
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
    );
  }
}

/// title, subtitle, done, failed
class _Steps extends StatelessWidget {
  const _Steps(this.steps, {this.reason});
  final List<(String, String?, bool, bool)> steps;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        for (final (title, subtitle, done, failed) in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: failed
                        ? AppTokens.dangerTint
                        : done
                        ? AppTokens.successTint
                        : tokens.sunken,
                    border: done || failed
                        ? null
                        : Border.all(color: tokens.line, width: 1.5),
                  ),
                  child: Icon(
                    failed
                        ? LucideIcons.x
                        : done
                        ? LucideIcons.check
                        : LucideIcons.clock,
                    size: 13,
                    color: failed
                        ? AppTokens.danger
                        : done
                        ? AppTokens.success
                        : tokens.muted,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: tokens.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (failed && reason?.isNotEmpty == true)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTokens.dangerTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            reason!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF7A1A12),
                              fontWeight: FontWeight.w600,
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
}
