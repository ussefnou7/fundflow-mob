import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/app_buttons.dart';
import '../../../core/format/exact_decimal.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/domain/custody_models.dart' show shortDate;
import '../../custody/presentation/custody_widgets.dart';
import '../../workflow/data/workflow_repository.dart';
import '../../workflow/presentation/workflow_panel.dart';
import '../data/scm_repository.dart';
import '../domain/scm_models.dart';
import 'scm_document_form_widgets.dart';

Future<bool?> showScmDocumentDetail(
  BuildContext context, {
  required ScmRepository repository,
  required ScmDocumentKind kind,
  required String id,
  required String documentNo,
  required Set<String> permissions,
  String? currentUserId,
  WorkflowRepository? workflow,
}) => showAppSheet<bool>(
  context,
  tall: true,
  builder: (_) => _ScmDocumentSheet(
    repository: repository,
    kind: kind,
    id: id,
    documentNo: documentNo,
    permissions: permissions,
    currentUserId: currentUserId,
    workflow: workflow,
  ),
);

class ScmDocumentsScreen extends StatefulWidget {
  const ScmDocumentsScreen({
    super.key,
    required this.repository,
    required this.kind,
    required this.permissions,
    this.currentUserId,
    this.workflow,
  });

  final ScmRepository repository;
  final ScmDocumentKind kind;
  final Set<String> permissions;
  final String? currentUserId;
  final WorkflowRepository? workflow;

  @override
  State<ScmDocumentsScreen> createState() => _ScmDocumentsScreenState();
}

class _ScmDocumentsScreenState extends State<ScmDocumentsScreen> {
  ScmPage<ScmDocumentSummary>? _result;
  int _page = 0;
  bool _loading = true;
  String? _error;

  bool get _canCreate => switch (widget.kind) {
    ScmDocumentKind.requests => widget.permissions.contains(
      'SCM_REQUESTS_CREATE',
    ),
    ScmDocumentKind.orders => widget.permissions.contains('SCM_ORDERS_MANAGE'),
    ScmDocumentKind.cashPurchases =>
      widget.permissions.contains('SCM_CASH_PURCHASES_CREATE') &&
          widget.permissions.contains('CUSTODY_EXPENSE_CREATE'),
    ScmDocumentKind.receipts => false,
  };

