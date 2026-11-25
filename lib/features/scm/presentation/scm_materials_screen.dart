import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/app_buttons.dart';
import '../../../core/format/arabic_search.dart';
import '../../../core/format/exact_decimal.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/scm_repository.dart';
import '../domain/scm_models.dart';

class ScmMaterialsScreen extends StatefulWidget {
  const ScmMaterialsScreen({
    super.key,
    required this.repository,
    required this.canManage,
    required this.catalogAccess,
  });

  final ScmRepository repository;
  final bool canManage, catalogAccess;

  @override
  State<ScmMaterialsScreen> createState() => _ScmMaterialsScreenState();
}

class _ScmMaterialsScreenState extends State<ScmMaterialsScreen> {
  final _search = TextEditingController();
  List<ScmCatalogMaterial>? _materials;
  List<ScmRef> _units = const [];
  String? _error;
  bool _loading = true;

  List<ScmCatalogMaterial> get _filtered {
    final query = normalizeArabic(_search.text);
    if (query.isEmpty) return _materials ?? const [];
    return (_materials ?? const [])
        .where(
          (item) =>
              normalizeArabic(item.name).contains(query) ||
              normalizeArabic(item.code).contains(query),
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (widget.canManage) _loadUnits();
    try {
      final materials = await widget.repository.materials(
        catalogAccess: widget.catalogAccess,
      );
      if (!mounted) return;
      setState(() => _materials = materials);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Units only feed the add/edit sheets: a failure here never hides the list.
  Future<void> _loadUnits() async {
    try {
      final units = await widget.repository.units();
      if (mounted) setState(() => _units = units);
    } catch (_) {
      if (mounted) setState(() => _units = const []);
    }
  }

  Future<void> _edit([ScmCatalogMaterial? material]) async {
    if (_units.isEmpty) {
      await _loadUnits();
      if (!mounted) return;
      if (_units.isEmpty) {
        _notify('لا توجد وحدات نشطة. أضف وحدة من الإعدادات أولًا.');
        return;
      }
    }
    final saved = await showAppSheet<ScmCatalogMaterial>(
      context,
      tall: true,
      dismissible: false,
      builder: (_) => _MaterialSheet(
        repository: widget.repository,
        units: _units,
        material: material,
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      final rows = [...?_materials];
      final index = rows.indexWhere((item) => item.id == saved.id);
      if (index == -1) {
        rows.add(saved);
      } else {
        rows[index] = saved;
      }
      rows.sort((a, b) => a.code.compareTo(b.code));
      _materials = rows;
    });
    _notify(material == null ? 'تمت إضافة الخامة' : 'تم تعديل الخامة');
  }

  Future<void> _conversion(
    ScmCatalogMaterial material, [
    ScmMaterialConversion? conversion,
  ]) async {
    if (_units.isEmpty) await _loadUnits();
    if (!mounted) return;
    final saved = await showAppSheet<ScmCatalogMaterial>(
      context,
      builder: (_) => _MaterialConversionSheet(
        repository: widget.repository,
        material: material,
        units: _units,
        conversion: conversion,
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      _materials = [
        for (final row in _materials ?? const [])
          if (row.id == saved.id) saved else row,
      ];
    });
    _notify('تم حفظ تحويل الوحدة');
  }

  Future<void> _deleteConversion(
    ScmCatalogMaterial material,
    ScmMaterialConversion conversion,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف تحويل الوحدة؟'),
        content: Text('سيتم حذف وحدة ${conversion.unit.name} من الخامة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.deleteMaterialConversion(
        material: material,
        conversion: conversion,
      );
      if (!mounted) return;
      await _load();
      _notify('تم حذف تحويل الوحدة');
    } catch (error) {
      if (mounted) _notify(error.toString());
    }
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          PageHeader(
            title: 'الخامات',
            subtitle: 'الخامات ووحدات الشراء والتحويل',
            action: widget.canManage
                ? AppAddButton(
                    key: const ValueKey('add-material-button'),
                    label: 'خامة جديدة',
                    onPressed: () => _edit(),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            textAlign: TextAlign.right,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ابحث باسم الخامة أو الكود…',
              prefixIcon: const Icon(LucideIcons.search, size: 19),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
            ),
          ),
          if (_loading && _materials != null) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 12),
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _load)
          else if (_loading && _materials == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (rows.isEmpty)
            const AppEmptyState(
              icon: LucideIcons.packageOpen,
              title: 'لا توجد خامات مطابقة',
            )
          else
            for (final material in rows) ...[
              _MaterialCard(
                material: material,
                canManage: widget.canManage,
                onEdit: () => _edit(material),
                onAddConversion: () => _conversion(material),
                onEditConversion: (conversion) =>
                    _conversion(material, conversion),
                onDeleteConversion: (conversion) =>
                    _deleteConversion(material, conversion),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.material,
    required this.canManage,
    required this.onEdit,
    required this.onAddConversion,
    required this.onEditConversion,
    required this.onDeleteConversion,
  });

  final ScmCatalogMaterial material;
  final bool canManage;
  final VoidCallback onEdit, onAddConversion;
  final ValueChanged<ScmMaterialConversion> onEditConversion;
  final ValueChanged<ScmMaterialConversion> onDeleteConversion;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.tokens.wash,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.packageOpen,
                color: context.tokens.brandStrong,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    material.code,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: context.tokens.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            AppTag(
              material.active ? 'نشطة' : 'متوقفة',
              tone: material.active ? AppTone.success : AppTone.danger,
            ),
            if (canManage)
              AppEditButton(tooltip: 'تعديل الخامة', onPressed: onEdit),
          ],
        ),
        if (material.description?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            material.description!,
            style: TextStyle(color: context.tokens.muted, fontSize: 12.5),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                'الوحدات والتحويلات',
                style: TextStyle(
                  color: context.tokens.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (canManage)
              AppAddButton(
                label: 'تحويل',
                onPressed: onAddConversion,
                secondary: true,
              ),
          ],
        ),
        for (final conversion in material.conversions)
          InkWell(
            onTap: canManage ? () => onEditConversion(conversion) : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      conversion.unit.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '1 = ${conversion.conversionToBase} ${material.baseUnit.code ?? material.baseUnit.name}',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(color: context.tokens.muted, fontSize: 12),
                  ),
                  if (conversion.purchaseIncrement != null) ...[
                    const SizedBox(width: 8),
                    AppTag('عبوة ${conversion.purchaseIncrement}'),
                  ],
                  if (canManage && conversion.unit.id != material.baseUnit.id)
                    IconButton(
                      tooltip: 'حذف التحويل',
                      onPressed: () => onDeleteConversion(conversion),
                      icon: const Icon(
                        LucideIcons.trash2,
                        size: 17,
                        color: AppTokens.danger,
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

class _MaterialSheet extends StatefulWidget {
  const _MaterialSheet({
    required this.repository,
    required this.units,
    this.material,
  });
  final ScmRepository repository;
  final List<ScmRef> units;
  final ScmCatalogMaterial? material;

  @override
  State<_MaterialSheet> createState() => _MaterialSheetState();
}

class _MaterialSheetState extends State<_MaterialSheet> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.material?.code ?? '');
  late final _name = TextEditingController(text: widget.material?.name ?? '');
  late final _description = TextEditingController(
    text: widget.material?.description ?? '',
  );
  late String _unitId = widget.material?.baseUnit.id ?? '';
  late bool _active = widget.material?.active ?? true;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.material != null;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.saveMaterial(
        material: widget.material,
        code: _code.text,
        name: _name.text,
        unitId: _unitId,
        description: _description.text,
        active: _active,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: _editing ? 'تعديل الخامة' : 'إضافة خامة',
    subtitle: 'بيانات الخامة مشتركة بين شركات القابضة',
    closeEnabled: !_saving,
    footer: AppSheetActions(
      primaryLabel: _editing ? 'حفظ التعديلات' : 'إضافة الخامة',
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
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                style: const TextStyle(color: AppTokens.danger),
              ),
            ),
          TextFormField(
            controller: _code,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(
              labelText: 'كود الخامة *',
              hintText: 'مثال: CEM-001',
            ),
            maxLength: 50,
            validator: _required,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'اسم الخامة *',
              hintText: 'مثال: أسمنت بورتلاندي',
            ),
            maxLength: 200,
            validator: _required,
          ),
          const SizedBox(height: 10),
          AppSelect<String>(
            label: 'الوحدة الأساسية *',
            value: _unitId.isEmpty ? null : _unitId,
            enabled: !_editing,
            options: [
              for (final unit in widget.units)
                AppSelectOption(
                  value: unit.id,
                  label: unit.name,
                  subtitle: unit.code,
                ),
            ],
            validator: (value) => value == null ? 'اختر الوحدة الأساسية' : null,
            onChanged: (value) => setState(() => _unitId = value ?? ''),
          ),
          const SizedBox(height: 6),
          Text(
            _editing
                ? 'لا يمكن تغيير الوحدة الأساسية بعد إنشاء الخامة.'
                : 'سيُنشأ تحويل الوحدة الأساسية تلقائيًا بمعامل 1. ويمكن إضافة وحدات شراء أخرى بعد الحفظ.',
            style: TextStyle(color: context.tokens.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            minLines: 3,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'وصف الخامة'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('الخامة نشطة'),
            subtitle: const Text('تظهر في طلبات وأوامر الشراء'),
            value: _active,
            onChanged: (value) => setState(() => _active = value),
          ),
        ],
      ),
    ),
  );
}

