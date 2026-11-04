import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_filter.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../data/custody_repository.dart';
import '../domain/custody_models.dart';

/// How a ledger row reads to one viewer: icon, colours, label and signed amount.
class LedgerLook {
  const LedgerLook({
    required this.icon,
    required this.color,
    required this.tint,
    required this.label,
    required this.amount,
    required this.tone,
  });

  final IconData icon;
  final Color color;
  final Color tint;
  final String label;
  final String amount;
  final AppMoneyTone tone;

  factory LedgerLook.of(
    BuildContext context,
    LedgerItem item, {
    String? viewerId,
    bool signed = true,
  }) {
    final tokens = context.tokens;
    final raw = item.amount.replaceFirst(RegExp(r'^[+-]'), '');
    final value = money(raw);
    if (item.rejected) {
      return LedgerLook(
        icon: LucideIcons.receipt,
        color: AppTokens.danger,
        tint: AppTokens.dangerTint,
        label: 'مصروف مرفوض',
        amount: value,
        tone: AppMoneyTone.voided,
      );
    }
    return switch (item.kind) {
      LedgerKind.funding => LedgerLook(
        icon: LucideIcons.arrowDownLeft,
        color: AppTokens.success,
        tint: AppTokens.successTint,
        label: 'تمويل عهدة',
        amount: '+$value',
        tone: AppMoneyTone.incoming,
      ),
      LedgerKind.custodyReturn => LedgerLook(
        icon: LucideIcons.undo2,
        color: AppTokens.warning,
        tint: AppTokens.warningTint,
        label: 'رد عهدة',
        amount: '−$value',
        tone: AppMoneyTone.plain,
      ),
      LedgerKind.transfer when item.recipientId == viewerId => LedgerLook(
        icon: LucideIcons.arrowDownLeft,
        color: AppTokens.info,
        tint: AppTokens.infoTint,
        label: 'تحويل وارد',
        amount: '+$value',
        tone: AppMoneyTone.incoming,
      ),
      LedgerKind.transfer => LedgerLook(
        icon: LucideIcons.arrowUpRight,
        color: AppTokens.info,
        tint: AppTokens.infoTint,
        label: 'تحويل صادر',
        amount: '−$value',
        tone: AppMoneyTone.plain,
      ),
      LedgerKind.expense => LedgerLook(
        icon: LucideIcons.receipt,
        color: tokens.muted,
        tint: tokens.sunken,
        label: 'مصروف',
        amount: signed ? '−$value' : value,
        tone: AppMoneyTone.plain,
      ),
    };
  }
}

List<AppTableColumn> ledgerColumns({required bool aggregate}) => [
  const AppTableColumn('البيان', 180),
  const AppTableColumn('المبلغ', 112, numeric: true),
  if (aggregate) const AppTableColumn('الموظف', 130),
  const AppTableColumn('التاريخ', 96),
  const AppTableColumn('مركز التكلفة', 150),
  const AppTableColumn('بند الصرف', 150),
  const AppTableColumn('المقاول / المستند', 150),
  const AppTableColumn('الاعتماد', 124),
  const AppTableColumn('التصفية', 104),
];

