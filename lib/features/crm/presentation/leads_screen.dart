import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../../meetings/data/meetings_repository.dart';
import '../data/crm_repository.dart';
import '../domain/crm_models.dart';
import 'lead_file_screen.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({
    super.key,
    required this.repository,
    required this.permissions,
    this.meetings,
  });
  final CrmRepository repository;
  final Set<String> permissions;
  final MeetingsRepository? meetings;
  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final _search = TextEditingController();
  CrmPage<CrmLeadSummary>? _result;
  int _page = 0;
  bool _loading = true;
  String? _error;
  String? _selectedId;
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
    try {
      final result = await widget.repository.leads(
        q: _search.text.trim(),
        page: _page,
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(CrmLeadSummary lead) => setState(() => _selectedId = lead.id);

  /// New and edit share one sheet; a new lead opens its file once saved.
  Future<CrmLeadDetail?> _leadSheet([CrmLeadDetail? lead]) =>
      showAppSheet<CrmLeadDetail>(
        context,
        tall: true,
        dismissible: false,
        builder: (_) => _LeadSheet(repository: widget.repository, lead: lead),
      );

  Future<void> _create() async {
    final saved = await _leadSheet();
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تمت إضافة العميل')));
    await _load();
    if (mounted) setState(() => _selectedId = saved.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedId != null) {
      return LeadFileScreen(
        key: ValueKey(_selectedId),
        repository: widget.repository,
        meetings: widget.meetings,
        id: _selectedId!,
        permissions: widget.permissions,
        embedded: true,
        onBack: () => setState(() => _selectedId = null),
        onEdit: (lead) async {
          final saved = await _leadSheet(lead);
          if (saved == null) return false;
          _load();
          return true;
        },
      );
    }
    final rows = _result?.items ?? const <CrmLeadSummary>[];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          PageHeader(
            title: 'العملاء',
            subtitle: '${_result?.total ?? 0} عميل',
            action: widget.permissions.contains('CRM_LEAD_MANAGE')
                ? AppAddButton(label: 'عميل جديد', onPressed: _create)
                : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              _page = 0;
              _load();
            },
            decoration: InputDecoration(
              labelText: 'بحث',
              hintText: 'الاسم أو الموبايل أو المنطقة',
              prefixIcon: const Icon(LucideIcons.search, size: 19),
              suffixIcon: IconButton(
                onPressed: _load,
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _load)
          else
            AppDataTable<CrmLeadSummary>(
              loading: _loading,
              rows: rows,
              onTap: _open,
              columns: const [
                AppTableColumn('الاسم', 170),
                AppTableColumn('الموبايل', 130),
                AppTableColumn('المنطقة', 130),
                AppTableColumn('الحالة', 130),
                AppTableColumn('المسؤول', 140),
              ],
              cells: (row) => [
                AppTableTitle(title: row.name, subtitle: row.altMobile),
                Text(row.mobile, textDirection: TextDirection.ltr),
                Text(row.area ?? '—'),
                Text(crmLeadStatusLabels[row.status] ?? row.status),
                Text(row.owner?.name ?? '—'),
              ],
            ),
          if (_result != null) ...[
            const SizedBox(height: 12),
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

class _LeadSheet extends StatefulWidget {
  const _LeadSheet({required this.repository, this.lead});
  final CrmRepository repository;
  final CrmLeadDetail? lead;
  @override
  State<_LeadSheet> createState() => _LeadSheetState();
}

class _LeadSheetState extends State<_LeadSheet> {
  late final _name = TextEditingController(text: widget.lead?.name);
  late final _mobile = TextEditingController(text: widget.lead?.mobile);
  late final _altMobile = TextEditingController(text: widget.lead?.altMobile);
  late final _area = TextEditingController(text: widget.lead?.area);
  late final _address = TextEditingController(text: widget.lead?.address);
  late final _notes = TextEditingController(text: widget.lead?.notes);
  List<CrmRef> _sources = const [];
  List<CrmRef> _users = const [];
  late String _sourceId = widget.lead?.source?.id ?? '';
  late String _ownerId = widget.lead?.owner?.id ?? '';
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final values = await Future.wait([
        widget.repository.sources(),
        widget.repository.organizationUsers(),
      ]);
      if (!mounted) return;
      setState(() {
        _sources = values[0];
        _users = values[1];
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _mobile,
      _altMobile,
      _area,
      _address,
      _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _mobile.text.trim().isEmpty) {
      setState(() => _error = 'الاسم والموبايل مطلوبان.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.saveLead(
        lead: widget.lead,
        name: _name.text,
        mobile: _mobile.text,
        altMobile: _altMobile.text,
        area: _area.text,
        address: _address.text,
        notes: _notes.text,
        sourceId: _sourceId,
        ownerId: _ownerId,
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: widget.lead == null ? 'عميل جديد' : 'تعديل العميل',
    subtitle: 'البيانات الأساسية',
    closeEnabled: !_busy,
    footer: AppSheetActions(
      primaryLabel: widget.lead == null ? 'إضافة العميل' : 'حفظ التعديلات',
      busy: _busy,
      onPrimary: _save,
      secondaryLabel: 'إلغاء',
      onSecondary: () => Navigator.pop(context),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: AppTokens.danger),
            ),
          ),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'الاسم *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _mobile,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'الموبايل *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _altMobile,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'موبايل آخر'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _area,
          decoration: const InputDecoration(labelText: 'المنطقة'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _address,
          decoration: const InputDecoration(labelText: 'العنوان'),
        ),
        const SizedBox(height: 12),
        AppSelect<String>(
          label: 'المصدر',
          value: _sourceId,
          options: [
            const AppSelectOption(value: '', label: 'بدون مصدر'),
            for (final source in _sources)
              AppSelectOption(
                value: source.id,
                label: source.code == null
                    ? source.name
                    : '${source.code} · ${source.name}',
              ),
          ],
          onChanged: (value) => setState(() => _sourceId = value ?? ''),
        ),
        const SizedBox(height: 12),
        AppSelect<String>(
          label: 'المسؤول',
          value: _ownerId,
          options: [
            const AppSelectOption(value: '', label: 'بدون مسؤول'),
            for (final user in _users)
              AppSelectOption(value: user.id, label: user.name),
          ],
          onChanged: (value) => setState(() => _ownerId = value ?? ''),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'ملاحظات'),
        ),
      ],
    ),
  );
}
