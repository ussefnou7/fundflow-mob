import 'package:flutter/material.dart';

import '../../../core/time/server_clock.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/meetings_repository.dart';
import '../../crm/domain/crm_models.dart';
import '../domain/meeting_models.dart';
import 'meetings_section.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key, required this.repository});
  final MeetingsRepository repository;
  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  List<Meeting>? _items;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repository.mine();
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
    final rows = _items ?? const <Meeting>[];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          PageHeader(title: 'الاجتماعات', subtitle: '${rows.length} اجتماع'),
          const SizedBox(height: 12),
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _load)
          else
            AppDataTable<Meeting>(
              loading: _items == null,
              rows: rows,
              columns: const [
                AppTableColumn('الموعد', 150),
                AppTableColumn('العنوان', 180),
                AppTableColumn('السجل', 150),
                AppTableColumn('الحالة', 110),
                AppTableColumn('المكان/الرابط', 180),
              ],
              cells: (item) => [
                Text(_format(item.startAt)),
                AppTableTitle(
                  title: item.title,
                  subtitle: meetingTypeLabels[item.meetingType],
                ),
                Text(item.ownerLabel),
                AppTag(
                  meetingStatusLabels[item.status] ?? item.status,
                  tone: meetingTone(item.status),
                ),
                Text(item.link ?? item.location ?? '—', maxLines: 2),
              ],
            ),
        ],
      ),
    );
  }

  String _format(String value) {
    final date = serverWallTime(value);
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
