import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

class AppTableColumn {
  const AppTableColumn(this.label, this.width, {this.numeric = false});
  final String label;
  final double width;

  /// Numbers line up on the left edge, as in an accounting ledger.
  final bool numeric;
}

/// The ledger table used by every statement screen: a horizontally scrolling
/// card with a header row and tappable rows that open details in a sheet.
class AppDataTable<T> extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.cells,
    this.onTap,
    this.rowColor,
    this.loading = false,
    this.empty,
  });

  final List<AppTableColumn> columns;
  final List<T> rows;
  final List<Widget> Function(T row) cells;
  final ValueChanged<T>? onTap;
  final Color? Function(T row)? rowColor;
  final bool loading;
  final Widget? empty;

  static const headerHeight = 40.0;
  static const rowHeight = 58.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (rows.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tokens.line),
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            : empty ??
                  const AppEmptyState(
                    icon: LucideIcons.inbox,
                    title: 'لا توجد بيانات مطابقة',
                  ),
      );
    }
    final natural = columns.fold<double>(0, (sum, c) => sum + c.width);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Narrow tables stretch to the card; wide ones scroll sideways.
          final scale = math.max(1.0, constraints.maxWidth / natural);
          final widths = [for (final c in columns) c.width * scale];
          return AnimatedOpacity(
            opacity: loading ? .55 : 1,
            duration: AppMotion.duration(context, AppMotion.feedback),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: natural * scale,
                child: Column(
                  children: [
                    Container(
                      height: headerHeight,
                      color: tokens.sunken,
                      child: Row(
                        children: [
                          for (var i = 0; i < columns.length; i++)
                            _Cell(
                              width: widths[i],
                              numeric: columns[i].numeric,
                              child: Text(
                                columns[i].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.muted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final row in rows)
                      Material(
                        color: rowColor?.call(row) ?? Colors.white,
                        child: InkWell(
                          onTap: onTap == null || loading
                              ? null
                              : () => onTap!(row),
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: rowHeight,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: tokens.line),
                              ),
                            ),
                            child: Row(
                              children: [
                                for (final (i, cell) in cells(row).indexed)
                                  _Cell(
                                    width: widths[i],
                                    numeric: columns[i].numeric,
                                    child: cell,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.child, this.numeric = false});

  final double width;
  final Widget child;
  final bool numeric;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    alignment: numeric
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart,
    child: DefaultTextStyle.merge(
      style: TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: context.tokens.ink,
      ),
      child: child,
    ),
  );
}

/// A cell with a bold first line and a small second line, optionally led by
/// a coloured dot that tells the row's kind at a glance.
class AppTableTitle extends StatelessWidget {
  const AppTableTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.dot,
  });

  final String title;
  final String? subtitle;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (dot != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: tokens.muted,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

enum AppMoneyTone { plain, incoming, voided }

/// An amount cell: tabular digits, signed, green for money coming in and
/// struck through when the entry no longer counts.
class AppMoney extends StatelessWidget {
  const AppMoney(
    this.text, {
    super.key,
    this.tone = AppMoneyTone.plain,
    this.size = 13.5,
  });

  final String text;
  final AppMoneyTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Text(
      text,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: switch (tone) {
          AppMoneyTone.incoming => AppTokens.success,
          AppMoneyTone.voided => tokens.muted,
          AppMoneyTone.plain => tokens.ink,
        },
        decoration: tone == AppMoneyTone.voided
            ? TextDecoration.lineThrough
            : null,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

enum AppTone { success, danger, warning, info, neutral, snag }

/// A small status label. Colour is never the only signal: the text says it.
class AppTag extends StatelessWidget {
  const AppTag(this.label, {super.key, this.tone = AppTone.neutral, this.icon});

  final String label;
  final AppTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (fg, bg) = switch (tone) {
      AppTone.success => (AppTokens.success, AppTokens.successTint),
      AppTone.danger => (AppTokens.danger, AppTokens.dangerTint),
      AppTone.warning => (AppTokens.warning, AppTokens.warningTint),
      AppTone.info => (AppTokens.info, AppTokens.infoTint),
      AppTone.snag => (AppTokens.snag, AppTokens.snagTint),
      AppTone.neutral => (tokens.ink, tokens.sunken),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: tone == AppTone.neutral ? Border.all(color: tokens.line) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// An empty or failed state inside a card.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.error = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: error ? AppTokens.dangerTint : tokens.wash,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              size: 26,
              color: error ? AppTokens.danger : tokens.brand,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: tokens.ink,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.8,
                color: tokens.muted,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
