import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../../extracts/domain/extract_models.dart';
import '../../extracts/presentation/contractor_extract_screen.dart';
import '../data/settings_repository.dart';
import '../domain/contractor_financial_detail.dart';
import 'settings_widgets.dart';

class ContractorDetailScreen extends StatefulWidget {
  const ContractorDetailScreen({
    super.key,
    required this.repository,
    required this.contractorId,
    required this.onBack,
  });

  final SettingsRepository repository;
  final String contractorId;
  final VoidCallback onBack;

  @override
  State<ContractorDetailScreen> createState() => _ContractorDetailScreenState();
}

class _ContractorDetailScreenState extends State<ContractorDetailScreen> {
  static const _pageSize = 10;
  ContractorFinancialDetail? _detail;
  String? _expandedId;
  String? _error;
  int _page = 0;
  bool _loading = true;

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
      final detail = await widget.repository.contractorFinancialDetail(
        widget.contractorId,
      );
      if (mounted) setState(() => _detail = detail);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final detail = _detail;
    if (_error != null && detail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: MessagePanel(message: _error!, onRetry: _load),
        ),
      );
    }
    if (detail == null) return const Center(child: CircularProgressIndicator());
    final extracts = detail.extracts;
    final visible = extracts
        .skip(_page * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.md,
          AppSpace.md,
          40,
        ),
        children: [
          AccountHero(
            title: detail.contractor.name,
            subtitle:
                '${detail.contractor.code} · ${detail.projectCount} مشروع',
            backTooltip: 'العودة للمقاولين',
            onBack: widget.onBack,
            metrics: [
              ('المستحق', accountMoney(detail.due), tokens.brandStrong),
              ('المسدّد', accountMoney(detail.settled), AppTokens.success),
              ('المتبقي', accountMoney(detail.debt), AppTokens.warning),
            ],
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tokens.line),
              ),
              child: const AppEmptyState(
                icon: LucideIcons.fileSpreadsheet,
                title: 'لا توجد مستخلصات لهذا المقاول',
              ),
            )
          else
            for (final ContractorExtract extract in visible) ...[
              RepaintBoundary(
                child: ContractorExtractCard(
                  extract: extract,
                  expanded: _expandedId == extract.id,
                  showFinancials: true,
                  onToggle: () => setState(() {
                    _expandedId = _expandedId == extract.id ? null : extract.id;
                  }),
                  onPrice: () {},
                  onReject: () {},
                ),
              ),
              const SizedBox(height: 10),
            ],
          AppPagination(
            page: _page,
            size: _pageSize,
            total: extracts.length,
            disabled: _loading,
            onChanged: (page) => setState(() => _page = page),
          ),
        ],
      ),
    );
  }
}