List<Widget> ledgerCells(
  BuildContext context,
  LedgerItem item, {
  required bool aggregate,
  String? viewerId,
}) {
  final look = LedgerLook.of(
    context,
    item,
    viewerId: viewerId,
    signed: !aggregate,
  );
  final expense = item.kind == LedgerKind.expense;
  return [
    Row(
      children: [
        if (aggregate && item.isSnag) ...[
          const Icon(LucideIcons.flag, size: 14, color: AppTokens.snag),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: AppTableTitle(
            title: item.description,
            subtitle: look.label,
            dot: look.color,
          ),
        ),
      ],
    ),
    AppMoney(look.amount, tone: look.tone),
    if (aggregate)
      Text(item.ownerName, maxLines: 2, overflow: TextOverflow.ellipsis),
    Text(
      shortDate(item.entryDate),
      style: TextStyle(
        color: context.tokens.muted,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
    Text(
      expense ? item.center : '—',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    Text(
      expense ? item.category : look.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    Text(
      expense ? item.contractor : item.ownerName,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    _approvalCell(item),
    expense && !item.rejected
        ? item.settled
              ? const Text('مُصفّى')
              : const AppTag('غير مُصفّى', tone: AppTone.warning)
        : const Text('—'),
  ];
}

Widget _approvalCell(LedgerItem item) {
  if (item.rejected) {
    return const AppTag('مرفوض', tone: AppTone.danger, icon: LucideIcons.x);
  }
  return switch (item.kind) {
    LedgerKind.transfer =>
      item.approval == 'تم الاستلام'
          ? const AppTag('تم الاستلام', tone: AppTone.success)
          : const AppTag('بانتظار الاستلام', tone: AppTone.info),
    LedgerKind.expense => Text(
      item.approval,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    _ => Text(item.approval),
  };
}

/// Rejected rows read light red everywhere; Snag rows light orange, but only
/// for managers — the employee's own screen never shows Snag.
Color? ledgerRowColor(LedgerItem item, {required bool showSnag}) {
  if (item.rejected) return AppTokens.dangerTint;
  if (showSnag && item.isSnag) return AppTokens.snagTint;
  return null;
}

/// Review permissions for the aggregate screen. Null means a read-only sheet.
class LedgerReviewActions {
  const LedgerReviewActions({
    required this.canReview,
    required this.canCorrect,
    required this.categories,
  });

  final bool canReview;
  final bool canCorrect;
  final List<ExpenseFilterOption> categories;

  bool get any => canReview || canCorrect;
}

Future<void> showLedgerDetail(
  BuildContext context, {
  required LedgerItem item,
  required CustodyRepository repository,
  String? viewerId,
  LedgerReviewActions? actions,
  Future<void> Function()? onChanged,
  Widget? footer,
}) => showAppSheet<void>(
  context,
  tall: actions?.any == true,
  builder: (context) => _LedgerDetail(
    initial: item,
    repository: repository,
    viewerId: viewerId,
    actions: actions,
    onChanged: onChanged,
    footer: footer,
  ),
);

enum _Mode { view, edit, reject, correct }

class _LedgerDetail extends StatefulWidget {
  const _LedgerDetail({
    required this.initial,
    required this.repository,
    required this.viewerId,
    required this.actions,
    required this.onChanged,
    required this.footer,
  });

  final LedgerItem initial;
  final CustodyRepository repository;
  final String? viewerId;
  final LedgerReviewActions? actions;
  final Future<void> Function()? onChanged;
  final Widget? footer;

  @override
  State<_LedgerDetail> createState() => _LedgerDetailState();
}

class _LedgerDetailState extends State<_LedgerDetail> {
  late LedgerItem _item = widget.initial;
  final _form = GlobalKey<FormState>();
  late final _description = TextEditingController(text: _item.description);
  final _reason = TextEditingController();
  late final _amount = TextEditingController();
  String? _categoryId;
  String _date = '';
  _Mode _mode = _Mode.view;
  bool _loading = false;
  bool _busy = false;
  String? _error;
  final Map<String, Future<Uint8List>> _invoiceLoads = {};

  bool get _expense => _item.kind == LedgerKind.expense;
  bool get _showSnag => widget.actions != null;

  @override
  void initState() {
    super.initState();
    _categoryId = _item.categoryId;
    if (_expense) _refresh();
  }

  @override
  void dispose() {
    _description.dispose();
    _reason.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final item = await widget.repository.expense(_item.id);
      if (mounted) setState(() => _adopt(item));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _adopt(LedgerItem item) {
    _item = item;
    _categoryId = item.categoryId;
    _description.text = item.description;
  }

  void _enter(_Mode mode) => setState(() {
    _mode = mode;
    _error = null;
    _reason.clear();
    if (mode == _Mode.correct) {
      _amount.text = _item.amount.replaceFirst(RegExp(r'^[+-]'), '');
      _date = _item.entryDate;
    }
    if (mode == _Mode.edit) _adopt(_item);
  });

  Future<void> _run(Future<LedgerItem> Function() operation) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final item = await operation();
      if (!mounted) return;
      setState(() {
        _adopt(item);
        _mode = _Mode.view;
      });
      await widget.onChanged?.call();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? true)) return;
    switch (_mode) {
      case _Mode.edit:
        final categoryId = _categoryId;
        if (categoryId == null) return;
        await _run(
          () => widget.repository.editExpense(
            expense: _item,
            categoryId: categoryId,
            description: _description.text,
          ),
        );
      case _Mode.reject:
        await _run(
          () => widget.repository.rejectExpense(
            expense: _item,
            reason: _reason.text,
          ),
        );
      case _Mode.correct:
        await _run(
          () => widget.repository.correctExpense(
            expense: _item,
            amount: _amount.text,
            entryDate: _date,
            reason: _reason.text,
          ),
        );
      case _Mode.view:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final look = LedgerLook.of(
      context,
      _item,
      viewerId: widget.viewerId,
      signed: widget.actions == null,
    );
    return AppSheetScaffold(
      title: _expense ? 'تفاصيل بند العهدة' : 'تفاصيل الحركة',
      subtitle: widget.actions == null
          ? look.label
          : '${_item.ownerName} · ${look.label}',
      closeEnabled: !_busy,
      footer: _mode == _Mode.view
          ? widget.footer
          : AppSheetActions(
              primaryLabel: switch (_mode) {
                _Mode.reject => 'تأكيد الرفض',
                _Mode.correct => 'حفظ التصحيح',
                _ => 'حفظ التعديل',
              },
              primaryIcon: _mode == _Mode.reject
                  ? LucideIcons.x
                  : LucideIcons.save,
              destructive: _mode == _Mode.reject,
              busy: _busy,
              onPrimary: _submit,
              secondaryLabel: 'إلغاء',
              onSecondary: () => setState(() {
                _mode = _Mode.view;
                _error = null;
              }),
            ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hero(item: _item, look: look, showSnag: _showSnag),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_mode == _Mode.view) ..._viewSections(context),
            if (_mode == _Mode.edit) ..._editFields(),
            if (_mode == _Mode.reject) ..._rejectFields(),
            if (_mode == _Mode.correct) ..._correctFields(context),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppTokens.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _viewSections(BuildContext context) {
    final actions = widget.actions;
    return [
      _Section(
        title: 'البيانات',
        child: _KeyValues([
          if (widget.actions != null) ('الموظف', _item.ownerName),
          (_expense ? 'تاريخ المصروف' : 'التاريخ', shortDate(_item.entryDate)),
          if (_expense) ...[
            ('مركز التكلفة', _item.center),
            ('اتجاه التكلفة', costDirectionLabel(_item.costDirection)),
            ('بند الصرف', _item.category),
            ('المقاول / المستند', _item.contractor),
          ] else
            ('الطرف', _item.ownerName),
        ]),
      ),
      if (_expense)
        _Section(
          title: 'الاعتماد والتصفية',
          child: _Timeline([
            if (_item.createdAt?.isNotEmpty == true)
              _Step(
                'سُجّل البند',
                dateTimeLabel(_item.createdAt!),
                _StepState.done,
              )
            else
              const _Step('سُجّل البند', null, _StepState.done),
            if (_item.updatedAt?.isNotEmpty == true &&
                _item.updatedAt != _item.createdAt)
              _Step(
                'آخر تحديث',
                dateTimeLabel(_item.updatedAt!),
                _StepState.done,
              ),
            if (_item.rejected)
              _Step(
                _item.rejecterName == null
                    ? 'رُفض البند'
                    : 'رفضه ${_item.rejecterName}',
                _item.rejectedAt == null
                    ? null
                    : dateTimeLabel(_item.rejectedAt!),
                _StepState.failed,
                note: _item.rejectionReason,
              )
            else ...[
              _Step(
                _item.approval == 'اعتماد تلقائي'
                    ? 'اعتماد تلقائي'
                    : 'اعتمده ${_item.approval}',
                _item.approvedAt == null
                    ? 'فور التسجيل'
                    : dateTimeLabel(_item.approvedAt!),
                _StepState.done,
              ),
              _Step(
                _item.settled ? 'تمت التصفية' : 'بانتظار التصفية',
                _item.settled
                    ? 'ضمن تسوية العهدة'
                    : 'تتم مع تسوية العهدة القادمة',
                _item.settled ? _StepState.done : _StepState.waiting,
              ),
            ],
          ]),
        ),
      if (_expense)
        _Section(
          title: 'صور الفواتير (${_item.invoices.length})',
          child: _item.invoices.isEmpty
              ? Text(
                  'لا توجد صور مرفقة',
                  style: TextStyle(color: context.tokens.muted, fontSize: 13),
                )
              : SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _item.invoices.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final invoice = _item.invoices[index];
                      return _InvoiceThumb(
                        bytes: _invoiceLoads.putIfAbsent(
                          invoice.id,
                          () => widget.repository.invoiceBytes(invoice.id),
                        ),
                      );
                    },
                  ),
                ),
        ),
      if (_item.note?.isNotEmpty == true)
        _Section(
          title: 'ملاحظات',
          child: Text(
            _item.note!,
            style: const TextStyle(fontSize: 13, height: 1.8),
          ),
        ),
      if (_expense && actions != null && actions.any)
        _Section(
          title: 'إجراءات المراجعة',
          child: AppFilterGrid(
            children: [
              if (actions.canReview)
                _ActionTile(
                  label: 'تعديل البند',
                  icon: LucideIcons.pencil,
                  onTap: _busy || _loading ? null : () => _enter(_Mode.edit),
                ),
              if (actions.canReview)
                _ActionTile(
                  label: _item.isSnag ? 'إزالة Snag' : 'تعليم Snag',
                  icon: LucideIcons.flag,
                  tone: AppTone.snag,
                  busy: _busy,
                  onTap: _busy || _loading
                      ? null
                      : () => _run(
                          () => widget.repository.setExpenseSnag(
                            expense: _item,
                            isSnag: !_item.isSnag,
                          ),
                        ),
                ),
              if (actions.canCorrect)
                _ActionTile(
                  label: 'تصحيح إداري',
                  icon: LucideIcons.scale,
                  onTap: _busy || _loading ? null : () => _enter(_Mode.correct),
                ),
              if (actions.canReview && _item.status == 'APPROVED')
                _ActionTile(
                  label: 'رفض البند',
                  icon: LucideIcons.x,
                  tone: AppTone.danger,
                  onTap: _busy || _loading ? null : () => _enter(_Mode.reject),
                ),
            ],
          ),
        ),
    ];
  }

  List<Widget> _editFields() {
    final categories = widget.actions?.categories ?? const [];
    return [
      _Section(
        title: 'تعديل البند',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSelect<String>(
              label: 'بند الصرف *',
              value: _categoryId,
              enabled: !_busy,
              options: [
                if (_item.categoryId != null &&
                    categories.every((value) => value.id != _item.categoryId))
                  AppSelectOption(
                    value: _item.categoryId!,
                    label: _item.category,
                  ),
                for (final category in categories)
                  AppSelectOption(value: category.id, label: category.label),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
              validator: (value) => value == null ? 'اختر بند الصرف' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              enabled: !_busy,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'البيان *',
                alignLabelWithHint: true,
                counterText: '',
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'البيان مطلوب' : null,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _rejectFields() => [
    _Section(
      title: 'رفض البند',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'سيظهر البند مرفوضًا للموظف ولن يُحسب على عهدته.',
            style: TextStyle(fontSize: 12.5, color: context.tokens.muted),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _reason,
            enabled: !_busy,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'سبب الرفض (اختياري)',
              alignLabelWithHint: true,
              counterText: '',
            ),
          ),
        ],
      ),
    ),
  ];

  List<Widget> _correctFields(BuildContext context) => [
    _Section(
      title: 'تصحيح إداري',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppAmountField(
            controller: _amount,
            label: 'المبلغ الصحيح *',
            enabled: !_busy,
            hint: 'المبلغ المسجّل',
            hintValue: money(_item.amount.replaceFirst(RegExp(r'^[+-]'), '')),
            validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                ? 'مبلغ غير صحيح'
                : null,
          ),
          const SizedBox(height: 12),
          FormField<String>(
            validator: (_) =>
                DateTime.tryParse(_date) == null ? 'تاريخ غير صحيح' : null,
            builder: (state) => InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: _busy
                  ? null
                  : () async {
                      final picked = await showAppDatePicker(
                        context: context,
                        initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _date = formatIsoDate(picked));
                      }
                    },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'التاريخ الصحيح *',
                  errorText: state.errorText,
                  suffixIcon: const Icon(LucideIcons.calendarDays, size: 18),
                ),
                child: Text(shortDate(_date)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _reason,
            enabled: !_busy,
            minLines: 2,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'سبب التصحيح *',
              alignLabelWithHint: true,
              counterText: '',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'سبب التصحيح مطلوب'
                : null,
          ),
        ],
      ),
    ),
  ];
}

class _Hero extends StatelessWidget {
  const _Hero({required this.item, required this.look, required this.showSnag});

  final LedgerItem item;
  final LedgerLook look;
  final bool showSnag;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final expense = item.kind == LedgerKind.expense;
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.line)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: look.tint,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(look.icon, color: look.color, size: 24),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AppMoney(look.amount, tone: look.tone, size: 30),
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
          const SizedBox(height: 2),
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              if (item.rejected)
                const AppTag('مرفوض', tone: AppTone.danger, icon: LucideIcons.x)
              else if (expense) ...[
                const AppTag(
                  'معتمد',
                  tone: AppTone.success,
                  icon: LucideIcons.check,
                ),
                item.settled
                    ? const AppTag('مُصفّى')
                    : const AppTag('غير مُصفّى', tone: AppTone.warning),
              ] else if (item.kind == LedgerKind.transfer)
                item.approval == 'تم الاستلام'
                    ? const AppTag('تم الاستلام', tone: AppTone.success)
                    : const AppTag('بانتظار الاستلام', tone: AppTone.info),
              if (showSnag && item.isSnag)
                const AppTag(
                  'Snag',
                  tone: AppTone.snag,
                  icon: LucideIcons.flag,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: context.tokens.muted,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _KeyValues extends StatelessWidget {
  const _KeyValues(this.rows);
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
                      value.isEmpty ? '—' : value,
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

enum _StepState { done, waiting, failed }

class _Step {
  const _Step(this.title, this.subtitle, this.state, {this.note});
  final String title;
  final String? subtitle;
  final _StepState state;
  final String? note;
}

class _Timeline extends StatelessWidget {
  const _Timeline(this.steps);
  final List<_Step> steps;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      children: [
        for (final (i, step) in steps.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: switch (step.state) {
                          _StepState.done => AppTokens.successTint,
                          _StepState.failed => AppTokens.dangerTint,
                          _StepState.waiting => tokens.sunken,
                        },
                        border: step.state == _StepState.waiting
                            ? Border.all(color: tokens.line, width: 1.5)
                            : null,
                      ),
                      child: Icon(
                        switch (step.state) {
                          _StepState.done => LucideIcons.check,
                          _StepState.failed => LucideIcons.x,
                          _StepState.waiting => LucideIcons.clock,
                        },
                        size: 13,
                        color: switch (step.state) {
                          _StepState.done => AppTokens.success,
                          _StepState.failed => AppTokens.danger,
                          _StepState.waiting => tokens.muted,
                        },
                      ),
                    ),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: tokens.line,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (step.subtitle != null)
                          Text(
                            step.subtitle!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: tokens.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (step.note?.isNotEmpty == true)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTokens.dangerTint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              step.note!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.7,
                                color: Color(0xFF7A1A12),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.tone = AppTone.neutral,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final AppTone tone;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (fg, bg) = switch (tone) {
      AppTone.danger => (AppTokens.danger, AppTokens.dangerTint),
      AppTone.snag => (AppTokens.snag, AppTokens.snagTint),
      _ => (tokens.brandStrong, tokens.wash),
    };
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tokens.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: fg,
                        ),
                      )
                    : Icon(icon, size: 17, color: fg),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: onTap == null ? tokens.muted : tokens.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoiceThumb extends StatelessWidget {
  const _InvoiceThumb({required this.bytes});
  final Future<Uint8List> bytes;

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: bytes,
    builder: (context, snapshot) => SizedBox(
      width: 92,
      child: Material(
        color: context.tokens.sunken,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: context.tokens.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: snapshot.hasData
              ? () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    insetPadding: const EdgeInsets.all(14),
                    backgroundColor: Colors.black87,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: InteractiveViewer(
                            minScale: .8,
                            maxScale: 5,
                            child: Center(
                              child: Image.memory(
                                snapshot.data!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          top: 8,
                          end: 8,
                          child: IconButton.filled(
                            tooltip: 'إغلاق',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(LucideIcons.x),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          child: snapshot.hasData
              ? Image.memory(snapshot.data!, fit: BoxFit.cover, cacheWidth: 300)
              : snapshot.hasError
              ? const Icon(LucideIcons.fileWarning, color: AppTokens.danger)
              : const Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
        ),
      ),
    ),
  );
}

String costDirectionLabel(String? value) => switch (value) {
  'OFFICE' => 'إدارة',
  'PROJECT' => 'مشروع',
  null || '' => '—',
  _ => value,
};

String dateTimeLabel(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${shortDate(value)} · $hour:$minute';
}
