import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/app_buttons.dart';
import '../../../core/format/exact_decimal.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_select.dart';
import '../domain/scm_models.dart';

class ScmLineDraft {
  ScmLineDraft({
    this.id,
    this.requestLineId,
    this.materialId = '',
    this.unitId = '',
    String quantity = '',
    String unitPrice = '',
    String notes = '',
  }) : quantity = TextEditingController(text: quantity),
       unitPrice = TextEditingController(text: unitPrice),
       notes = TextEditingController(text: notes);

  factory ScmLineDraft.copyOf(ScmLineDraft value) => ScmLineDraft(
    id: value.id,
    requestLineId: value.requestLineId,
    materialId: value.materialId,
    unitId: value.unitId,
    quantity: value.quantity.text,
    unitPrice: value.unitPrice.text,
    notes: value.notes.text,
  );

  final String? id;
  final String? requestLineId;
  String materialId;
  String unitId;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController notes;

  ExactDecimal get lineTotal {
    final quantityValue = ExactDecimal.tryParse(quantity.text);
    final priceValue = ExactDecimal.tryParse(unitPrice.text);
    if (quantityValue == null || priceValue == null) return ExactDecimal.zero;
    return quantityValue * priceValue;
  }

  void dispose() {
    quantity.dispose();
    unitPrice.dispose();
    notes.dispose();
  }
}

class ScmDocumentMasterCard extends StatelessWidget {
  const ScmDocumentMasterCard({
    super.key,
    required this.title,
    required this.children,
    this.total,
    this.currency = 'EGP',
  });

  final String title;
  final List<Widget> children;
  final String? total;
  final String currency;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.tokens.line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A102A23),
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (total != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'الإجمالي',
                    style: TextStyle(color: context.tokens.muted, fontSize: 11),
                  ),
                  Text(
                    '$total $currency',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );
}

class ScmDocumentLinesCard extends StatefulWidget {
  const ScmDocumentLinesCard({
    super.key,
    required this.lines,
    required this.materials,
    required this.priced,
    required this.onChanged,
    this.currency = 'EGP',
  });

  final List<ScmLineDraft> lines;
  final List<ScmMaterial> materials;
  final bool priced;
  final VoidCallback onChanged;
  final String currency;

  @override
  State<ScmDocumentLinesCard> createState() => ScmDocumentLinesCardState();
}

class ScmDocumentLinesCardState extends State<ScmDocumentLinesCard> {
  final _lineForm = GlobalKey<FormState>();
  ScmLineDraft? _draft;
  int? _editingIndex;

  bool get hasOpenDraft => _draft != null;

  void startAdd() {
    if (_draft != null) return;
    setState(() {
      _editingIndex = null;
      _draft = ScmLineDraft();
    });
  }

  void _startEdit(int index) {
    if (_draft != null) return;
    setState(() {
      _editingIndex = index;
      _draft = ScmLineDraft.copyOf(widget.lines[index]);
    });
  }

  void _cancelDraft() {
    final draft = _draft;
    setState(() {
      _draft = null;
      _editingIndex = null;
    });
    draft?.dispose();
  }

  void _saveDraft() {
    if (!(_lineForm.currentState?.validate() ?? false)) return;
    final draft = _draft!;
    final index = _editingIndex;
    if (index == null) {
      widget.lines.add(draft);
    } else {
      widget.lines[index].dispose();
      widget.lines[index] = draft;
    }
    setState(() {
      _draft = null;
      _editingIndex = null;
    });
    widget.onChanged();
  }

  void _remove(int index) {
    widget.lines.removeAt(index).dispose();
    setState(() {});
    widget.onChanged();
  }

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.tokens.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'البنود',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            _ViewPill(
              icon: LucideIcons.list,
              label: 'القائمة',
              selected: _draft == null,
            ),
            const SizedBox(width: 5),
            _ViewPill(
              icon: LucideIcons.squarePen,
              label: 'النموذج',
              selected: _draft != null,
              onTap: _draft == null ? startAdd : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_draft != null)
          _LineForm(
            key: ValueKey(_editingIndex ?? 'new'),
            formKey: _lineForm,
            line: _draft!,
            materials: widget.materials,
            priced: widget.priced,
            onChanged: () => setState(() {}),
            onSave: _saveDraft,
            onCancel: _cancelDraft,
          )
        else ...[
          for (final (index, line) in widget.lines.indexed) ...[
            _LineSummary(
              line: line,
              material: widget.materials
                  .where((item) => item.id == line.materialId)
                  .firstOrNull,
              priced: widget.priced,
              currency: widget.currency,
              onEdit: () => _startEdit(index),
              onRemove: () => _remove(index),
            ),
            if (index != widget.lines.length - 1)
              Divider(height: 18, color: context.tokens.line),
          ],
          if (widget.lines.isEmpty) const SizedBox(height: 2),
          const SizedBox(height: 10),
          AppAddButton(
            label: 'إضافة بند',
            onPressed: startAdd,
            secondary: true,
          ),
        ],
      ],
    ),
  );
}

