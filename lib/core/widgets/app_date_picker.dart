import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// System date picker shown as a floating dialog above the current screen.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (context, child) {
      final theme = Theme.of(context);
      final tokens = context.tokens;
      return Theme(
        data: theme.copyWith(
          datePickerTheme: theme.datePickerTheme.copyWith(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            headerBackgroundColor: tokens.brand,
            headerForegroundColor: Colors.white,
            headerHeadlineStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            headerHelpStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            weekdayStyle: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: tokens.muted,
              fontWeight: FontWeight.w600,
            ),
            dayStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            yearStyle: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
        child: Center(child: Transform.scale(scale: .88, child: child)),
      );
    },
  );
}
