import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/format/exact_decimal.dart';
import '../../../core/media/invoice_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../data/custody_repository.dart';
import '../domain/custody_models.dart';
import 'custody_widgets.dart';

Future<bool> showExpenseForm({
  required BuildContext context,
  required CustodyRepository repository,
  required String currentUserId,
  required Set<String> permissions,
  bool onBehalf = false,
}) async =>
    await showAppSheet<bool>(
      context,
      tall: true,
      dismissible: false,
      builder: (context) => _ExpenseFormSheet(
        repository: repository,
        currentUserId: currentUserId,
        permissions: permissions,
        onBehalf: onBehalf,
      ),
    ) ??
    false;

class _ExpenseFormSheet extends StatefulWidget {
  const _ExpenseFormSheet({
    required this.repository,
    required this.currentUserId,
    required this.permissions,
    required this.onBehalf,
  });

  final CustodyRepository repository;
  final String currentUserId;
  final Set<String> permissions;
  final bool onBehalf;

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _note = TextEditingController();

  ExpenseOptions? _rosterOptions;
  ExpenseOptions? _options;
  CustodyBalance? _balance;
  String? _ownerId;
  String? _centerType;
  String? _centerId;
  String? _categoryId;
  String? _subCategoryId;
  String? _contractorId;
  String _evidenceType = 'INVOICE';
  String _entryDate = '';
  List<XFile> _invoices = const [];
  bool _loading = true;
  bool _loadingOwner = false;
  bool _busy = false;
  String? _error;

