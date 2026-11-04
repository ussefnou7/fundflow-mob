import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/format/arabic_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_refresh_page.dart';
import '../data/custody_repository.dart';
import '../domain/custody_models.dart';
import 'custody_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.onOpenAggregate,
    required this.onOpenCustody,
  });
  final CustodyRepository repository;
  final VoidCallback onOpenAggregate;
  final ValueChanged<String> onOpenCustody;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _data;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
    });
    try {
      final data = await widget.repository.dashboard();
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return AppRefreshPage(
      onRefresh: _load,
      children: [
        const PageHeader(title: 'لوحة المتابعة'),
        const SizedBox(height: AppSpace.md),
        if (_error != null)
          MessagePanel(message: _error!, onRetry: _load)
        else if (data == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          _MetricsGrid(data: data, onOpenAggregate: widget.onOpenAggregate),
          const SizedBox(height: 22),
          Text(
            'عهد الموظفين (${data.owners.length})',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: context.tokens.ink,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            textAlign: TextAlign.right,
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              hintText: 'اسم الموظف أو الكود…',
              fillColor: Colors.white,
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.tokens.line),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...data.owners
              .where(
                (owner) => normalizeArabic(
                  '${owner.name} ${owner.code}',
                ).contains(normalizeArabic(_search)),
              )
              .map(
                (owner) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OwnerCard(
                    owner: owner,
                    onOpen: () => widget.onOpenCustody(owner.id),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.data, required this.onOpenAggregate});
  final DashboardData data;
  final VoidCallback onOpenAggregate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    const soft = Color(0xB8FFFFFF);
    final cash = data.companyCash.isEmpty
        ? money('0')
        : data.companyCash
              .map((item) => '${money(item.total)} ${item.arabicCode}')
              .join(' · ');
    final tiles = <(String, String, IconData)>[
      ('إجمالي عدد الموظفين', '${data.memberCount}', LucideIcons.users),
      ('عدد أصحاب العهد', '${data.custodyOwnerCount}', LucideIcons.wallet),
      ('إجمالي نقدية الشركة', cash, LucideIcons.circleDollarSign),
      (
        'طلبات عهدة لم تُصرف',
        '${data.unpaidRequestCount} طلب · ${money(data.unpaidRequestAmount)} ج',
        LucideIcons.filePlus2,
      ),
    ];
    final parts = money(data.totalFunding).split('.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [tokens.brand, tokens.brandStrong, tokens.brandDeep],
              stops: const [0, .55, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.brandStrong.withValues(alpha: .35),
                blurRadius: 30,
                offset: const Offset(0, 14),
                spreadRadius: -16,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.landmark, size: 18, color: soft),
                  SizedBox(width: 8),
                  Text(
                    'إجمالي تمويل العهد',
                    style: TextStyle(
                      color: soft,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: parts.first),
                      if (parts.length > 1)
                        TextSpan(
                          text: '.${parts[1]}',
                          style: const TextStyle(
                            fontSize: 22,
                            color: Color(0xB3FFFFFF),
                          ),
                        ),
                    ],
                  ),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _HeroTile(
                      label: 'الرصيد المتبقي للعهد',
                      value: money(data.remaining),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeroTile(
                      label: 'المصروفات المعتمدة',
                      value: money(data.approvedAmount),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (label, value, icon) in tiles)
                  SizedBox(
                    width: width,
                    child: _MetricCard(label: label, value: value, icon: icon),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Material(
          color: tokens.brandStrong,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onOpenAggregate,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(LucideIcons.layers, color: Colors.white, size: 19),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'عرض مُجمّع العُهد',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(LucideIcons.arrowLeft, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: .09)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xB8FFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: 84,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: tokens.wash,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: tokens.brand),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          // Values mix figures with Arabic units («3 طلب · 45,000.00 ج»), so
          // they read right to left like the rest of the card.
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: tokens.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.owner, required this.onOpen});
  final CustodyOwner owner;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: tokens.line),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: tokens.washStrong,
                    foregroundColor: tokens.brandStrong,
                    child: Text(
                      owner.name.trim().isEmpty ? '؟' : owner.name.trim()[0],
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          owner.name,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${owner.code}${owner.custodyId == null ? ' · بدون عهدة' : ''}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: tokens.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onOpen,
                    tooltip: 'عرض العهدة',
                    icon: Icon(
                      LucideIcons.chevronLeft,
                      size: 19,
                      color: tokens.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: tokens.sunken,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tokens.line),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        _OwnerValue(
                          label: 'إجمالي التمويل',
                          value: owner.totalFunding,
                        ),
                        VerticalDivider(width: 1, color: tokens.line),
                        _OwnerValue(
                          label: 'المصروف المعتمد',
                          value: owner.approved,
                        ),
                        VerticalDivider(width: 1, color: tokens.line),
                        _OwnerValue(
                          label: 'المتبقي',
                          value: owner.remaining,
                          highlight: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'آخر تصفية: ${owner.lastSettledAt == null ? 'لم تتم التصفية بعد' : shortDate(owner.lastSettledAt!)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.muted,
                    fontWeight: FontWeight.w600,
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

class _OwnerValue extends StatelessWidget {
  const _OwnerValue({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: context.tokens.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            money(value),
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: highlight
                  ? context.tokens.brandStrong
                  : context.tokens.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );
}
