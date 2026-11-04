import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/format/arabic_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_filter.dart';
import '../../../core/widgets/app_pagination.dart';
import '../../../core/widgets/app_select.dart';
import '../../../core/widgets/app_table.dart';
import '../../custody/presentation/custody_widgets.dart';
import '../../extracts/domain/extract_models.dart';
import '../../extracts/presentation/contractor_extract_screen.dart';
import '../data/settings_repository.dart';
import '../domain/cost_center_financial_detail.dart';
import 'settings_widgets.dart';

class CostCenterDetailScreen extends StatefulWidget {
  const CostCenterDetailScreen({
    super.key,
    required this.repository,
    required this.centerId,
    required this.onBack,
  });

  final SettingsRepository repository;
  final String centerId;
  final VoidCallback onBack;

  @override
  State<CostCenterDetailScreen> createState() => _CostCenterDetailScreenState();
}

class _CostCenterDetailScreenState extends State<CostCenterDetailScreen> {
  final _search = TextEditingController();
  CostCenterFinancialDetail? _detail;
  String _status = '';
  String? _expandedId;
  String? _error;
  int _page = 0;
  int _pageSize = 10;
  bool _loading = true;

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
      final detail = await widget.repository.costCenterFinancial(
        widget.centerId,
      );
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ContractorExtract> get _filtered {
    final query = normalizeArabic(_search.text);
    return (_detail?.extracts ?? const <ContractorExtract>[])
        .where((extract) {
          if (_status.isNotEmpty && extract.status != _status) return false;
          if (query.isEmpty) return true;
          return normalizeArabic(extract.contractorName).contains(query) ||
              '${extract.extractNo}'.contains(query) ||
              extract.extractDate.contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _openFilters() async {
    final result = await showAppFilterSheet<(String, int)>(
      context: context,
      subtitle: 'مستخلصات المركز',
      initial: (_status, _pageSize),
      empty: ('', _pageSize),
      isActive: (draft) => draft.$1.isNotEmpty,
      fields: (context, draft, update) => AppFilterGrid(
        children: [
          AppSelect<String>(
            compact: true,
            label: 'الحالة',
            value: draft.$1,
            options: const [
              AppSelectOption(value: '', label: 'كل الحالات'),
              AppSelectOption(value: 'PENDING', label: 'بانتظار الاعتماد'),
              AppSelectOption(value: 'APPROVED', label: 'معتمد'),
              AppSelectOption(value: 'REJECTED', label: 'مرفوض'),
            ],
            onChanged: (value) => update((value ?? '', draft.$2)),
          ),
          appPageSizeField(
            value: draft.$2,
            onChanged: (size) => update((draft.$1, size)),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _status = result.$1;
      _pageSize = result.$2;
      _page = 0;
    });
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
    if (detail == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = _filtered;
    final lastPage = filtered.isEmpty ? 0 : (filtered.length - 1) ~/ _pageSize;
    if (_page > lastPage) _page = lastPage;
    final visible = filtered
        .skip(_page * _pageSize)
        .take(_pageSize)
        .toList(growable: false);
    final center = detail.center;
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
            title: center.name,
            subtitle:
                '${center.code} · ${center.type == 'OFFICE' ? 'مكتب' : 'مشروع'}',
            backTooltip: 'العودة لمراكز التكلفة',
            onBack: widget.onBack,
            active: center.active,
            metrics: [
              ('وارد', accountMoney(center.incoming), AppTokens.success),
              ('منصرف', accountMoney(center.outgoing), AppTokens.danger),
              ('مديون', accountMoney(center.debt), AppTokens.warning),
              ('مستخلص', '${center.extractCount ?? 0}', tokens.brandStrong),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _search,
            textAlign: TextAlign.right,
            onChanged: (_) => setState(() => _page = 0),
            decoration: InputDecoration(
              hintText: 'ابحث بالمقاول أو رقم المستخلص…',
              fillColor: Colors.white,
              prefixIcon: const Icon(LucideIcons.search, size: 19),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: tokens.line),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppFilterBar(
            activeCount: _status.isEmpty ? 0 : 1,
            summary: switch (_status) {
              'PENDING' => 'بانتظار الاعتماد',
              'APPROVED' => 'معتمد',
              'REJECTED' => 'مرفوض',
              _ => '',
            },
            onOpen: _openFilters,
            onClear: () => setState(() {
              _status = '';
              _page = 0;
            }),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: tokens.line),
              ),
              child: const AppEmptyState(
                icon: LucideIcons.fileSpreadsheet,
                title: 'لا توجد مستخلصات مطابقة',
              ),
            )
          else
            for (final extract in visible) ...[
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
            total: filtered.length,
            disabled: _loading,
            onChanged: (page) => setState(() => _page = page),
          ),
        ],
      ),
    );
  }
}