  String get _createLabel => switch (widget.kind) {
    ScmDocumentKind.requests => 'طلب جديد',
    ScmDocumentKind.orders => 'أمر جديد',
    ScmDocumentKind.cashPurchases => 'فاتورة جديدة',
    ScmDocumentKind.receipts => '',
  };

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
      final result = await widget.repository.documents(
        widget.kind,
        page: _page,
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final saved = await showAppSheet<bool>(
      context,
      tall: true,
      dismissible: false,
      builder: (_) => switch (widget.kind) {
        ScmDocumentKind.requests => _PurchaseRequestSheet(
          repository: widget.repository,
        ),
        ScmDocumentKind.orders ||
        ScmDocumentKind.cashPurchases => _PurchaseDocumentSheet(
          repository: widget.repository,
          kind: widget.kind,
        ),
        ScmDocumentKind.receipts => const SizedBox.shrink(),
      },
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _open(ScmDocumentSummary summary) async {
    final changed = await showScmDocumentDetail(
      context,
      repository: widget.repository,
      kind: widget.kind,
      id: summary.id,
      documentNo: summary.documentNo,
      permissions: widget.permissions,
      currentUserId: widget.currentUserId,
      workflow: widget.workflow,
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _result?.items ?? const <ScmDocumentSummary>[];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          PageHeader(
            title: _title(widget.kind),
            subtitle: '${_result?.total ?? 0} مستند',
            action: _canCreate
                ? AppAddButton(
                    key: ValueKey('create-${widget.kind.name}'),
                    label: _createLabel,
                    onPressed: _create,
                  )
                : null,
          ),
          if (widget.kind == ScmDocumentKind.receipts) ...[
            const SizedBox(height: 10),
            _ScmFlowHint(kind: widget.kind),
          ],
          if (_loading && _result != null) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 12),
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _load)
          else if (_loading && _result == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (items.isEmpty)
            AppEmptyState(
              icon: _icon(widget.kind),
              title: 'لا توجد ${_title(widget.kind)}',
            )
          else ...[
            for (final item in items) ...[
              _ScmDocumentCard(item: item, onTap: () => _open(item)),
              const SizedBox(height: 10),
            ],
            AppPagination(
              page: _page,
              size: _result!.size,
              total: _result!.total,
              disabled: _loading,
              onChanged: (page) {
                setState(() => _page = page);
                _load();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ScmDocumentCard extends StatelessWidget {
  const _ScmDocumentCard({required this.item, required this.onTap});
  final ScmDocumentSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: context.tokens.line),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.documentNo,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        item.warehouse.name,
                        style: TextStyle(
                          color: context.tokens.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusTag(item.status),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                AppTag(shortDate(item.date), icon: LucideIcons.calendarDays),
                if (item.party?.isNotEmpty == true)
                  AppTag(item.party!, icon: LucideIcons.user),
                if (item.lineCount != null)
                  AppTag('${item.lineCount} بنود', icon: LucideIcons.list),
              ],
            ),
            if (item.total != null) ...[
              const SizedBox(height: 10),
              AppMoney('${item.total!} ${item.currency ?? 'EGP'}'),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ScmDocumentSheet extends StatefulWidget {
  const _ScmDocumentSheet({
    required this.repository,
    required this.kind,
    required this.id,
    required this.documentNo,
    required this.permissions,
    this.currentUserId,
    this.workflow,
  });
  final ScmRepository repository;
  final ScmDocumentKind kind;
  final String id, documentNo;
  final Set<String> permissions;
  final String? currentUserId;
  final WorkflowRepository? workflow;

  @override
  State<_ScmDocumentSheet> createState() => _ScmDocumentSheetState();
}

class _ScmDocumentSheetState extends State<_ScmDocumentSheet> {
  ScmDocumentDetail? _detail;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await widget.repository.document(widget.kind, widget.id);
      if (mounted) setState(() => _detail = detail);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      if (widget.kind == ScmDocumentKind.orders) {
        await widget.repository.submitOrder(_detail!.id, _detail!.version);
      } else if (widget.kind == ScmDocumentKind.receipts) {
        await widget.repository.confirmReceipt(_detail!.id, _detail!.version);
      } else {
        await widget.repository.submitRequest(_detail!.id, _detail!.version);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canEdit => _detail?.status == 'DRAFT' && _canSubmit;

  bool get _canSubmit => switch (widget.kind) {
    ScmDocumentKind.requests =>
      widget.permissions.contains('SCM_REQUESTS_CREATE') &&
          (_detail?.requestedBy?.id == widget.currentUserId ||
              widget.currentUserId == null),
    ScmDocumentKind.orders => widget.permissions.contains('SCM_ORDERS_MANAGE'),
    ScmDocumentKind.receipts =>
      widget.permissions.contains('SCM_RECEIPTS_RECEIVE') &&
          (_detail?.receivedBy?.id == widget.currentUserId ||
              widget.currentUserId == null),
    ScmDocumentKind.cashPurchases => false,
  };

  Future<void> _edit() async {
    final detail = _detail!;
    final saved = await showAppSheet<bool>(
      context,
      tall: true,
      dismissible: false,
      builder: (_) => switch (widget.kind) {
        ScmDocumentKind.requests => _PurchaseRequestSheet(
          repository: widget.repository,
          document: detail,
        ),
        ScmDocumentKind.orders => _PurchaseDocumentSheet(
          repository: widget.repository,
          kind: widget.kind,
          document: detail,
        ),
        ScmDocumentKind.receipts => _ReceiptEditSheet(
          repository: widget.repository,
          document: detail,
        ),
        ScmDocumentKind.cashPurchases => const SizedBox.shrink(),
      },
    );
    if (saved == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: '${_title(widget.kind)} ${widget.documentNo}',
    subtitle: _detail?.warehouse.name,
    footer: _canSubmit && _detail?.status == 'DRAFT'
        ? AppSheetActions(
            primaryLabel: widget.kind == ScmDocumentKind.receipts
                ? 'تأكيد الاستلام'
                : 'إرسال للموافقة',
            busy: _busy,
            onPrimary: _submit,
            secondaryLabel: _canEdit ? 'تعديل' : 'إغلاق',
            onSecondary: _canEdit ? _edit : () => Navigator.pop(context),
          )
        : null,
    child: _error != null
        ? MessagePanel(message: _error!, onRetry: _load)
        : _detail == null
        ? const Center(child: CircularProgressIndicator())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.workflow != null &&
                  _detail!.status != 'DRAFT' &&
                  _detail!.status != 'CANCELLED') ...[
                WorkflowPanel(
                  repository: widget.workflow!,
                  docType: _workflowDocType(widget.kind),
                  docId: _detail!.id,
                  onChanged: _load,
                ),
                const SizedBox(height: 18),
              ],
              Text(
                'تفاصيل المستند',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.tokens.sunken,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.tokens.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusTag(_detail!.status),
                        AppTag(
                          shortDate(_detail!.date),
                          icon: LucideIcons.calendarDays,
                        ),
                        if (_detail!.party?.isNotEmpty == true)
                          AppTag(_detail!.party!, icon: LucideIcons.user),
                      ],
                    ),
                    if (_detail!.total != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.tokens.line),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'إجمالي الفاتورة',
                                style: TextStyle(
                                  color: context.tokens.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            AppMoney(
                              '${_detail!.total!} ${_detail!.currency ?? 'EGP'}',
                              size: 19,
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_detail!.transportCost != null &&
                        _detail!.transportCost != '0' &&
                        _detail!.transportCost != '0.00') ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.tokens.line),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.truck,
                              size: 18,
                              color: context.tokens.brandStrong,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'تكلفة النقل',
                                style: TextStyle(
                                  color: context.tokens.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            AppMoney(
                              '${_detail!.transportCost!} ${_detail!.currency ?? 'EGP'}',
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'تفاصيل البنود',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              _ScmDocumentLinesTable(
                lines: _detail!.lines,
                currency: _detail!.currency ?? 'EGP',
              ),
              if (_detail!.notes?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('ملاحظات: ${_detail!.notes}'),
                ),
            ],
          ),
  );
}

class _ScmDocumentLinesTable extends StatelessWidget {
  const _ScmDocumentLinesTable({required this.lines, required this.currency});

  final List<ScmDocumentLine> lines;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final approved = lines.any((line) => line.approvedQuantity != null);
    final received = lines.any((line) => line.receivedQuantity != null);
    final priced = lines.any(
      (line) => line.unitPrice != null || line.total != null,
    );
    final noted = lines.any((line) => line.notes?.isNotEmpty == true);
    return AppDataTable<ScmDocumentLine>(
      rows: lines,
      columns: [
        const AppTableColumn('البند', 170),
        const AppTableColumn('الوحدة', 76),
        const AppTableColumn('الكمية', 82, numeric: true),
        if (approved) const AppTableColumn('المعتمد', 86, numeric: true),
        if (received) const AppTableColumn('المستلم', 86, numeric: true),
        if (priced) ...[
          const AppTableColumn('سعر الوحدة', 112, numeric: true),
          const AppTableColumn('الإجمالي', 120, numeric: true),
        ],
        if (noted) const AppTableColumn('ملاحظات', 150),
      ],
      cells: (line) => [
        AppTableTitle(title: line.description, subtitle: line.material.code),
        Text(line.unit),
        _tableNumber(line.quantity),
        if (approved) _tableNumber(line.approvedQuantity),
        if (received) _tableNumber(line.receivedQuantity),
        if (priced) ...[
          line.unitPrice == null
              ? const Text('—')
              : AppMoney('${line.unitPrice!} $currency'),
          line.total == null
              ? const Text('—')
              : AppMoney('${line.total!} $currency', size: 14.5),
        ],
        if (noted) Text(line.notes?.isNotEmpty == true ? line.notes! : '—'),
      ],
    );
  }

  Widget _tableNumber(String? value) => Text(
    value ?? '—',
    textDirection: TextDirection.ltr,
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );
}

class _PurchaseRequestSheet extends StatefulWidget {
  const _PurchaseRequestSheet({required this.repository, this.document});
  final ScmRepository repository;
  final ScmDocumentDetail? document;

  @override
  State<_PurchaseRequestSheet> createState() => _PurchaseRequestSheetState();
}

class _PurchaseRequestSheetState extends State<_PurchaseRequestSheet> {
  final _form = GlobalKey<FormState>();
  final _linesKey = GlobalKey<ScmDocumentLinesCardState>();
  final _notes = TextEditingController();
  final List<ScmLineDraft> _lines = [];
  ScmOptions? _options;
  String _warehouseId = '';
  DateTime _date = DateTime.now();
  DateTime? _needDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final document = widget.document;
    if (document != null) {
      _warehouseId = document.warehouse.id;
      _date = DateTime.parse(document.date);
      _needDate = document.needDate == null
          ? null
          : DateTime.parse(document.needDate!);
      _notes.text = document.notes ?? '';
      _lines.addAll(document.lines.map(_draftFromLine));
    }
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await widget.repository.options();
      if (mounted) setState(() => _options = options);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_linesKey.currentState?.hasOpenDraft == true) {
      setState(() => _error = 'احفظ أو ألغِ البند المفتوح أولًا');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = 'أضف بندًا واحدًا على الأقل');
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final lines = [
        for (final line in _lines)
          {
            'materialId': line.materialId,
            'unitId': line.unitId,
            'quantity': ExactDecimal.parse(line.quantity.text).toString(),
            if (line.notes.text.trim().isNotEmpty)
              'notes': line.notes.text.trim(),
          },
      ];
      final document = widget.document;
      if (document == null) {
        await widget.repository.createRequest(
          warehouseId: _warehouseId,
          date: _date.toIso8601String().substring(0, 10),
          needDate: _needDate?.toIso8601String().substring(0, 10),
          notes: _notes.text,
          lines: lines,
        );
      } else {
        await widget.repository.updateRequest(
          id: document.id,
          version: document.version,
          warehouseId: _warehouseId,
          date: _date.toIso8601String().substring(0, 10),
          needDate: _needDate?.toIso8601String().substring(0, 10),
          notes: _notes.text,
          lines: lines,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: widget.document == null ? 'طلب شراء جديد' : 'تعديل طلب الشراء',
    closeEnabled: !_saving,
    footer: AppSheetActions(
      primaryLabel: widget.document == null ? 'حفظ الطلب' : 'حفظ التعديلات',
      busy: _saving,
      onPrimary: _options == null ? null : _save,
      secondaryLabel: 'إلغاء',
      onSecondary: () => Navigator.pop(context),
    ),
    child: _options == null && _error == null
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  MessagePanel(message: _error!, onRetry: _loadOptions),
                ScmDocumentMasterCard(
                  title: 'بيانات الطلب',
                  children: [
                    AppSelect<String>(
                      label: 'المخزن *',
                      value: _warehouseId.isEmpty ? null : _warehouseId,
                      options: [
                        for (final item in _options?.warehouses ?? const [])
                          AppSelectOption(value: item.id, label: item.name),
                      ],
                      validator: (value) =>
                          value == null ? 'اختر المخزن' : null,
                      onChanged: (value) =>
                          setState(() => _warehouseId = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: 'تاريخ الطلب',
                            value: _date,
                            onChanged: (value) => setState(() => _date = value),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DateField(
                            label: 'تاريخ الاحتياج',
                            value: _needDate,
                            onChanged: (value) =>
                                setState(() => _needDate = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notes,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'ملاحظات'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ScmDocumentLinesCard(
                  key: _linesKey,
                  lines: _lines,
                  materials: _options?.materials ?? const [],
                  priced: false,
                  onChanged: () => setState(() => _error = null),
                ),
              ],
            ),
          ),
  );
}

class _PurchaseDocumentSheet extends StatefulWidget {
  const _PurchaseDocumentSheet({
    required this.repository,
    required this.kind,
    this.document,
  });

  final ScmRepository repository;
  final ScmDocumentKind kind;
  final ScmDocumentDetail? document;

  @override
  State<_PurchaseDocumentSheet> createState() => _PurchaseDocumentSheetState();
}

class _PurchaseDocumentSheetState extends State<_PurchaseDocumentSheet> {
  final _form = GlobalKey<FormState>();
  final _linesKey = GlobalKey<ScmDocumentLinesCardState>();
  final _notes = TextEditingController();
  final _supplierName = TextEditingController();
  final _invoiceNo = TextEditingController();
  final _currency = TextEditingController(text: 'EGP');
  final _transportCost = TextEditingController(text: '0');
  final _picker = ImagePicker();
  final List<ScmLineDraft> _lines = [];
  ScmOptions? _options;
  String _warehouseId = '',
      _supplierId = '',
      _receiverId = '',
      _categoryId = '';
  DateTime _date = DateTime.now();
  DateTime? _deliveryDate;
  List<XFile> _images = const [];
  bool _saving = false;
  String? _error;

  bool get _cash => widget.kind == ScmDocumentKind.cashPurchases;

  ExactDecimal get _total {
    var total = ExactDecimal.zero;
    for (final line in _lines) {
      total = total + line.lineTotal;
    }
    return total +
        (ExactDecimal.tryParse(_transportCost.text) ?? ExactDecimal.zero);
  }

  @override
  void initState() {
    super.initState();
    final document = widget.document;
    if (document != null) {
      _warehouseId = document.warehouse.id;
      _supplierId = document.supplier?.id ?? '';
      _receiverId = document.receiver?.id ?? '';
      _date = DateTime.parse(document.date);
      _deliveryDate = document.deliveryDate == null
          ? null
          : DateTime.parse(document.deliveryDate!);
      _currency.text = document.currency ?? 'EGP';
      _transportCost.text = document.transportCost ?? '0';
      _notes.text = document.notes ?? '';
      _lines.addAll(document.lines.map(_draftFromLine));
    }
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await widget.repository.options();
      if (!mounted) return;
      setState(() {
        _options = options;
        if (_cash && _categoryId.isEmpty) {
          _categoryId =
              options.expenseCategories
                  .where((item) => item.name.contains('خامات'))
                  .firstOrNull
                  ?.id ??
              '';
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _supplierName.dispose();
    _invoiceNo.dispose();
    _currency.dispose();
    _transportCost.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85, limit: 5);
    if (!mounted || picked.isEmpty) return;
    setState(() => _images = picked.take(5).toList(growable: false));
  }

  Future<void> _save() async {
    if (_linesKey.currentState?.hasOpenDraft == true) {
      setState(() => _error = 'احفظ أو ألغِ البند المفتوح أولًا');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = 'أضف بندًا واحدًا على الأقل');
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final lines = [
      for (final line in _lines)
        {
          if (!_cash) 'id': line.id,
          'materialId': line.materialId,
          'unitId': line.unitId,
          'quantity': ExactDecimal.parse(line.quantity.text).toString(),
          'unitPrice': ExactDecimal.parse(line.unitPrice.text).toString(),
          if (!_cash) 'requestLineId': line.requestLineId,
          if (line.notes.text.trim().isNotEmpty)
            'notes': line.notes.text.trim(),
        },
    ];
    try {
      if (_cash) {
        await widget.repository.createCashPurchase(
          warehouseId: _warehouseId,
          date: _date.toIso8601String().substring(0, 10),
          categoryId: _categoryId,
          supplierId: _supplierId.isEmpty ? null : _supplierId,
          supplierName: _supplierId.isEmpty ? _supplierName.text : null,
          invoiceNo: _invoiceNo.text,
          transportCost: _transportCost.text,
          notes: _notes.text,
          lines: lines,
          imagePaths: _images.map((item) => item.path).toList(growable: false),
        );
      } else if (widget.document == null) {
        await widget.repository.createOrder(
          warehouseId: _warehouseId,
          date: _date.toIso8601String().substring(0, 10),
          supplierId: _supplierId.isEmpty ? null : _supplierId,
          receiverId: _receiverId.isEmpty ? null : _receiverId,
          deliveryDate: _deliveryDate?.toIso8601String().substring(0, 10),
          currencyCode: _currency.text.trim().toUpperCase(),
          transportCost: _transportCost.text,
          notes: _notes.text,
          lines: lines,
        );
      } else {
        await widget.repository.updateOrder(
          id: widget.document!.id,
          version: widget.document!.version,
          warehouseId: _warehouseId,
          date: _date.toIso8601String().substring(0, 10),
          supplierId: _supplierId.isEmpty ? null : _supplierId,
          receiverId: _receiverId.isEmpty ? null : _receiverId,
          deliveryDate: _deliveryDate?.toIso8601String().substring(0, 10),
          currencyCode: _currency.text.trim().toUpperCase(),
          transportCost: _transportCost.text,
          notes: _notes.text,
          lines: lines,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: _cash
        ? 'فاتورة شراء نقدي جديدة'
        : widget.document == null
        ? 'أمر شراء جديد'
        : 'تعديل أمر الشراء',
    closeEnabled: !_saving,
    footer: AppSheetActions(
      primaryLabel: _cash
          ? 'حفظ الفاتورة'
          : widget.document == null
          ? 'حفظ الأمر'
          : 'حفظ التعديلات',
      busy: _saving,
      onPrimary: _options == null ? null : _save,
      secondaryLabel: 'إلغاء',
      onSecondary: () => Navigator.pop(context),
    ),
    child: _options == null && _error == null
        ? const Center(child: CircularProgressIndicator())
        : Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  MessagePanel(message: _error!, onRetry: _loadOptions),
                ScmDocumentMasterCard(
                  title: _cash ? 'بيانات الفاتورة' : 'بيانات أمر الشراء',
                  total: _total.money(),
                  currency: _cash ? 'EGP' : _currency.text.trim().toUpperCase(),
                  children: [
                    AppSelect<String>(
                      label: 'المخزن *',
                      value: _warehouseId.isEmpty ? null : _warehouseId,
                      options: [
                        for (final item in _options?.warehouses ?? const [])
                          AppSelectOption(value: item.id, label: item.name),
                      ],
                      validator: (value) =>
                          value == null ? 'اختر المخزن' : null,
                      onChanged: (value) =>
                          setState(() => _warehouseId = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    _DateField(
                      label: 'التاريخ',
                      value: _date,
                      onChanged: (value) => setState(() => _date = value),
                    ),
                    const SizedBox(height: 12),
                    AppSelect<String>(
                      label: 'المورد',
                      value: _supplierId.isEmpty ? null : _supplierId,
                      options: [
                        for (final item in _options?.suppliers ?? const [])
                          AppSelectOption(value: item.id, label: item.name),
                      ],
                      onChanged: (value) =>
                          setState(() => _supplierId = value ?? ''),
                    ),
                    if (_cash && _supplierId.isEmpty) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _supplierName,
                        decoration: const InputDecoration(
                          labelText: 'اسم مورد غير مسجل',
                        ),
                      ),
                    ],
                    if (_cash) ...[
                      const SizedBox(height: 12),
                      AppSelect<String>(
                        label: 'بند الصرف *',
                        value: _categoryId.isEmpty ? null : _categoryId,
                        options: [
                          for (final item
                              in _options?.expenseCategories ?? const [])
                            AppSelectOption(value: item.id, label: item.name),
                        ],
                        validator: (value) =>
                            value == null ? 'اختر بند الصرف' : null,
                        onChanged: (value) =>
                            setState(() => _categoryId = value ?? ''),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _invoiceNo,
                        decoration: const InputDecoration(
                          labelText: 'رقم الفاتورة',
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      AppSelect<String>(
                        label: 'المستلم',
                        value: _receiverId.isEmpty ? null : _receiverId,
                        options: [
                          for (final item in _options?.members ?? const [])
                            AppSelectOption(value: item.id, label: item.name),
                        ],
                        onChanged: (value) =>
                            setState(() => _receiverId = value ?? ''),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              label: 'تاريخ التوريد',
                              value: _deliveryDate,
                              onChanged: (value) =>
                                  setState(() => _deliveryDate = value),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _currency,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 3,
                              decoration: const InputDecoration(
                                labelText: 'العملة *',
                                counterText: '',
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (value) =>
                                  RegExp(
                                    r'^[A-Za-z]{3}$',
                                  ).hasMatch(value?.trim() ?? '')
                                  ? null
                                  : '3 حروف',
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _transportCost,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'مصاريف النقل',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        final amount = ExactDecimal.tryParse(value ?? '');
                        return amount == null ||
                                amount.compareTo(ExactDecimal.zero) < 0
                            ? 'قيمة غير صحيحة'
                            : null;
                      },
                    ),
                    if (_cash) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(LucideIcons.images, size: 17),
                        label: Text(
                          _images.isEmpty
                              ? 'إرفاق صور الفاتورة'
                              : '${_images.length} صور مرفقة',
                        ),
                      ),
                      if (_images.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _images.map((item) => item.name).join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.tokens.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notes,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'ملاحظات'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ScmDocumentLinesCard(
                  key: _linesKey,
                  lines: _lines,
                  materials: _options?.materials ?? const [],
                  priced: true,
                  currency: _cash ? 'EGP' : _currency.text.trim().toUpperCase(),
                  onChanged: () => setState(() => _error = null),
                ),
              ],
            ),
          ),
  );
}

class _ReceiptEditSheet extends StatefulWidget {
  const _ReceiptEditSheet({required this.repository, required this.document});

  final ScmRepository repository;
  final ScmDocumentDetail document;

  @override
  State<_ReceiptEditSheet> createState() => _ReceiptEditSheetState();
}

class _ReceiptEditSheetState extends State<_ReceiptEditSheet> {
  final _form = GlobalKey<FormState>();
  final _supplierDeliveryNo = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _date;
  late final List<ScmLineDraft> _lines;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = DateTime.parse(widget.document.date);
    _supplierDeliveryNo.text = widget.document.supplierDeliveryNo ?? '';
    _notes.text = widget.document.notes ?? '';
    _lines = widget.document.lines
        .map(
          (line) => ScmLineDraft(
            id: line.id,
            materialId: line.material.id,
            unitId: line.unitRef.id,
            quantity: line.receivedQuantity ?? '',
            notes: line.notes ?? '',
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _supplierDeliveryNo.dispose();
    _notes.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.updateReceipt(
        id: widget.document.id,
        version: widget.document.version,
        date: _date.toIso8601String().substring(0, 10),
        supplierDeliveryNo: _supplierDeliveryNo.text,
        notes: _notes.text,
        lines: [
          for (final line in _lines)
            {
              'lineId': line.id,
              'receivedQuantity': line.quantity.text.trim().isEmpty
                  ? null
                  : ExactDecimal.parse(line.quantity.text).toString(),
              if (line.notes.text.trim().isNotEmpty)
                'notes': line.notes.text.trim(),
            },
        ],
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: 'تعديل أمر الاستلام',
    closeEnabled: !_saving,
    footer: AppSheetActions(
      primaryLabel: 'حفظ التعديلات',
      busy: _saving,
      onPrimary: _save,
      secondaryLabel: 'إلغاء',
      onSecondary: () => Navigator.pop(context),
    ),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) MessagePanel(message: _error!, onRetry: _save),
          _DateField(
            label: 'تاريخ الاستلام',
            value: _date,
            onChanged: (value) => setState(() => _date = value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _supplierDeliveryNo,
            decoration: const InputDecoration(labelText: 'رقم إذن المورد'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'ملاحظات'),
          ),
          const SizedBox(height: 16),
          Text(
            'الكميات المستلمة',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final (index, source) in widget.document.lines.indexed) ...[
            Text(
              '${source.description} · المطلوب ${source.quantity ?? '—'} ${source.unit}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _lines[index].quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'المستلم (${source.unit})',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final quantity = ExactDecimal.tryParse(value);
                return quantity == null ||
                        quantity.compareTo(ExactDecimal.zero) < 0
                    ? 'كمية غير صحيحة'
                    : null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _lines[index].notes,
              decoration: const InputDecoration(labelText: 'ملاحظات البند'),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    ),
  );
}

class _ScmFlowHint extends StatelessWidget {
  const _ScmFlowHint({required this.kind});
  final ScmDocumentKind kind;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.tokens.wash,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.tokens.line),
    ),
    child: Row(
      children: [
        Icon(LucideIcons.info, size: 18, color: context.tokens.brandStrong),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'أوامر الاستلام تُنشأ تلقائيًا بعد اعتماد أمر الشراء، ثم يسجل أمين المخزن الكميات المستلمة.',
            style: TextStyle(fontSize: 12.5, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final selected = await showAppDatePicker(
        context: context,
        initialDate: value ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (selected != null) onChanged(selected);
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(LucideIcons.calendarDays, size: 17),
      ),
      child: Text(value == null ? 'اختياري' : shortDate(value.toString())),
    ),
  );
}

class ScmStockScreen extends StatefulWidget {
  const ScmStockScreen({super.key, required this.repository});
  final ScmRepository repository;

  @override
  State<ScmStockScreen> createState() => _ScmStockScreenState();
}

class _ScmStockScreenState extends State<ScmStockScreen> {
  List<ScmStockBalance>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.stock();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        PageHeader(
          title: 'أرصدة المخازن',
          subtitle: '${_items?.length ?? 0} رصيد',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.tokens.wash,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.tokens.line),
          ),
          child: const Text(
            'الرصيد يتحدث تلقائيًا من أوامر الاستلام المعتمدة وفواتير الشراء النقدي؛ لذلك لا يُضاف رصيد يدويًا.',
            style: TextStyle(fontSize: 12.5, height: 1.5),
          ),
        ),
        const SizedBox(height: 14),
        if (_error != null)
          MessagePanel(message: _error!, onRetry: _load)
        else if (_items == null)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_items!.isEmpty)
          const AppEmptyState(
            icon: LucideIcons.boxes,
            title: 'لا توجد أرصدة مخزون',
          )
        else
          for (final item in _items!) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.tokens.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.material.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          item.warehouse.name,
                          style: TextStyle(
                            color: context.tokens.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.quantity} ${item.unit.name}',
                    style: TextStyle(
                      color: context.tokens.brandStrong,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    ),
  );
}

class ScmDirectoryScreen extends StatefulWidget {
  const ScmDirectoryScreen({
    super.key,
    required this.repository,
    required this.kind,
  });
  final ScmRepository repository;
  final ScmDirectoryKind kind;

  @override
  State<ScmDirectoryScreen> createState() => _ScmDirectoryScreenState();
}

class _ScmDirectoryScreenState extends State<ScmDirectoryScreen> {
  List<ScmDirectoryEntry>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.directory(widget.kind);
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final warehouses = widget.kind == ScmDirectoryKind.warehouses;
    final title = warehouses ? 'المخازن' : 'الموردون';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          PageHeader(title: title, subtitle: '${_items?.length ?? 0} سجل'),
          const SizedBox(height: 14),
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _load)
          else if (_items == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items!.isEmpty)
            AppEmptyState(
              icon: warehouses ? LucideIcons.warehouse : LucideIcons.truck,
              title: 'لا توجد بيانات $title',
            )
          else
            for (final item in _items!) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.tokens.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.tokens.wash,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        warehouses ? LucideIcons.warehouse : LucideIcons.truck,
                        color: context.tokens.brandStrong,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            [
                              if (item.code.isNotEmpty) item.code,
                              if (item.subtitle != null) item.subtitle!,
                            ].join(' · '),
                            style: TextStyle(
                              color: context.tokens.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!item.active)
                      const AppTag('متوقف', tone: AppTone.danger),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag(this.status);
  final String status;

  @override
  Widget build(BuildContext context) => AppTag(
    _statusLabel(status),
    tone: switch (status) {
      'APPROVED' || 'CONFIRMED' || 'POSTED' || 'RECEIVED' => AppTone.success,
      'REJECTED' || 'CANCELLED' => AppTone.danger,
      'SUBMITTED' || 'PARTIALLY_RECEIVED' => AppTone.warning,
      _ => AppTone.neutral,
    },
  );
}

String _title(ScmDocumentKind kind) => switch (kind) {
  ScmDocumentKind.requests => 'طلبات الشراء',
  ScmDocumentKind.orders => 'أوامر الشراء',
  ScmDocumentKind.receipts => 'أوامر الاستلام',
  ScmDocumentKind.cashPurchases => 'الفواتير النقدية',
};

IconData _icon(ScmDocumentKind kind) => switch (kind) {
  ScmDocumentKind.requests => LucideIcons.clipboardList,
  ScmDocumentKind.orders => LucideIcons.fileCheck2,
  ScmDocumentKind.receipts => LucideIcons.packageCheck,
  ScmDocumentKind.cashPurchases => LucideIcons.receiptText,
};

String _workflowDocType(ScmDocumentKind kind) => switch (kind) {
  ScmDocumentKind.requests => 'PURCHASE_REQUEST',
  ScmDocumentKind.orders => 'PURCHASE_ORDER',
  ScmDocumentKind.receipts => 'RECEIPT',
  ScmDocumentKind.cashPurchases => 'CASH_PURCHASE',
};

ScmLineDraft _draftFromLine(ScmDocumentLine line) => ScmLineDraft(
  id: line.id,
  requestLineId: line.requestLineId,
  materialId: line.material.id,
  unitId: line.unitRef.id,
  quantity: line.quantity ?? '',
  unitPrice: line.unitPrice ?? '',
  notes: line.notes ?? '',
);

String _statusLabel(String value) => switch (value) {
  'DRAFT' => 'مسودة',
  'SUBMITTED' => 'بانتظار الموافقة',
  'APPROVED' => 'معتمد',
  'PARTIALLY_RECEIVED' => 'استلام جزئي',
  'RECEIVED' => 'تم الاستلام',
  'CONFIRMED' => 'مؤكد',
  'POSTED' => 'مرحّل',
  'CLOSED' => 'مغلق',
  'REJECTED' => 'مرفوض',
  'CANCELLED' => 'ملغي',
  _ => value,
};