  bool get _invoiceOptional =>
      widget.permissions.contains('CUSTODY_EXPENSE_WITHOUT_INVOICE');

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final results = await Future.wait([
        widget.repository.expenseOptions(
          ownerId: widget.onBehalf ? null : widget.currentUserId,
        ),
        if (!widget.onBehalf) widget.repository.balance(widget.currentUserId),
      ]);
      if (!mounted) return;
      final options = results.first as ExpenseOptions;
      setState(() {
        _rosterOptions = options;
        if (!widget.onBehalf) {
          _options = options;
          _balance = results.last as CustodyBalance;
        }
        _entryDate = options.today;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectOwner(String? ownerId) async {
    setState(() {
      _ownerId = ownerId;
      _options = null;
      _balance = null;
      _centerType = null;
      _centerId = null;
      _categoryId = null;
      _subCategoryId = null;
      _contractorId = null;
      _loadingOwner = ownerId != null;
      _error = null;
    });
    if (ownerId == null) return;
    try {
      final results = await Future.wait([
        widget.repository.expenseOptions(ownerId: ownerId),
        widget.repository.balance(ownerId),
      ]);
      if (!mounted || _ownerId != ownerId) return;
      final options = results.first as ExpenseOptions;
      setState(() {
        _options = options;
        _balance = results.last as CustodyBalance;
        _entryDate = options.today;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loadingOwner = false);
    }
  }

  Future<void> _pickDate() async {
    final parsed = DateTime.tryParse(_entryDate) ?? DateTime.now();
    final chosen = await showAppDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(2020),
      lastDate: DateTime.tryParse(_options?.today ?? '') ?? DateTime.now(),
    );
    if (chosen == null || !mounted) return;
    setState(() => _entryDate = _dateValue(chosen));
  }

  Future<void> _addFromCamera() async {
    final images = await pickInvoiceImages(context, camera: true);
    if (mounted) await _addInvoices(images);
  }

  Future<void> _addFromGallery() async {
    final images = await pickInvoiceImages(context);
    if (mounted) await _addInvoices(images);
  }

  Future<void> _addInvoices(List<XFile> additions) async {
    if (additions.isEmpty) return;
    final selected = [..._invoices, ...additions];
    if (selected.length > 10) {
      setState(() => _error = 'الحد الأقصى 10 صور');
      return;
    }
    var total = 0;
    for (final image in selected) {
      final length = await image.length();
      if (length > 10 * 1024 * 1024) {
        if (mounted) setState(() => _error = 'الحد الأقصى للصورة 10 ميجابايت');
        return;
      }
      total += length;
    }
    if (total > 50 * 1024 * 1024) {
      if (mounted) setState(() => _error = 'الحد الإجمالي للصور 50 ميجابايت');
      return;
    }
    if (mounted) {
      setState(() {
        _invoices = selected;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    final options = _options;
    if (!_formKey.currentState!.validate() || options == null) return;
    if (_evidenceType == 'INVOICE' && _invoices.isEmpty && !_invoiceOptional) {
      setState(() => _error = 'ارفع صورة فاتورة واحدة على الأقل');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.createExpense(
        centerId: _centerId!,
        categoryId: _categoryId!,
        amount: _amount.text,
        entryDate: _entryDate,
        description: _description.text,
        note: _note.text,
        centerType: options.costDetailsEnabled ? _centerType : null,
        evidenceType: _evidenceType,
        contractorId: _contractorId,
        subCategoryId: options.costDetailsEnabled ? _subCategoryId : null,
        ownerId: widget.onBehalf ? _ownerId : null,
        invoicePaths: _invoices.map((image) => image.path).toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The balance line under the amount: what is left after this item, or a
  /// warning when the amount is more than the custody holds.
  (String, String?, bool) _balanceHint() {
    final balance = _balance;
    if (balance == null) {
      return (
        widget.onBehalf ? 'اختر الموظف لعرض رصيد عهدته' : 'رصيدك الحالي',
        null,
        false,
      );
    }
    final remaining = ExactDecimal.tryParse(balance.remaining);
    final amount = ExactDecimal.tryParse(_amount.text);
    final who = widget.onBehalf ? 'رصيد عهدة الموظف' : 'رصيدك الحالي';
    if (remaining == null ||
        amount == null ||
        amount.compareTo(ExactDecimal.zero) <= 0) {
      return (who, money(balance.remaining), false);
    }
    final after = remaining + -amount;
    if (after.compareTo(ExactDecimal.zero) < 0) {
      return ('أكبر من $who', money(balance.remaining), true);
    }
    return ('المتبقي بعد البند', after.money(), false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final options = _options;
    final owners = (_rosterOptions?.people ?? const <CustodyPerson>[])
        .where(
          (person) =>
              person.active &&
              person.custodyId != null &&
              person.id != widget.currentUserId,
        )
        .toList();
    final (hint, hintValue, warning) = _balanceHint();
    final ready = options != null && options.custodyId != null;
    return AppSheetScaffold(
      title: widget.onBehalf ? 'صرف بند باسم موظف' : 'إضافة بند عهدة',
      subtitle: widget.onBehalf
          ? 'يُسجّل البند على عهدة الموظف المختار'
          : 'يُخصم من رصيد عهدتك بعد الحفظ',
      closeEnabled: !_busy,
      onClose: () => Navigator.pop(context, false),
      footer: AppSheetActions(
        primaryLabel: widget.onBehalf ? 'صرف البند' : 'إضافة البند',
        primaryIcon: LucideIcons.check,
        busy: _busy,
        onPrimary: ready ? _submit : null,
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    MessagePanel(message: _error!),
                    const SizedBox(height: 12),
                  ],
                  if (widget.onBehalf) ...[
                    _SelectField(
                      label: 'الموظف صاحب العهدة *',
                      value: _ownerId,
                      placeholder: owners.isEmpty
                          ? 'لا يوجد موظفون لديهم عهدة'
                          : 'اختر الموظف',
                      items: [
                        for (final person in owners)
                          (person.id, person.name, person.code),
                      ],
                      onChanged: _busy ? null : _selectOwner,
                    ),
                    const SizedBox(height: 12),
                  ],
                  AppAmountField(
                    controller: _amount,
                    enabled: !_busy,
                    hint: hint,
                    hintValue: hintValue,
                    warning: warning,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      final amount = double.tryParse(value ?? '');
                      return amount == null || amount <= 0
                          ? 'أدخل مبلغًا صحيحًا أكبر من صفر'
                          : null;
                    },
                  ),
                  if (_loadingOwner)
                    const Padding(
                      padding: EdgeInsets.all(AppSpace.lg),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (widget.onBehalf && !_loadingOwner && _ownerId == null)
                    const _HintCard(
                      text: 'اختر الموظف لتحميل مراكز التكلفة الخاصة به.',
                    ),
                  if (options != null) ...[
                    if (options.custodyId == null)
                      const _HintCard(
                        text: 'لا توجد عهدة للموظف داخل الشركة الحالية.',
                      ),
                    const _GroupTitle('البيان'),
                    TextFormField(
                      controller: _description,
                      enabled: !_busy,
                      textAlign: TextAlign.right,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        labelText: 'البيان *',
                        hintText: 'مثال: شراء أسمنت للموقع',
                        counterText: '',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'البيان مطلوب'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _busy ? null : _pickDate,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'تاريخ المصروف *',
                          suffixIcon: Icon(LucideIcons.calendarDays, size: 18),
                        ),
                        child: Text(
                          _entryDate.isEmpty
                              ? 'اختر التاريخ'
                              : shortDate(_entryDate),
                        ),
                      ),
                    ),
                    const _GroupTitle('التحميل على'),
                    if (options.costDetailsEnabled) ...[
                      AppSegmented<String?>(
                        value: _centerType,
                        options: const [
                          ('PROJECT', 'مشروع', LucideIcons.hardHat),
                          ('OFFICE', 'مكتب', LucideIcons.building2),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                _centerType = value;
                                _centerId = null;
                              }),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _SelectField(
                      label: 'مركز التكلفة *',
                      value: _centerId,
                      items: [
                        for (final center in options.centers)
                          if (!options.costDetailsEnabled ||
                              center.type == _centerType)
                            (center.id, center.name, center.code),
                      ],
                      onChanged:
                          _busy ||
                              (options.costDetailsEnabled &&
                                  _centerType == null)
                          ? null
                          : (value) => setState(() => _centerId = value),
                    ),
                    const SizedBox(height: 12),
                    _SelectField(
                      label: 'بند الصرف *',
                      value: _categoryId,
                      items: [
                        for (final category in options.categories)
                          (category.id, category.name, category.code),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _categoryId = value;
                              _subCategoryId = null;
                            }),
                    ),
                    if (options.costDetailsEnabled &&
                        options.subCategories.any(
                          (item) => item.parentId == _categoryId,
                        )) ...[
                      const SizedBox(height: 12),
                      _SelectField(
                        label: 'البند الفرعي',
                        value: _subCategoryId,
                        required: false,
                        items: [
                          for (final item in options.subCategories)
                            if (item.parentId == _categoryId)
                              (item.id, item.name, item.code),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _subCategoryId = value),
                      ),
                    ],
                    const _GroupTitle('المستند'),
                    AppSegmented<String>(
                      value: _evidenceType,
                      options: const [
                        ('INVOICE', 'فاتورة', LucideIcons.receipt),
                        ('CONTRACTOR', 'مقاول', LucideIcons.users),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _evidenceType = value;
                              _contractorId = null;
                              _invoices = const [];
                            }),
                    ),
                    const SizedBox(height: 12),
                    if (_evidenceType == 'CONTRACTOR')
                      _SelectField(
                        label: 'المقاول *',
                        value: _contractorId,
                        items: [
                          for (final contractor in options.contractors)
                            (contractor.id, contractor.name, contractor.code),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _contractorId = value),
                      )
                    else
                      _InvoicePicker(
                        invoices: _invoices,
                        optional: _invoiceOptional,
                        busy: _busy,
                        onCamera: _addFromCamera,
                        onGallery: _addFromGallery,
                        onRemove: (index) => setState(
                          () => _invoices = [
                            ..._invoices.take(index),
                            ..._invoices.skip(index + 1),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _note,
                      enabled: !_busy,
                      textAlign: TextAlign.right,
                      maxLength: 1000,
                      maxLines: 3,
                      minLines: 2,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات',
                        hintText: 'اختياري',
                        alignLabelWithHint: true,
                        counterText: '',
                        fillColor: tokens.sunken,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: context.tokens.muted,
      ),
    ),
  );
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.placeholder = 'اختر…',
    this.required = true,
  });

  final String label;
  final String? value;

  /// id, name and an optional code shown under the name.
  final List<(String, String, String)> items;
  final ValueChanged<String?>? onChanged;
  final String placeholder;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return AppSelect<String>(
      label: label,
      value: value,
      placeholder: placeholder,
      enabled: onChanged != null,
      options: [
        for (final (id, name, code) in items)
          AppSelectOption(
            value: id,
            label: name,
            subtitle: code.isEmpty ? null : code,
          ),
      ],
      onChanged: (value) => onChanged?.call(value),
      validator: required
          ? (value) => value == null || value.isEmpty ? 'هذا الحقل مطلوب' : null
          : null,
    );
  }
}

class _InvoicePicker extends StatelessWidget {
  const _InvoicePicker({
    required this.invoices,
    required this.optional,
    required this.busy,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final List<XFile> invoices;
  final bool optional;
  final bool busy;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final full = invoices.length >= 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          optional ? 'صور الفواتير (اختياري)' : 'صور الفواتير *',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: tokens.ink,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (index, invoice) in invoices.indexed) ...[
                _SelectedInvoice(
                  invoice: invoice,
                  busy: busy,
                  onRemove: () => onRemove(index),
                ),
                const SizedBox(width: 8),
              ],
              if (!full) ...[
                _AddTile(
                  icon: LucideIcons.camera,
                  label: 'تصوير',
                  filled: true,
                  onTap: busy ? null : onCamera,
                ),
                const SizedBox(width: 8),
                _AddTile(
                  icon: LucideIcons.images,
                  label: 'المعرض',
                  onTap: busy ? null : onGallery,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'حتى 10 صور · 10 ميجابايت للصورة',
          style: TextStyle(
            fontSize: 11,
            color: tokens.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: filled ? tokens.wash : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tokens.brand.withValues(alpha: .35)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: tokens.brand, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: tokens.brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedInvoice extends StatelessWidget {
  const _SelectedInvoice({
    required this.invoice,
    required this.busy,
    required this.onRemove,
  });

  final XFile invoice;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 84,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(invoice.path),
            fit: BoxFit.cover,
            cacheWidth: 300,
            errorBuilder: (_, error, stack) => Container(
              color: context.tokens.sunken,
              child: const Icon(LucideIcons.fileImage),
            ),
          ),
          PositionedDirectional(
            top: 4,
            end: 4,
            child: IconButton.filled(
              onPressed: busy ? null : onRemove,
              tooltip: 'حذف الصورة',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              constraints: const BoxConstraints.tightFor(width: 24, height: 24),
              padding: EdgeInsets.zero,
              icon: const Icon(LucideIcons.x, size: 13),
            ),
          ),
        ],
      ),
    ),
  );
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(AppSpace.md),
    decoration: BoxDecoration(
      color: context.tokens.wash,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(text, style: const TextStyle(fontSize: 13)),
  );
}

String _dateValue(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
