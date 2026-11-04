import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'app_date_picker.dart';
import 'app_select.dart';
import 'app_sheet.dart';

/// The filter bar above a table, mirroring the web card: «الفلاتر» with a
/// «مفعّلة» badge, a one-line summary of what is applied and a clear action.
/// Tapping it opens the screen's filter sheet.
class AppFilterBar extends StatelessWidget {
  const AppFilterBar({
    super.key,
    required this.onOpen,
    this.activeCount = 0,
    this.summary = '',
    this.onClear,
    this.trailing,
  });

  final VoidCallback onOpen;
  final int activeCount;
  final String summary;
  final VoidCallback? onClear;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.slidersHorizontal,
                          size: 18,
                          color: tokens.ink,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'الفلاتر',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: tokens.ink,
                          ),
                        ),
                        if (activeCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: tokens.washStrong,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'مفعّلة',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: tokens.brandStrong,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          LucideIcons.chevronLeft,
                          size: 17,
                          color: tokens.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: trailing,
                ),
            ],
          ),
          if (summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 14, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: tokens.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onClear != null)
                    TextButton(
                      onPressed: onClear,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTokens.danger,
                        minimumSize: const Size(44, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('مسح'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Lays filter fields out two to a row, as in the web filter card.
class AppFilterGrid extends StatelessWidget {
  const AppFilterGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// A compact date filter: label above, tap to pick, × to clear.
class AppDateFilterField extends StatelessWidget {
  const AppDateFilterField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final current = value == null ? null : DateTime.tryParse(value!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: tokens.muted,
          ),
        ),
        const SizedBox(height: 5),
        Material(
          color: current == null ? Colors.white : tokens.wash,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: current == null ? tokens.line : tokens.brand,
              width: current == null ? 1 : 1.4,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showAppDatePicker(
                context: context,
                initialDate: current ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) onChanged(formatIsoDate(picked));
            },
            child: SizedBox(
              height: 46,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.calendarDays,
                      size: 16,
                      color: tokens.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        current == null
                            ? 'dd/mm/yyyy'
                            : formatDayMonthYear(current),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: current == null
                              ? FontWeight.w500
                              : FontWeight.w700,
                          color: current == null ? tokens.muted : tokens.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    if (current != null)
                      IconButton(
                        tooltip: 'مسح التاريخ',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onChanged(null),
                        icon: const Icon(LucideIcons.x, size: 15),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String formatIsoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String formatDayMonthYear(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/${value.year}';

/// Rows-per-page options shared by every table.
const appPageSizes = [10, 20, 50];

Widget appPageSizeField({
  required int value,
  required ValueChanged<int> onChanged,
}) => AppSelect<int>(
  compact: true,
  highlight: false,
  label: 'عدد الصفوف',
  value: value,
  options: [
    for (final size in appPageSizes)
      AppSelectOption(value: size, label: '$size'),
  ],
  onChanged: (size) => onChanged(size ?? value),
);

/// Opens the shared filter sheet. Fields edit a draft; nothing reaches the
/// screen until «عرض النتائج», so several filters cost one request.
Future<T?> showAppFilterSheet<T>({
  required BuildContext context,
  required String subtitle,
  required T initial,
  required T empty,
  required bool Function(T value) isActive,
  required Widget Function(
    BuildContext context,
    T draft,
    ValueChanged<T> update,
  )
  fields,
}) => showAppSheet<T>(
  context,
  builder: (context) {
    var draft = initial;
    return StatefulBuilder(
      builder: (context, setState) => AppSheetScaffold(
        title: 'الفلاتر',
        subtitle: subtitle,
        footer: AppSheetActions(
          primaryLabel: 'عرض النتائج',
          primaryIcon: LucideIcons.listFilter,
          onPrimary: () => Navigator.pop(context, draft),
          secondaryLabel: 'مسح الفلاتر',
          onSecondary: isActive(draft)
              ? () => setState(() => draft = empty)
              : null,
        ),
        child: fields(context, draft, (next) => setState(() => draft = next)),
      ),
    );
  },
);
