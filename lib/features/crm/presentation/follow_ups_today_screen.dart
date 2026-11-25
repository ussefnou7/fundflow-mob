import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/crm_repository.dart';
import '../domain/crm_models.dart';
import 'lead_file_screen.dart';

class FollowUpsTodayScreen extends StatefulWidget {
  const FollowUpsTodayScreen({
    super.key,
    required this.repository,
    required this.permissions,
  });
  final CrmRepository repository;
  final Set<String> permissions;
  @override
  State<FollowUpsTodayScreen> createState() => _FollowUpsTodayScreenState();
}

class _FollowUpsTodayScreenState extends State<FollowUpsTodayScreen> {
  List<CrmLeadSummary>? _rows;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.repository.dueFollowUps();
      if (mounted) {
        setState(() {
          _rows = rows;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows ?? const <CrmLeadSummary>[];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          PageHeader(title: 'متابعات اليوم', subtitle: '${rows.length} متابعة'),
          const SizedBox(height: 12),
          if (_error != null)
            MessagePanel(message: _error!, onRetry: _load)
          else
            AppDataTable<CrmLeadSummary>(
              loading: _rows == null,
              rows: rows,
              onTap: (lead) => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LeadFileScreen(
                    repository: widget.repository,
                    id: lead.id,
                    permissions: widget.permissions,
                    initialSection: 1,
                  ),
                ),
              ),
              columns: const [
                AppTableColumn('الاسم', 170),
                AppTableColumn('الموبايل', 150),
                AppTableColumn('الحالة', 130),
                AppTableColumn('المتابعة القادمة', 180),
              ],
              cells: (lead) => [
                Text(lead.name),
                TextButton(
                  onPressed: () => launchUrl(Uri.parse('tel:${lead.mobile}')),
                  child: Text(lead.mobile),
                ),
                Text(crmLeadStatusLabels[lead.status] ?? lead.status),
                Text(crmEnglishDateTime(lead.nextFollowUpAt)),
              ],
            ),
        ],
      ),
    );
  }
}
