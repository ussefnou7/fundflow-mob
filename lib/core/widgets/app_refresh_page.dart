import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The standard page container for screens whose data can be refreshed.
///
/// Keeping [AlwaysScrollableScrollPhysics] here makes pull-to-refresh work
/// even when the page content is shorter than the viewport.
class AppRefreshPage extends StatelessWidget {
  const AppRefreshPage({
    super.key,
    required this.onRefresh,
    required this.children,
    this.padding = const EdgeInsets.all(AppSpace.md),
  });

  final RefreshCallback onRefresh;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding.resolve(Directionality.of(context));
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: resolvedPadding.copyWith(
          bottom: resolvedPadding.bottom + keyboardInset,
        ),
        children: children,
      ),
    );
  }
}
