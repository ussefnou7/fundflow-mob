import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

/// Opens a bottom sheet with the app's standard frame. [tall] gives forms a
/// fixed height so attached dropdowns always have room to open.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool tall = false,
  bool dismissible = true,
}) {
  final height = MediaQuery.sizeOf(context).height;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    constraints: BoxConstraints(maxHeight: height * .92),
    builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: tall
          ? SizedBox(height: height * .92, child: builder(context))
          : builder(context),
    ),
  );
}

/// Grabber, title row, scrolling body and a footer that stays above the keyboard.
class AppSheetScaffold extends StatelessWidget {
  const AppSheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.footer,
    this.onClose,
    this.closeEnabled = true,
    this.leading,
    this.bodyPadding = const EdgeInsets.fromLTRB(20, 4, 20, 20),
    this.scrollController,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final VoidCallback? onClose;
  final bool closeEnabled;
  final Widget? leading;
  final EdgeInsets bodyPadding;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        // A tall sheet has a fixed height: the body fills it and the footer
        // stays on the bottom edge instead of floating under short content.
        final fixed = constraints.hasTightHeight;
        final body = SingleChildScrollView(
          controller: scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: bodyPadding,
          child: child,
        );
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 5,
                margin: const EdgeInsets.only(top: 8, bottom: 2),
                decoration: BoxDecoration(
                  color: tokens.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              height: 1.4,
                              fontWeight: FontWeight.w800,
                              color: tokens.ink,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: closeEnabled
                          ? onClose ?? () => Navigator.maybePop(context)
                          : null,
                      style: IconButton.styleFrom(
                        backgroundColor: tokens.sunken,
                        minimumSize: const Size(38, 38),
                      ),
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
                  ],
                ),
              ),
              fixed ? Expanded(child: body) : Flexible(child: body),
              if (footer != null)
                Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    12 +
                        (keyboard > 0
                            ? 0
                            : MediaQuery.paddingOf(context).bottom),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: tokens.line)),
                  ),
                  child: footer,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A sheet footer's buttons: an optional secondary on the start side and the
/// primary action filling the rest.
class AppSheetActions extends StatelessWidget {
  const AppSheetActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.busy = false,
    this.busyLabel,
    this.secondaryLabel,
    this.onSecondary,
    this.destructive = false,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final IconData? primaryIcon;
  final bool busy;
  final String? busyLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        if (secondaryLabel != null) ...[
          OutlinedButton(
            onPressed: busy ? null : onSecondary,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(110, 50),
              foregroundColor: tokens.ink,
              backgroundColor: tokens.sunken,
              side: BorderSide(color: tokens.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              textStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            child: Text(secondaryLabel!),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: FilledButton.icon(
            onPressed: busy ? null : onPrimary,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: destructive ? AppTokens.danger : tokens.brand,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              textStyle: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            icon: busy
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(primaryIcon ?? LucideIcons.check, size: 18),
            label: Text(busy ? (busyLabel ?? 'جارٍ الحفظ…') : primaryLabel),
          ),
        ),
      ],
    );
  }
}

/// The large amount entry used at the top of money forms, with a balance line.
class AppAmountField extends StatelessWidget {
  const AppAmountField({
    super.key,
    required this.controller,
    this.label = 'المبلغ *',
    this.hint,
    this.hintValue,
    this.warning = false,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.currency = 'ج.م',
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? hintValue;
  final bool warning;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return FormField<String>(
      validator: (_) => validator?.call(controller.text),
      builder: (state) {
        final invalid = state.hasError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              decoration: BoxDecoration(
                color: tokens.sunken,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: invalid ? AppTokens.danger : tokens.line,
                  width: invalid ? 1.4 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: tokens.muted,
                    ),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            enabled: enabled,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (value) {
                              state.didChange(value);
                              onChanged?.call(value);
                            },
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: tokens.ink,
                              letterSpacing: -.5,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(color: tokens.line),
                              filled: false,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currency,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: tokens.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hint != null) ...[
                    Divider(height: 14, color: tokens.line),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hint!,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: warning ? AppTokens.warning : tokens.muted,
                            ),
                          ),
                        ),
                        if (hintValue != null)
                          Text(
                            hintValue!,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: warning ? AppTokens.warning : tokens.ink,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (invalid)
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 4),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTokens.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A two-option switch for short enums inside forms and filters.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String, IconData?)> options;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.sunken,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        children: [
          for (final (option, label, icon) in options)
            Expanded(
              child: Material(
                color: option == value ? Colors.white : Colors.transparent,
                elevation: option == value ? 1 : 0,
                shadowColor: tokens.brandStrong.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  onTap: onChanged == null ? null : () => onChanged!(option),
                  borderRadius: BorderRadius.circular(11),
                  child: SizedBox(
                    height: 42,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon,
                            size: 16,
                            color: option == value
                                ? tokens.brandStrong
                                : tokens.muted,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: option == value
                                ? tokens.brandStrong
                                : tokens.muted,
                          ),
                        ),
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
