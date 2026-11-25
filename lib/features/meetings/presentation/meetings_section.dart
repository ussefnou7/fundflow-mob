import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../../crm/domain/crm_models.dart';
import '../data/meetings_repository.dart';
import '../domain/meeting_models.dart';

class MeetingsSection extends StatefulWidget {
  const MeetingsSection({
    super.key,
    required this.repository,
    required this.ownerType,
    required this.ownerId,
    required this.canManage,
  });
  final MeetingsRepository repository;
  final String ownerType, ownerId;
  final bool canManage;
  @override
  State<MeetingsSection> createState() => _MeetingsSectionState();
}

class _MeetingsSectionState extends State<MeetingsSection> {
  List<Meeting>? _items;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.forOwner(
        widget.ownerType,
        widget.ownerId,
      );
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return MessagePanel(message: _error!, onRetry: _load);
    return AppDataTable<Meeting>(
      loading: _items == null,
      rows: _items ?? const [],
      empty: const AppEmptyState(
        icon: LucideIcons.calendarDays,
        title: 'لا توجد اجتماعات',
      ),
      columns: const [
        AppTableColumn('الموعد', 130),
        AppTableColumn('العنوان', 180),
        AppTableColumn('النوع', 90),
        AppTableColumn('المكان/الرابط', 170),
        AppTableColumn('الحالة', 110),
      ],
      cells: (item) => [
        Text(
          crmEnglishDateTime(item.startAt),
          textDirection: TextDirection.ltr,
        ),
        AppTableTitle(title: item.title, subtitle: item.organizer.name),
        Text(meetingTypeLabels[item.meetingType] ?? item.meetingType),
        Text(item.link ?? item.location ?? '—', maxLines: 2),
        AppTag(
          meetingStatusLabels[item.status] ?? item.status,
          tone: meetingTone(item.status),
        ),
      ],
    );
  }
}

AppTone meetingTone(String status) => switch (status) {
  'DONE' => AppTone.success,
  'CANCELLED' => AppTone.danger,
  'RESCHEDULED' => AppTone.warning,
  _ => AppTone.info,
};
