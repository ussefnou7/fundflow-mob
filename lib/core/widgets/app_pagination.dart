import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// Numbered pages under a table: the first, last and neighbouring pages are
/// shown and the gaps open a jump-to-page dialog. Rows per page live in the
/// screen's filters, as on the web.
class AppPagination extends StatelessWidget {
  const AppPagination({
    super.key,
    required this.page,
    required this.size,
    required this.total,
    required this.onChanged,
    this.disabled = false,
  });

  final int page;
  final int size;
  final int total;
  final ValueChanged<int> onChanged;
  final bool disabled;

  int get lastPage => math.max(1, (total / size).ceil());

  Future<void> _jump(BuildContext context) async {
    var input = '${page + 1}';
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الانتقال إلى صفحة'),
        content: TextFormField(
          initialValue: input,
          autofocus: true,
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: 'رقم الصفحة',
            helperText: 'من 1 إلى $lastPage',
          ),
          onChanged: (value) => input = value,
          onFieldSubmitted: (value) {
            final number = int.tryParse(value);
            if (number != null && number >= 1 && number <= lastPage) {
              Navigator.pop(context, number - 1);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final number = int.tryParse(input);
              if (number != null && number >= 1 && number <= lastPage) {
                Navigator.pop(context, number - 1);
              }
            },
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
    if (selected != null && selected != page) onChanged(selected);
  }

  /// Page indexes to draw, with null standing for a gap.
  List<int?> get _slots {
    final slots = <int?>[];
    for (var i = 0; i < lastPage; i++) {
      if (i == 0 || i == lastPage - 1 || (i - page).abs() <= 1) {
        slots.add(i);
      } else if (slots.last != null) {
        slots.add(null);
      }
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    final tokens = context.tokens;
    final from = page * size + 1;
    final to = math.min(total, (page + 1) * size);
    final info = TextStyle(
      fontSize: 12,
      color: tokens.muted,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lastPage > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PageButton(
                  tooltip: 'الصفحة السابقة',
                  onPressed: disabled || page == 0
                      ? null
                      : () => onChanged(page - 1),
                  child: const Icon(LucideIcons.chevronRight, size: 17),
                ),
                for (final slot in _slots)
                  slot == null
                      ? _PageButton(
                          tooltip: 'الانتقال إلى صفحة',
                          onPressed: disabled ? null : () => _jump(context),
                          plain: true,
                          child: const Text('…'),
                        )
                      : _PageButton(
                          tooltip: 'صفحة ${slot + 1}',
                          current: slot == page,
                          onPressed: disabled || slot == page
                              ? null
                              : () => onChanged(slot),
                          child: Text('${slot + 1}'),
                        ),
                _PageButton(
                  tooltip: 'الصفحة التالية',
                  onPressed: disabled || page + 1 >= lastPage
                      ? null
                      : () => onChanged(page + 1),
                  child: const Icon(LucideIcons.chevronLeft, size: 17),
                ),
              ],
            ),
          const SizedBox(height: 6),
          Text(
            lastPage > 1
                ? '$from–$to من $total · صفحة ${page + 1} من $lastPage'
                : '$from–$to من $total',
            textAlign: TextAlign.center,
            style: info,
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.current = false,
    this.plain = false,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final bool current;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = onPressed != null || current;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: current
              ? tokens.brandStrong
              : plain
              ? Colors.transparent
              : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
            side: current || plain
                ? BorderSide.none
                : BorderSide(color: tokens.line),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(11),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(
                    color: enabled ? tokens.ink : tokens.line,
                  ),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: current
                          ? Colors.white
                          : enabled
                          ? tokens.ink
                          : tokens.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