class _MaterialConversionSheet extends StatefulWidget {
  const _MaterialConversionSheet({
    required this.repository,
    required this.material,
    required this.units,
    this.conversion,
  });
  final ScmRepository repository;
  final ScmCatalogMaterial material;
  final List<ScmRef> units;
  final ScmMaterialConversion? conversion;

  @override
  State<_MaterialConversionSheet> createState() =>
      _MaterialConversionSheetState();
}

class _MaterialConversionSheetState extends State<_MaterialConversionSheet> {
  final _form = GlobalKey<FormState>();
  late String _unitId = widget.conversion?.unit.id ?? '';
  late final _factor = TextEditingController(
    text: widget.conversion?.conversionToBase ?? '',
  );
  late final _increment = TextEditingController(
    text: widget.conversion?.purchaseIncrement ?? '',
  );
  late final _notes = TextEditingController(
    text: widget.conversion?.notes ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _factor.dispose();
    _increment.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.saveMaterialConversion(
        material: widget.material,
        conversion: widget.conversion,
        unitId: _unitId,
        conversionToBase: ExactDecimal.parse(_factor.text).toString(),
        purchaseIncrement: _increment.text,
        notes: _notes.text,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: widget.conversion == null
        ? 'إضافة تحويل وحدة'
        : 'تعديل تحويل الوحدة',
    subtitle: widget.material.name,
    footer: AppSheetActions(
      primaryLabel: 'حفظ التحويل',
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
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppTokens.danger)),
          AppSelect<String>(
            label: 'الوحدة *',
            value: _unitId.isEmpty ? null : _unitId,
            enabled: widget.conversion == null,
            options: [
              for (final unit in widget.units)
                if (widget.conversion != null ||
                    !widget.material.conversions.any(
                      (conversion) => conversion.unit.id == unit.id,
                    ))
                  AppSelectOption(
                    value: unit.id,
                    label: unit.name,
                    subtitle: unit.code,
                  ),
            ],
            validator: (value) => value == null ? 'اختر الوحدة' : null,
            onChanged: (value) => setState(() => _unitId = value ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _factor,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'معامل التحويل للوحدة الأساسية *',
              helperText: 'مثال: الطن = 1000 ${widget.material.baseUnit.name}',
            ),
            validator: _positive,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _increment,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'حجم عبوة الشراء',
              hintText: 'اختياري',
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? null : _positive(value),
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
    ),
  );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;

String? _positive(String? value) {
  final number = ExactDecimal.tryParse(value ?? '');
  return number == null || number.compareTo(ExactDecimal.zero) <= 0
      ? 'أدخل رقمًا أكبر من صفر'
      : null;
}
