import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/media/invoice_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_filter.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/hr_repository.dart';
import '../domain/hr_models.dart';
import 'hr_widgets.dart';

/// Opens the request form; true once a request was filed.
Future<bool> showHrRequestForm(
  BuildContext context, {
  required HrRepository repository,
  String type = 'LEAVE',
  DateTime? date,
}) async =>
    await showAppSheet<bool>(
      context,
      tall: true,
      dismissible: false,
      builder: (context) =>
          _RequestForm(repository: repository, initialType: type, date: date),
    ) ??
    false;

class _RequestForm extends StatefulWidget {
  const _RequestForm({
    required this.repository,
    required this.initialType,
    this.date,
  });

  final HrRepository repository;
  final String initialType;
  final DateTime? date;

  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late String _type = widget.initialType;
  HrRequestOptions? _options;
  String? _leaveTypeId;
  late DateTime _from = widget.date ?? _today;
  DateTime? _to;
  TimeOfDay? _fromTime;
  TimeOfDay? _toTime;
  String _punchType = 'IN';
  bool _missionHours = false;
  XFile? _attachment;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _picked = false;

  /// The server's date. The phone's stands in only until any HR answer has
  /// synced the clock, and the options request does that on opening.
  DateTime get _today {
    final now = widget.repository.clock.now() ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    widget.repository
        .requestOptions()
        .then((options) {
          if (!mounted) return;
          setState(() {
            _options = options;
            // The answer synced the server's clock; start from its day.
            if (widget.date == null && !_picked) _from = _today;
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
    _reason.dispose();
    super.dispose();
  }

  HrLeaveType? get _leaveType =>
      _options?.leaveTypes.where((type) => type.id == _leaveTypeId).firstOrNull;

  /// Whole days for leave and day missions; one day with hours otherwise.
  bool get _wholeDays =>
      _type == 'LEAVE' || (_type == 'MISSION' && !_missionHours);

  bool get _needsAttachment =>
      _type == 'LEAVE' && (_leaveType?.attachmentRequired ?? false);

  String _iso(DateTime value) => formatIsoDate(value);
  String _clock(TimeOfDay value) =>
      '${two(value.hour)}:${two(value.minute)}:00';

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_needsAttachment && _attachment == null) {
      setState(() => _error = 'هذا النوع من الإجازات يتطلب مرفقًا');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final request = await widget.repository.createRequest(
        HrRequestInput(
          requestType: _type,
          leaveTypeId: _type == 'LEAVE' ? _leaveTypeId : null,
          fromDate: _iso(_from),
          toDate: _wholeDays ? _iso(_to ?? _from) : null,
          fromTime: _wholeDays || _fromTime == null ? null : _clock(_fromTime!),
          toTime:
              _wholeDays || _type == 'ATTENDANCE_CORRECTION' || _toTime == null
              ? null
              : _clock(_toTime!),
          punchType: _type == 'ATTENDANCE_CORRECTION' ? _punchType : null,
          reason: _reason.text,
        ),
      );
      if (_attachment != null) {
        await widget.repository.attach(request, _attachment!.path);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate({required bool end}) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: end ? (_to ?? _from) : _from,
      firstDate: DateTime(2020),
      lastDate: _today.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _picked = true;
      if (end) {
        _to = picked;
      } else {
        _from = picked;
        if (_to != null && _to!.isBefore(picked)) _to = picked;
      }
    });
  }

  Future<void> _pickTime({required bool end}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (end ? _toTime : _fromTime) ??
          TimeOfDay.fromDateTime(widget.repository.clock.now() ?? _today),
    );
    if (picked == null) return;
    setState(() {
      if (end) {
        _toTime = picked;
      } else {
        _fromTime = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final options = _options;
    return AppSheetScaffold(
      title: 'طلب جديد',
      subtitle: 'يُرسل إلى المدير المباشر أو الموارد البشرية للقرار',
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
            const _Label('نوع الطلب'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.9,
              children: [
                for (final type in const [
                  'LEAVE',
                  'PERMISSION',
                  'MISSION',
                  'ATTENDANCE_CORRECTION',
                ])
                  _TypeTile(
                    type: type,
                    selected: type == _type,
                    onTap: _busy ? null : () => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_type == 'LEAVE') ...[
              AppSelect<String>(
                label: 'نوع الإجازة *',
                value: _leaveTypeId,
                enabled: !_busy && !_loading,
                placeholder: _loading ? 'جارٍ التحميل…' : 'اختر نوع الإجازة',
                options: [
                  for (final type
                      in options?.leaveTypes ?? const <HrLeaveType>[])
                    if (type.active)
                      AppSelectOption(
                        value: type.id,
                        label: type.name,
                        subtitle: _balanceText(options!, type),
                      ),
                ],
                onChanged: (value) => setState(() => _leaveTypeId = value),
                validator: (value) => value == null ? 'اختر نوع الإجازة' : null,
              ),
              const SizedBox(height: 12),
            ],
            if (_type == 'MISSION') ...[
              AppSegmented<bool>(
                value: _missionHours,
                options: const [
                  (false, 'أيام كاملة', LucideIcons.calendarDays),
                  (true, 'ساعات من يوم', LucideIcons.clock),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _missionHours = value),
              ),
              const SizedBox(height: 12),
            ],
            if (_type == 'ATTENDANCE_CORRECTION') ...[
              const _Label('البصمة المنسية'),
              AppSegmented<String>(
                value: _punchType,
                options: const [
                  ('IN', 'حضور', LucideIcons.logIn),
                  ('OUT', 'انصراف', LucideIcons.logOut),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _punchType = value),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    label: _wholeDays ? 'من تاريخ *' : 'التاريخ *',
                    value: hrDate(_iso(_from)),
                    icon: LucideIcons.calendarDays,
                    onTap: _busy ? null : () => _pickDate(end: false),
                  ),
                ),
                if (_wholeDays) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickerField(
                      label: 'إلى تاريخ *',
                      value: hrDate(_iso(_to ?? _from)),
                      icon: LucideIcons.calendarDays,
                      onTap: _busy ? null : () => _pickDate(end: true),
                    ),
                  ),
                ],
              ],
            ),
            if (!_wholeDays) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PickerField(
                      label: _type == 'ATTENDANCE_CORRECTION'
                          ? 'وقت البصمة *'
                          : 'من الساعة *',
                      value: _fromTime == null ? null : _clock(_fromTime!),
                      icon: LucideIcons.clock,
                      onTap: _busy ? null : () => _pickTime(end: false),
                      validator: () => _fromTime == null ? 'اختر الوقت' : null,
                    ),
                  ),
                  if (_type != 'ATTENDANCE_CORRECTION') ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickerField(
                        label: 'إلى الساعة *',
                        value: _toTime == null ? null : _clock(_toTime!),
                        icon: LucideIcons.clock,
                        onTap: _busy ? null : () => _pickTime(end: true),
                        validator: () => _toTime == null ? 'اختر الوقت' : null,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (_type == 'PERMISSION' && options?.permissions != null) ...[
              const SizedBox(height: 10),
              _PermissionNote(usage: options!.permissions!),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              enabled: !_busy,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: _type == 'ATTENDANCE_CORRECTION'
                    ? 'السبب *'
                    : 'السبب (اختياري)',
                alignLabelWithHint: true,
                counterText: '',
              ),
              validator: (value) =>
                  _type == 'ATTENDANCE_CORRECTION' &&
                      (value == null || value.trim().isEmpty)
                  ? 'اذكر سبب نسيان البصمة'
                  : null,
            ),
            if (_type == 'LEAVE' || _type == 'MISSION') ...[
              const SizedBox(height: 12),
              _AttachmentField(
                file: _attachment,
                required: _needsAttachment,
                onPick: _busy
                    ? null
                    : () async {
                        final files = await pickInvoiceImages(
                          context,
                          single: true,
                        );
                        if (files.isNotEmpty && mounted) {
                          setState(() => _attachment = files.first);
                        }
                      },
                onRemove: _busy
                    ? null
                    : () => setState(() => _attachment = null),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'يمكنك إلغاء الطلب ما دام قيد المراجعة.',
              style: TextStyle(fontSize: 11.5, color: tokens.muted),
            ),
          ],
        ),
      ),
    );
  }

  String? _balanceText(HrRequestOptions options, HrLeaveType type) {
    final balance = options.balances
        .where((item) => item.leaveType?.id == type.id)
        .firstOrNull;
    if (balance == null) return type.paid ? null : 'بدون رصيد · غير مدفوعة';
    return 'متاح ${balance.availableDays} يوم';
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: context.tokens.ink,
      ),
    ),
  );
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final String type;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: selected ? tokens.wash : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? tokens.brand : tokens.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(
                requestTypeIcon(type),
                size: 18,
                color: selected ? tokens.brandStrong : tokens.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  requestTypeLabel(type),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? tokens.brandStrong : tokens.ink,
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

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.validator,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback? onTap;
  final String? Function()? validator;

  @override
  Widget build(BuildContext context) => FormField<String>(
    validator: (_) => validator?.call(),
    builder: (state) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          errorText: state.errorText,
          suffixIcon: Icon(icon, size: 18),
        ),
        child: Text(
          value == null
              ? ''
              : (value!.length == 8 ? value!.substring(0, 5) : value!),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
        ),
      ),
    ),
  );
}

