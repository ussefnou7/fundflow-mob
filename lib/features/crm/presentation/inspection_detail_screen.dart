import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/crm_repository.dart';
import '../domain/crm_models.dart';

class InspectionDetailScreen extends StatefulWidget {
  const InspectionDetailScreen({
    super.key,
    required this.repository,
    required this.id,
    required this.permissions,
  });
  final CrmRepository repository;
  final String id;
  final Set<String> permissions;
  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  CrmInspection? _item;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final item = await widget.repository.inspection(widget.id);
      if (mounted) {
        setState(() {
          _item = item;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _launch(String value) async {
    final uri = Uri.parse(value);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح الرابط.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المعاينة')),
      body: item == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : MessagePanel(message: _error!, onRetry: _load),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageHeader(
                    title: 'تفاصيل المعاينة',
                    subtitle:
                        crmInspectionStatusLabels[item.status] ?? item.status,
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: item.lead.name,
                    children: [
                      Text(item.address ?? 'لا يوجد عنوان'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => _launch('tel:${item.lead.mobile}'),
                            icon: const Icon(LucideIcons.phone, size: 17),
                            label: const Text('اتصال'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _launch(
                              'https://wa.me/2${item.lead.mobile.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^2'), '')}',
                            ),
                            icon: const Icon(
                              LucideIcons.messageCircle,
                              size: 17,
                            ),
                            label: const Text('واتساب'),
                          ),
                          if (item.latitude != null && item.longitude != null)
                            FilledButton.tonalIcon(
                              onPressed: () => _launch(
                                'https://www.google.com/maps/dir/?api=1&destination=${item.latitude},${item.longitude}',
                              ),
                              icon: const Icon(LucideIcons.mapPinned, size: 17),
                              label: const Text('فتح في الخرائط'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: 'التحصيل',
                    children: [
                      Text('المتفق عليه: ${item.agreedPrice}'),
                      Text('المحصل: ${item.collectedAmount ?? '—'}'),
                      Text('المصاريف: ${item.expensesTotal}'),
                      Text('الصافي: ${item.net ?? '—'}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: 'تقرير المهندس',
                    children: [Text(item.engineerReport ?? 'لم يسجل تقرير')],
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    title: 'المصاريف',
                    children: item.expenses.isEmpty
                        ? [const Text('لا توجد مصاريف')]
                        : [
                            for (final expense in item.expenses)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(expense.expenseType),
                                subtitle: Text(expense.note ?? '—'),
                                trailing: Text(expense.amount),
                              ),
                          ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
}