class _ViewPill extends StatelessWidget {
  const _ViewPill({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? context.tokens.wash : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? context.tokens.brandStrong : context.tokens.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11.5)),
        ],
      ),
    ),
  );
}

class _LineSummary extends StatelessWidget {
  const _LineSummary({
    required this.line,
    required this.material,
    required this.priced,
    required this.currency,
    required this.onEdit,
    required this.onRemove,
  });

  final ScmLineDraft line;
  final ScmMaterial? material;
  final bool priced;
  final String currency;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  String get _unitName =>
      material?.units
          .where((item) => item.id == line.unitId)
          .firstOrNull
          ?.name ??
      '—';

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: context.tokens.wash,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(LucideIcons.package, size: 17),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              material?.name ?? '—',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              '${line.quantity.text} $_unitName'
              '${priced ? ' · ${line.unitPrice.text} للوحدة' : ''}',
              style: TextStyle(color: context.tokens.muted, fontSize: 12),
            ),
            if (priced)
              Text(
                '${line.lineTotal.money()} $currency',
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
          ],
        ),
      ),
      AppEditButton(tooltip: 'تعديل', onPressed: onEdit),
      IconButton(
        tooltip: 'حذف',
        onPressed: onRemove,
        icon: const Icon(LucideIcons.trash2, size: 17, color: AppTokens.danger),
      ),
    ],
  );
}

class _LineForm extends StatelessWidget {
  const _LineForm({
    super.key,
    required this.formKey,
    required this.line,
    required this.materials,
    required this.priced,
    required this.onChanged,
    required this.onSave,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final ScmLineDraft line;
  final List<ScmMaterial> materials;
  final bool priced;
  final VoidCallback onChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final material = materials
        .where((item) => item.id == line.materialId)
        .firstOrNull;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSelect<String>(
            label: 'الخامة *',
            value: line.materialId.isEmpty ? null : line.materialId,
            options: [
              for (final item in materials)
                AppSelectOption(
                  value: item.id,
                  label: item.name,
                  subtitle: item.code,
                ),
            ],
            validator: (value) => value == null ? 'اختر الخامة' : null,
            onChanged: (value) {
              line.materialId = value ?? '';
              final selected = materials
                  .where((item) => item.id == line.materialId)
                  .firstOrNull;
              line.unitId = selected?.units.firstOrNull?.id ?? '';
              onChanged();
            },
          ),
          const SizedBox(height: 10),
          AppSelect<String>(
            label: 'الوحدة *',
            value: line.unitId.isEmpty ? null : line.unitId,
            options: [
              for (final unit in material?.units ?? const <ScmMaterialUnit>[])
                AppSelectOption(
                  value: unit.id,
                  label: unit.name,
                  subtitle: unit.code,
                ),
            ],
            validator: (value) => value == null ? 'اختر الوحدة' : null,
            onChanged: (value) {
              line.unitId = value ?? '';
              onChanged();
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DecimalField(
                  controller: line.quantity,
                  label: 'الكمية *',
                  onChanged: onChanged,
                ),
              ),
              if (priced) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _DecimalField(
                    controller: line.unitPrice,
                    label: 'سعر الوحدة *',
                    allowZero: true,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ],
          ),
          if (priced) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                'إجمالي البند  ${line.lineTotal.money()} EGP',
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            controller: line.notes,
            decoration: const InputDecoration(labelText: 'ملاحظات البند'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(LucideIcons.check, size: 17),
                  label: const Text('حفظ البند'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('إلغاء'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecimalField extends StatelessWidget {
  const _DecimalField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.allowZero = false,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;
  final bool allowZero;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
    decoration: InputDecoration(labelText: label),
    onChanged: (_) => onChanged(),
    validator: (value) {
      final number = ExactDecimal.tryParse(value ?? '');
      if (number == null ||
          number.compareTo(ExactDecimal.zero) < (allowZero ? 0 : 1)) {
        return 'قيمة غير صحيحة';
      }
      return null;
    },
  );
}
