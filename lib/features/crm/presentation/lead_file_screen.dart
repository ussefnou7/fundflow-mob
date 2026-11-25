import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../../meetings/data/meetings_repository.dart';
import '../../meetings/presentation/meetings_section.dart';
import '../data/crm_repository.dart';
import '../domain/crm_models.dart';
import 'inspection_detail_screen.dart';

class LeadFileScreen extends StatefulWidget {
  const LeadFileScreen({
    super.key,
    required this.repository,
    required this.id,
    required this.permissions,
    this.initialSection = 0,
    this.meetings,
    this.embedded = false,
    this.onBack,
    this.onEdit,
  });
  final CrmRepository repository;
  final String id;
  final Set<String> permissions;
  final int initialSection;
  final MeetingsRepository? meetings;
  final bool embedded;
  final VoidCallback? onBack;

  /// Opens the lead's edit sheet; true when it saved.
  final Future<bool> Function(CrmLeadDetail lead)? onEdit;
  @override
  State<LeadFileScreen> createState() => _LeadFileScreenState();
}

class _LeadFileScreenState extends State<LeadFileScreen> {
  CrmLeadDetail? _lead;
  CrmPage<CrmInspection>? _inspections;
  List<CrmFollowUp>? _followUps;
  late int _section;
  int _meetingRevision = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        widget.repository.lead(widget.id),
        widget.repository.inspections(leadId: widget.id, size: 100),
        widget.repository.followUps(widget.id),
      ]);
      if (mounted) {
        setState(() {
          _lead = values[0] as CrmLeadDetail;
          _inspections = values[1] as CrmPage<CrmInspection>;
          _followUps = values[2] as List<CrmFollowUp>;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _edit(CrmLeadDetail lead) async {
    if (await widget.onEdit?.call(lead) == true) await _load();
  }

  /// Every "new" in a sub-tab is a sheet; the tab reloads once it saves.
  Future<void> _add(Widget Function(BuildContext) sheet, String done) async {
    final saved = await showAppSheet<bool>(
      context,
      tall: true,
      dismissible: false,
      builder: sheet,
    );
    if (saved != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    if (_section == 2) {
      setState(() => _meetingRevision++);
    } else {
      await _load();
    }
  }

  Future<void> _openInspection(CrmInspection item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionDetailScreen(
          repository: widget.repository,
          id: item.id,
          permissions: widget.permissions,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Widget? _sectionAction(CrmLeadDetail lead) {
    final canLead = widget.permissions.contains('CRM_LEAD_MANAGE');
    return switch (_section) {
      0 when widget.permissions.contains('CRM_INSPECTION_MANAGE') =>
        AppAddButton(
          label: 'حجز معاينة',
          onPressed: () => _add(
            (_) => _InspectionSheet(repository: widget.repository, lead: lead),
            'تم حجز المعاينة',
          ),
        ),
      1 when canLead => AppAddButton(
        label: 'حجز متابعة',
        onPressed: () => _add(
          (_) => _FollowUpSheet(repository: widget.repository, leadId: lead.id),
          'تم تسجيل المتابعة',
        ),
      ),
      2 when canLead && widget.meetings != null => AppAddButton(
        label: 'حجز اجتماع',
        onPressed: () => _add(
          (_) => _MeetingSheet(repository: widget.meetings!, lead: lead),
          'تم حجز الاجتماع',
        ),
      ),
      _ => null,
    };
  }

  Widget _sectionBody() {
    switch (_section) {
      case 0:
        return AppDataTable<CrmInspection>(
          rows: _inspections?.items ?? const [],
          onTap: _openInspection,
          empty: const AppEmptyState(
            icon: LucideIcons.mapPinned,
            title: 'لا توجد معاينات',
          ),
          columns: const [
            AppTableColumn('الموعد', 130),
            AppTableColumn('العنوان', 170),
            AppTableColumn('المهندس', 130),
            AppTableColumn('الحالة', 110),
            AppTableColumn('المحصل', 100, numeric: true),
          ],
          cells: (item) => [
            Text(
              crmEnglishDateTime(item.scheduledAt),
              textDirection: TextDirection.ltr,
            ),
            Text(item.address ?? '—', maxLines: 2),
            Text(item.engineer.name),
            AppTag(
              crmInspectionStatusLabels[item.status] ?? item.status,
              tone: _inspectionTone(item.status),
            ),
            Text(item.collectedAmount ?? '—'),
          ],
        );
      case 1:
        return AppDataTable<CrmFollowUp>(
          rows: _followUps ?? const [],
          empty: const AppEmptyState(
            icon: LucideIcons.phoneCall,
            title: 'لا توجد متابعات',
          ),
          columns: const [
            AppTableColumn('التاريخ', 130),
            AppTableColumn('القناة', 110),
            AppTableColumn('النتيجة', 110),
            AppTableColumn('ملاحظة', 190),
            AppTableColumn('المتابعة القادمة', 140),
            AppTableColumn('بواسطة', 120),
          ],
          cells: (item) => [
            Text(
              crmEnglishDateTime(item.occurredAt),
              textDirection: TextDirection.ltr,
            ),
            Text(crmFollowUpChannelLabels[item.channel] ?? item.channel),
            Text(
              item.outcome == null
                  ? '—'
                  : crmFollowUpOutcomeLabels[item.outcome] ?? item.outcome!,
            ),
            Text(item.note ?? '—', maxLines: 2),
            Text(
              item.nextFollowUpAt == null
                  ? '—'
                  : crmEnglishDateTime(item.nextFollowUpAt!),
              textDirection: TextDirection.ltr,
            ),
            Text(item.actor.name),
          ],
        );
      default:
        if (widget.meetings == null) {
          return const AppEmptyState(
            icon: LucideIcons.calendarX2,
            title: 'تعذر تحميل الاجتماعات',
          );
        }
        return MeetingsSection(
          key: ValueKey(_meetingRevision),
          repository: widget.meetings!,
          ownerType: 'CRM_LEAD',
          ownerId: widget.id,
          canManage: widget.permissions.contains('CRM_LEAD_MANAGE'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lead = _lead;
    final action = lead == null ? null : _sectionAction(lead);
    final content = lead == null
        ? Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : MessagePanel(message: _error!, onRetry: _load),
          )
        : RefreshIndicator(
            onRefresh: () async {
              await _load();
              if (mounted && _section == 2) {
                setState(() => _meetingRevision++);
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                if (widget.onBack != null) ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: widget.onBack,
                      icon: const Icon(LucideIcons.arrowRight, size: 17),
                      label: const Text('العملاء'),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                PageHeader(
                  title: lead.name,
                  subtitle: crmLeadStatusLabels[lead.status] ?? lead.status,
                  action:
                      widget.permissions.contains('CRM_LEAD_MANAGE') &&
                          widget.onEdit != null
                      ? AppEditButton(
                          tooltip: 'تعديل العميل',
                          onPressed: () => _edit(lead),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Card(
                  color: Colors.white,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final half = (constraints.maxWidth - 8) / 2;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Field('الاسم', lead.name, width: half),
                            _Field(
                              'الموبايل',
                              lead.mobile,
                              width: half,
                              ltr: true,
                            ),
                            _Field(
                              'موبايل آخر',
                              lead.altMobile ?? '—',
                              width: half,
                              ltr: true,
                            ),
                            _Field('المنطقة', lead.area ?? '—', width: half),
                            _Field(
                              'العنوان',
                              lead.address ?? '—',
                              width: constraints.maxWidth,
                            ),
                            _Field(
                              'المصدر',
                              lead.source?.name ?? '—',
                              width: half,
                            ),
                            _Field(
                              'المسؤول',
                              lead.owner?.name ?? '—',
                              width: half,
                            ),
                            _Field(
                              'ملاحظات',
                              lead.notes ?? '—',
                              width: constraints.maxWidth,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Metric(
                      'المعاينات',
                      lead.behaviour.inspections,
                      LucideIcons.mapPinned,
                      const Color(0xff287f8d),
                    ),
                    _Metric(
                      'إلغاء من العميل',
                      lead.behaviour.clientCancellations,
                      LucideIcons.calendarX2,
                      const Color(0xffb5473c),
                    ),
                    _Metric(
                      'تأجيل من العميل',
                      lead.behaviour.clientReschedules,
                      LucideIcons.calendarClock,
                      const Color(0xffb76a0b),
                    ),
                    _Metric(
                      'إلغاء من الشركة',
                      lead.behaviour.companyCancellations,
                      LucideIcons.building2,
                      const Color(0xffb5473c),
                    ),
                    _Metric(
                      'لم يحضر',
                      lead.behaviour.noShows,
                      LucideIcons.userRoundX,
                      const Color(0xffb76a0b),
                    ),
                    _Metric(
                      'لم يرد',
                      lead.behaviour.noAnswers,
                      LucideIcons.phoneOff,
                      const Color(0xff50645d),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                LedgerTabs<int>(
                  value: _section,
                  tabs: [
                    (0, 'المعاينات', lead.behaviour.inspections),
                    (1, 'المتابعة', _followUps?.length ?? 0),
                    (2, 'الاجتماعات', 0),
                  ],
                  onChanged: (value) => setState(() => _section = value),
                ),
                const SizedBox(height: 10),
                if (action != null) ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: action,
                  ),
                  const SizedBox(height: 10),
                ],
                _sectionBody(),
              ],
            ),
          );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('ملف العميل')),
      body: content,
    );
  }
}

AppTone _inspectionTone(String status) => switch (status) {
  'DONE' => AppTone.success,
  'CANCELLED' || 'NO_SHOW' => AppTone.danger,
  'RESCHEDULED' => AppTone.warning,
  _ => AppTone.neutral,
};

/// A CRM form in the app's sheet frame; pops true once saved.
class _CrmFormSheet extends StatelessWidget {
  const _CrmFormSheet({
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.busy,
    required this.onSave,
    required this.children,
    this.error,
  });
  final String title, subtitle, primaryLabel;
  final bool busy;
  final VoidCallback onSave;
  final String? error;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppSheetScaffold(
    title: title,
    subtitle: subtitle,
    closeEnabled: !busy,
    footer: AppSheetActions(
      primaryLabel: primaryLabel,
      busy: busy,
      onPrimary: onSave,
      secondaryLabel: 'إلغاء',
      onSecondary: () => Navigator.pop(context),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              error!,
              style: const TextStyle(color: AppTokens.danger),
            ),
          ),
        ...children,
      ],
    ),
  );
}

class _FollowUpSheet extends StatefulWidget {
  const _FollowUpSheet({required this.repository, required this.leadId});
  final CrmRepository repository;
  final String leadId;
  @override
  State<_FollowUpSheet> createState() => _FollowUpSheetState();
}

class _FollowUpSheetState extends State<_FollowUpSheet> {
  String _channel = 'CALL', _outcome = 'ANSWERED';
  final _note = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.addFollowUp(
        widget.leadId,
        channel: _channel,
        outcome: _outcome,
        note: _note.text,
        nextFollowUpAt: _date == null
            ? null
            : crmOffsetIso(_combine(_date!, _time ?? TimeOfDay.now())),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _CrmFormSheet(
    title: 'حجز متابعة',
    subtitle: 'سجل التواصل وموعد المتابعة القادمة',
    primaryLabel: 'حفظ المتابعة',
    busy: _busy,
    error: _error,
    onSave: _save,
    children: [
      AppSelect<String>(
        label: 'القناة',
        value: _channel,
        options: [
          for (final entry in crmFollowUpChannelLabels.entries)
            if (entry.key != 'SOURCE')
              AppSelectOption(value: entry.key, label: entry.value),
        ],
        onChanged: (value) => setState(() => _channel = value ?? 'CALL'),
      ),
      const SizedBox(height: 12),
      AppSelect<String>(
        label: 'النتيجة',
        value: _outcome,
        options: [
          for (final entry in crmFollowUpOutcomeLabels.entries)
            AppSelectOption(value: entry.key, label: entry.value),
        ],
        onChanged: (value) => setState(() => _outcome = value ?? 'ANSWERED'),
      ),
      const SizedBox(height: 12),
      _DateTimePickerFields(
        date: _date,
        time: _time,
        dateLabel: 'المتابعة القادمة',
        timeLabel: 'الوقت',
        onDate: (value) => setState(() => _date = value),
        onTime: (value) => setState(() => _time = value),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _note,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'ملاحظة'),
      ),
    ],
  );
}

class _InspectionSheet extends StatefulWidget {
  const _InspectionSheet({required this.repository, required this.lead});
  final CrmRepository repository;
  final CrmLeadDetail lead;

  @override
  State<_InspectionSheet> createState() => _InspectionSheetState();
}

class _InspectionSheetState extends State<_InspectionSheet> {
  final _price = TextEditingController();
  late final _address = TextEditingController(text: widget.lead.address);
  List<CrmRef> _engineers = const [];
  List<CrmRef> _inspectionTypes = const [];
  String _engineerId = '';
  String _inspectionTypeId = '';
  DateTime? _date;
  TimeOfDay? _time;
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
        widget.repository.inspectionEngineers(),
        widget.repository.inspectionTypes(),
      ]);
      if (mounted) {
        setState(() {
          _engineers = values[0];
          _inspectionTypes = values[1];
          if (_inspectionTypes.isNotEmpty) {
            _inspectionTypeId = _inspectionTypes.first.id;
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _price.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = num.tryParse(_price.text.trim());
    if (_date == null ||
        _time == null ||
        _engineerId.isEmpty ||
        _inspectionTypeId.isEmpty ||
        price == null) {
      setState(
        () => _error = 'أكمل نوع المعاينة والتاريخ والوقت والمهندس والسعر.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.addInspection(
        leadId: widget.lead.id,
        inspectionTypeId: _inspectionTypeId,
        scheduledAt: crmOffsetIso(_combine(_date!, _time!)),
        engineerId: _engineerId,
        agreedPrice: price,
        address: _address.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _CrmFormSheet(
    title: 'حجز معاينة',
    subtitle: widget.lead.name,
    primaryLabel: 'حجز المعاينة',
    busy: _busy,
    error: _error,
    onSave: _save,
    children: [
      AppSelect<String>(
        label: 'نوع المعاينة *',
        value: _inspectionTypeId.isEmpty ? null : _inspectionTypeId,
        options: [
          for (final type in _inspectionTypes)
            AppSelectOption(value: type.id, label: type.name),
        ],
        onChanged: (value) => setState(() => _inspectionTypeId = value ?? ''),
      ),
      const SizedBox(height: 12),
      _DateTimePickerFields(
        date: _date,
        time: _time,
        dateLabel: 'تاريخ المعاينة *',
        timeLabel: 'الوقت *',
        onDate: (value) => setState(() => _date = value),
        onTime: (value) => setState(() => _time = value),
      ),
      const SizedBox(height: 12),
      AppSelect<String>(
        label: 'المهندس *',
        value: _engineerId.isEmpty ? null : _engineerId,
        options: [
          for (final engineer in _engineers)
            AppSelectOption(value: engineer.id, label: engineer.name),
        ],
        onChanged: (value) => setState(() => _engineerId = value ?? ''),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _price,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(labelText: 'السعر المتفق عليه *'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _address,
        decoration: const InputDecoration(labelText: 'العنوان'),
      ),
    ],
  );
}

class _MeetingSheet extends StatefulWidget {
  const _MeetingSheet({required this.repository, required this.lead});
  final MeetingsRepository repository;
  final CrmLeadDetail lead;

  @override
  State<_MeetingSheet> createState() => _MeetingSheetState();
}

class _MeetingSheetState extends State<_MeetingSheet> {
  late final _title = TextEditingController(
    text: 'اجتماع مع ${widget.lead.name}',
  );
  late final _location = TextEditingController(text: widget.lead.address);
  final _link = TextEditingController();
  String _type = 'IN_PERSON';
  DateTime? _date;
  TimeOfDay? _time;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _date == null || _time == null) {
      setState(() => _error = 'أكمل العنوان والتاريخ والوقت.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.createForLead(
        leadId: widget.lead.id,
        leadName: widget.lead.name,
        leadMobile: widget.lead.mobile,
        title: _title.text,
        meetingType: _type,
        startAt: crmOffsetIso(_combine(_date!, _time!)),
        location: _location.text,
        link: _link.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _CrmFormSheet(
    title: 'حجز اجتماع',
    subtitle: widget.lead.name,
    primaryLabel: 'حجز الاجتماع',
    busy: _busy,
    error: _error,
    onSave: _save,
    children: [
      TextField(
        controller: _title,
        decoration: const InputDecoration(labelText: 'العنوان *'),
      ),
      const SizedBox(height: 12),
      AppSelect<String>(
        label: 'النوع',
        value: _type,
        options: [
          for (final entry in meetingTypeLabels.entries)
            AppSelectOption(value: entry.key, label: entry.value),
        ],
        onChanged: (value) => setState(() => _type = value ?? 'IN_PERSON'),
      ),
      const SizedBox(height: 12),
      _DateTimePickerFields(
        date: _date,
        time: _time,
        dateLabel: 'تاريخ الاجتماع *',
        timeLabel: 'الوقت *',
        onDate: (value) => setState(() => _date = value),
        onTime: (value) => setState(() => _time = value),
      ),
      const SizedBox(height: 12),
      if (_type == 'ONLINE')
        TextField(
          controller: _link,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'الرابط'),
        )
      else
        TextField(
          controller: _location,
          decoration: const InputDecoration(labelText: 'المكان'),
        ),
    ],
  );
}

class _DateTimePickerFields extends StatelessWidget {
  const _DateTimePickerFields({
    required this.date,
    required this.time,
    required this.dateLabel,
    required this.timeLabel,
    required this.onDate,
    required this.onTime,
  });
  final DateTime? date;
  final TimeOfDay? time;
  final String dateLabel;
  final String timeLabel;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<TimeOfDay> onTime;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _PickerField(
          label: dateLabel,
          value: date == null ? 'dd/mm/yyyy' : _dateText(date!),
          icon: LucideIcons.calendarDays,
          onTap: () async {
            final now = DateTime.now();
            final picked = await showAppDatePicker(
              context: context,
              initialDate: date ?? now,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 10),
            );
            if (picked != null) onDate(picked);
          },
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _PickerField(
          label: timeLabel,
          value: time == null ? '--:--' : _timeText(time!),
          icon: LucideIcons.clock3,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time ?? TimeOfDay.now(),
            );
            if (picked != null) onTime(picked);
          },
        ),
      ),
    ],
  );
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, suffixIcon: Icon(icon)),
      child: Text(value, textDirection: TextDirection.ltr),
    ),
  );
}

DateTime _combine(DateTime date, TimeOfDay time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

String _dateText(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

String _timeText(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

class _Field extends StatelessWidget {
  const _Field(this.label, this.value, {required this.width, this.ltr = false});
  final String label;
  final String value;
  final double width;
  final bool ltr;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.tokens.brand,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(minHeight: 40),
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: context.tokens.canvas,
            border: Border.all(color: context.tokens.line),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textDirection: ltr ? TextDirection.ltr : null,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 155,
    constraints: const BoxConstraints(minHeight: 82),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [
          Colors.white,
          Color.alphaBlend(color.withValues(alpha: .08), Colors.white),
        ],
      ),
      border: Border.all(color: color.withValues(alpha: .22)),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: context.tokens.brandStrong.withValues(alpha: .05),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withValues(alpha: .18)),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.tokens.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  color: value > 0 ? color : context.tokens.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
