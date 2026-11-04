import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: context.tokens.line),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: context.tokens.brandStrong.withValues(alpha: .035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                    color: context.tokens.brandStrong,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(color: context.tokens.muted, fontSize: 13),
                  ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: AppSpace.sm), action!],
        ],
      ),
    );
  }
}

class MessagePanel extends StatelessWidget {
  const MessagePanel({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTokens.dangerTint,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Column(
          children: [
            const Icon(LucideIcons.circleAlert, color: AppTokens.danger),
            const SizedBox(height: AppSpace.xs),
            SizedBox(
              width: double.infinity,
              child: Text(message, textAlign: TextAlign.right),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpace.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('إعادة المحاولة'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.fontSize = 11});
  final String label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (label) {
      'مرفوض' => (AppTokens.danger, AppTokens.dangerTint),
      'بانتظار الاستلام' ||
      'غير مصفّى' => (AppTokens.warning, AppTokens.warningTint),
      _ => (AppTokens.success, AppTokens.successTint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The custody balance: current balance with pending incoming and outgoing.
/// The eye hides the figures when the phone is shown to someone else.
class BalanceHero extends StatefulWidget {
  const BalanceHero({
    super.key,
    required this.remaining,
    required this.pendingIncoming,
    required this.pendingOutgoing,
    this.currency = 'ج.م',
  });

  final String remaining;
  final String pendingIncoming;
  final String pendingOutgoing;
  final String currency;

  @override
  State<BalanceHero> createState() => _BalanceHeroState();
}

class _BalanceHeroState extends State<BalanceHero> {
  bool _hidden = false;

  String _mask(String value) => _hidden ? '••••••' : value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final parts = widget.remaining.split('.');
    const soft = Color(0xB8FFFFFF);
    return Container(
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
          Row(
            children: [
              const Icon(LucideIcons.wallet, size: 18, color: soft),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'الرصيد الحالي',
                  style: TextStyle(
                    color: soft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: _hidden ? 'إظهار المبالغ' : 'إخفاء المبالغ',
                onPressed: () => setState(() => _hidden = !_hidden),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .08),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(36, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                icon: Icon(
                  _hidden ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: _mask(parts.first)),
                      if (!_hidden && parts.length > 1)
                        TextSpan(
                          text: '.${parts[1]}',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Color(0xB3FFFFFF),
                          ),
                        ),
                    ],
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.currency,
                style: const TextStyle(
                  color: soft,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PendingTile(
                  label: 'وارد معلّق',
                  value: _mask(widget.pendingIncoming),
                  icon: LucideIcons.arrowDownLeft,
                  iconColor: const Color(0xFF8FE0B4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PendingTile(
                  label: 'صادر معلّق',
                  value: _mask(widget.pendingOutgoing),
                  icon: LucideIcons.arrowUpRight,
                  iconColor: const Color(0xFFF5C38A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

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
        Row(
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xB8FFFFFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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

/// A square action under the balance; the primary one is filled with the brand.
class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Material(
      color: primary ? tokens.brand : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: primary ? BorderSide.none : BorderSide(color: tokens.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary
                      ? Colors.white.withValues(alpha: .14)
                      : tokens.wash,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: primary ? Colors.white : tokens.brand,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primary ? Colors.white : tokens.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented tabs over a screen's tables, each with an optional count of
/// items waiting on the user.
class LedgerTabs<T> extends StatelessWidget {
  const LedgerTabs({
    super.key,
    required this.value,
    required this.tabs,
    required this.onChanged,
  });

  final T value;
  final List<(T, String, int)> tabs;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tokens.ink.withValues(alpha: .06),
          tokens.canvas,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          for (final (tab, label, count) in tabs)
            // Long labels get more room, so four tabs fit without truncating.
            Expanded(
              flex: (label.length < 6 ? 6 : label.length) + (count > 0 ? 3 : 0),
              child: Material(
                color: tab == value ? Colors.white : Colors.transparent,
                elevation: tab == value ? 1 : 0,
                shadowColor: tokens.brandStrong.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => onChanged(tab),
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: tab == value ? tokens.ink : tokens.muted,
                            ),
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            height: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: tokens.brand,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
