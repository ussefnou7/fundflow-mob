import 'package:flutter/material.dart';
import '../../../core/time/server_clock.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/crm_repository.dart';
import '../domain/crm_models.dart';
import 'inspection_detail_screen.dart';

class InspectionsScreen extends StatefulWidget {
  const InspectionsScreen({
    super.key,
    required this.repository,
    required this.permissions,
  });
  final CrmRepository repository;
  final Set<String> permissions;
  @override
  State<InspectionsScreen> createState() => _InspectionsScreenState();
}

class _InspectionsScreenState extends State<InspectionsScreen> {
  CrmPage<CrmInspection>? _result;
  int _page = 0;
  bool _loading = true;
  String? _error;
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
      final result = await widget.repository.inspections(page: _page);
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(CrmInspection item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionDetailScreen(
          repository: widget.repository,
          id: item.id,
          permissions: widget.permissions,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _result?.items ?? const <CrmInspection>[];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          PageHeader(
            title: 'المعاينات',
            subtitle: '${_result?.total ?? 0} معاينة',
          ),
          const SizedBox(height: 12),
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _load)
          else
            AppDataTable<CrmInspection>(
              loading: _loading,
              rows: rows,
              onTap: _open,
              columns: const [
                AppTableColumn('الوقت', 120),
                AppTableColumn('العميل', 150),
                AppTableColumn('المنطقة/العنوان', 190),
                AppTableColumn('الحالة', 110),
                AppTableColumn('المحصل', 100, numeric: true),
              ],
              cells: (row) => [
                Text(_dateTime(row.scheduledAt)),
                AppTableTitle(title: row.lead.name, subtitle: row.lead.mobile),
                Text(row.lead.area ?? row.address ?? '—'),
                Text(crmInspectionStatusLabels[row.status] ?? row.status),
                Text(row.collectedAmount ?? '—'),
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

String _dateTime(String value) {
  final date = serverWallTime(value);
  if (date == null) return '—';
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}  '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
