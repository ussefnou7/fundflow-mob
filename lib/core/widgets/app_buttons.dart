import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The one "add" button: «+ label». Filled for a screen or tab's main action;
/// [secondary] is the outlined form for adding a line inside a form.
class AppAddButton extends StatelessWidget {
  const AppAddButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.icon = LucideIcons.plus,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 17);
    final text = Text(label);
    return secondary
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: iconWidget,
            label: text,
          )
        : FilledButton.icon(
            onPressed: onPressed,
            icon: iconWidget,
            label: text,
          );
  }
}

/// The one "edit" button: an outlined pencil, on a row or beside a title.
class AppEditButton extends StatelessWidget {
  const AppEditButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.icon = LucideIcons.pencil,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, size: 17),
  );
}
