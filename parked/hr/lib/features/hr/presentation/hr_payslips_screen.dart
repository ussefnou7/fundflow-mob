import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_refresh_page.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../data/hr_repository.dart';
import '../domain/hr_models.dart';
import 'hr_widgets.dart';

class HrPayslipsScreen extends StatefulWidget {
  const HrPayslipsScreen({super.key, required this.repository});
  final HrRepository repository;

  @override
  State<HrPayslipsScreen> createState() => _HrPayslipsScreenState();
}

class _HrPayslipsScreenState extends State<HrPayslipsScreen> {
  List<HrMyPayslip> _rows = const [];
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
      final rows = await widget.repository.payslips();
      if (mounted) setState(() => _rows = rows);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AppRefreshPage(
      onRefresh: _load,
      children: [
        const PageHeader(
          title: 'قسائم المرتب',
          subtitle: 'القسائم المعتمدة وصافي المستحق',
        ),
        const SizedBox(height: 14),
        if (_error != null)
          MessagePanel(message: _error!, onRetry: _load)
        else if (_loading && _rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_rows.isEmpty)
          const AppEmptyState(
            icon: LucideIcons.receiptText,
            title: 'لا توجد قسائم معتمدة',
            message: 'تظهر القسيمة بعد اعتماد فترة المرتب.',
          )
        else
          for (final row in _rows) ...[
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tokens.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: tokens.wash,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          LucideIcons.receiptText,
                          size: 19,
                          color: tokens.brandStrong,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${hrDate(row.fromDate)} – ${hrDate(row.toDate)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (row.payDate != null)
                              Text(
                                'تاريخ الصرف ${hrDate(row.payDate!)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: tokens.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Money(
                          label: 'الإجمالي',
                          value: row.gross,
                          color: tokens.ink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Money(
                          label: 'الصافي',
                          value: row.net,
                          color: tokens.brandStrong,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: context.tokens.sunken,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.tokens.muted),
        ),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}
