import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/format/exact_decimal.dart';
import '../../../core/theme/app_theme.dart';

/// The dark account card at the top of a contractor or cost-centre account:
/// back, name and code, then its money in light tiles.
class AccountHero extends StatelessWidget {
  const AccountHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.backTooltip,
    required this.onBack,
    required this.metrics,
    this.active,
    this.onEdit,
    this.editTooltip = 'تعديل',
  });

  final String title;
  final String subtitle;
  final String backTooltip;
  final VoidCallback onBack;

  /// label, value, colour; money values are formatted, plain counts are not.
  final List<(String, String, Color)> metrics;
  final bool? active;

  /// A pencil beside the title, in the hero's own light-on-dark style.
  final VoidCallback? onEdit;
  final String editTooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      constraints: const BoxConstraints(minHeight: 136),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
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
            color: tokens.brandDeep.withValues(alpha: .2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: backTooltip,
                onPressed: onBack,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .1),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(40, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(LucideIcons.arrowRight, size: 19),
              ),
              const Spacer(),
              if (active != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .16),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    active! ? 'نشط' : 'غير نشط',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (onEdit != null) ...[
                IconButton(
                  tooltip: editTooltip,
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(40, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(LucideIcons.pencil, size: 17),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xC7FFFFFF),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    for (final (i, (label, value, color))
                        in metrics.indexed) ...[
                      if (i > 0) VerticalDivider(width: 1, color: tokens.line),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 11,
                          ),
                          child: Column(
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  color: tokens.muted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String accountMoney(String? value) =>
    (ExactDecimal.tryParse(value ?? '') ?? ExactDecimal.zero).money();