class _PermissionNote extends StatelessWidget {
  const _PermissionNote({required this.usage});
  final HrPermissionUsage usage;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final parts = [
      'المستخدم ${usage.usedMinutes}${usage.maxMinutes == null ? '' : ' من ${usage.maxMinutes}'} دقيقة',
      '${usage.usedCount}${usage.maxCount == null ? '' : ' من ${usage.maxCount}'} مرة',
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.sunken,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.info, size: 16, color: AppTokens.info),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'أذونات الفترة (${hrRange(hrDate(usage.fromDate), hrDate(usage.toDate))}): ${parts.join(' · ')}',
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
    );
  }
}

class _AttachmentField extends StatelessWidget {
  const _AttachmentField({
    required this.file,
    required this.required,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? file;
  final bool required;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: file == null ? Colors.white : tokens.wash,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: file == null ? tokens.line : tokens.brand),
      ),
      child: InkWell(
        onTap: file == null ? onPick : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              Icon(
                file == null ? LucideIcons.paperclip : LucideIcons.fileCheck,
                size: 18,
                color: file == null ? tokens.muted : tokens.brand,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  file?.name ??
                      (required ? 'إرفاق مستند *' : 'إرفاق مستند (اختياري)'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: required && file == null
                        ? AppTokens.warning
                        : tokens.ink,
                  ),
                ),
              ),
              if (file != null)
                IconButton(
                  tooltip: 'حذف المرفق',
                  onPressed: onRemove,
                  icon: const Icon(LucideIcons.x, size: 17),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
