import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../format/arabic_search.dart';
import '../theme/app_theme.dart';

class AppSelectOption<T> {
  const AppSelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.fieldLabel,
  });
  final T value;
  final String label;

  /// What the closed field shows once chosen, when the list line is too long.
  final String? fieldLabel;

  /// A secondary line such as a code; it is searchable too.
  final String? subtitle;
  final IconData? icon;
}

/// The one dropdown of the app. It opens attached to its field (above it when
/// there is no room below), and lists longer than [searchThreshold] get a
/// search box. The field is first scrolled near the top so the list keeps
/// room above the keyboard.
class AppSelect<T> extends StatefulWidget {
  const AppSelect({
    super.key,
    required this.label,
    required this.options,
    required this.onChanged,
    this.value,
    this.placeholder = 'اختر…',
    this.searchable,
    this.enabled = true,
    this.validator,
    this.compact = false,
    this.highlight,
  });

  final String label;
  final T? value;
  final String placeholder;
  final List<AppSelectOption<T>> options;
  final ValueChanged<T?> onChanged;

  /// Null decides from the list length.
  final bool? searchable;
  final bool enabled;
  final FormFieldValidator<T>? validator;

  /// Filter-grid style: the label sits above a white box that is outlined
  /// in the brand colour once a value is chosen.
  final bool compact;

  /// Compact fields outline themselves once they hold a real filter. Null
  /// treats '' and false as «all»; pass false for settings such as page size.
  final bool? highlight;

  static const searchThreshold = 8;

  @override
  State<AppSelect<T>> createState() => _AppSelectState<T>();
}

class _AppSelectState<T> extends State<AppSelect<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;

  bool get _searchable =>
      widget.searchable ?? widget.options.length > AppSelect.searchThreshold;

  @override
  void dispose() {
    _removeOverlay(notify: false);
    super.dispose();
  }

  Future<void> _open(FormFieldState<T> field) async {
    if (_overlay != null || !widget.enabled) return;
    final searchable = _searchable;
    await Scrollable.ensureVisible(
      context,
      alignment: searchable ? .06 : .18,
      duration: AppMotion.duration(context, AppMotion.expand),
      curve: AppMotion.curve,
    );
    if (!mounted) return;

    final fieldBox = context.findRenderObject()! as RenderBox;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final menuWidth = math.min(
      screenWidth - (AppSpace.md * 2),
      math.max(fieldBox.size.width, searchable ? 290.0 : 220.0),
    );
    _overlay = OverlayEntry(
      builder: (overlayContext) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) return const SizedBox.shrink();
        final media = MediaQuery.of(overlayContext);
        final top = box.localToGlobal(Offset.zero).dy;
        final bottom = top + box.size.height;
        final below =
            media.size.height -
            media.viewInsets.bottom -
            media.padding.bottom -
            bottom -
            18;
        final above = top - media.padding.top - 18;
        final natural = _SelectMenu.naturalHeight(
          widget.options.length,
          searchable,
        );
        final down = below >= math.min(natural, 220) || below >= above;
        final maxHeight = math.max(140.0, down ? below : above);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _removeOverlay,
                ),
              ),
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                targetAnchor: down ? Alignment.bottomRight : Alignment.topRight,
                followerAnchor: down
                    ? Alignment.topRight
                    : Alignment.bottomRight,
                offset: Offset(0, down ? 5 : -5),
                child: SizedBox(
                  width: menuWidth,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.min(maxHeight, 420),
                    ),
                    child: _SelectMenu<T>(
                      value: widget.value,
                      options: widget.options,
                      searchable: searchable,
                      onSelected: (value) {
                        _removeOverlay();
                        field.didChange(value);
                        widget.onChanged(value);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  void _removeOverlay({bool notify = true}) {
    _overlay?.remove();
    _overlay = null;
    if (notify && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.options
        .where((option) => option.value == widget.value)
        .firstOrNull;
    final tokens = context.tokens;
    final open = _overlay != null;
    final chevron = AnimatedRotation(
      turns: open ? .5 : 0,
      duration: AppMotion.duration(context, AppMotion.feedback),
      child: Icon(LucideIcons.chevronDown, size: 17, color: tokens.muted),
    );
    final text = Text(
      selected == null ? widget.placeholder : _display(selected),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: widget.compact ? 13 : 14,
        color: selected == null ? tokens.muted : tokens.ink,
        fontWeight: selected == null ? FontWeight.w500 : FontWeight.w700,
      ),
    );
    return CompositedTransformTarget(
      link: _layerLink,
      child: FormField<T>(
        initialValue: widget.value,
        validator: widget.validator,
        builder: (state) {
          if (widget.compact) {
            final value = selected?.value as Object?;
            final active =
                widget.highlight ??
                (selected != null && value != '' && value != false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: tokens.muted,
                  ),
                ),
                const SizedBox(height: 5),
                Material(
                  color: active ? tokens.wash : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: open || active ? tokens.brand : tokens.line,
                      width: open || active ? 1.4 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: widget.enabled ? () => _open(state) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 46,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(child: text),
                            const SizedBox(width: 6),
                            chevron,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return InkWell(
            onTap: widget.enabled ? () => _open(state) : null,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InputDecorator(
              // The placeholder is rendered as the decorator's child. Marking
              // the field empty makes InputDecorator fade that child out,
              // leaving an apparently blank select until a value is chosen.
              isEmpty: false,
              isFocused: open,
              decoration: InputDecoration(
                labelText: widget.label,
                errorText: state.errorText,
                enabled: widget.enabled,
                suffixIcon: chevron,
              ),
              child: text,
            ),
          );
        },
      ),
    );
  }

  String _display(AppSelectOption<T> option) {
    if (option.fieldLabel != null) return option.fieldLabel!;
    final subtitle = option.subtitle;
    return subtitle == null || subtitle.isEmpty || subtitle == option.label
        ? option.label
        : '$subtitle · ${option.label}';
  }
}

class _SelectMenu<T> extends StatefulWidget {
  const _SelectMenu({
    required this.value,
    required this.options,
    required this.searchable,
    required this.onSelected,
  });

  final T? value;
  final List<AppSelectOption<T>> options;
  final bool searchable;
  final ValueChanged<T> onSelected;

  static const rowHeight = 46.0;
  static const searchHeight = 58.0;

  static double naturalHeight(int count, bool searchable) =>
      math.min(count, 7) * rowHeight + 10 + (searchable ? searchHeight : 0);

  @override
  State<_SelectMenu<T>> createState() => _SelectMenuState<T>();
}

class _SelectMenuState<T> extends State<_SelectMenu<T>> {
  final _scrollController = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _matches(AppSelectOption<T> option, String query) =>
      query.isEmpty ||
      normalizeArabic(option.label).contains(query) ||
      normalizeArabic(option.subtitle ?? '').contains(query);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final query = normalizeArabic(_query);
    final selected = widget.options
        .where((option) => option.value == widget.value)
        .firstOrNull;
    // The current choice is pinned on top so it is never lost in a long list.
    final visible = [
      if (selected != null && _matches(selected, query)) selected,
      ...widget.options.where(
        (option) => option != selected && _matches(option, query),
      ),
    ];
    final pinned = selected != null && visible.firstOrNull == selected;

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: tokens.brandStrong.withValues(alpha: .18),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.searchable) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        autofocus: true,
                        textAlign: TextAlign.right,
                        onChanged: (value) => setState(() => _query = value),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'ابحث بالاسم أو الكود…',
                          fillColor: tokens.sunken,
                          prefixIcon: const Icon(LucideIcons.search, size: 16),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${visible.length} نتيجة',
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.line),
          ],
          Flexible(
            child: visible.isEmpty
                ? SizedBox(
                    height: 64,
                    child: Center(
                      child: Text(
                        'لا توجد نتائج مطابقة',
                        style: TextStyle(color: tokens.muted, fontSize: 12.5),
                      ),
                    ),
                  )
                : Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: visible.length > 7,
                    child: ListView.separated(
                      controller: _scrollController,
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(4),
                      itemCount: visible.length,
                      separatorBuilder: (_, index) => pinned && index == 0
                          ? Divider(height: 9, color: tokens.line)
                          : const SizedBox.shrink(),
                      itemBuilder: (context, index) {
                        final option = visible[index];
                        final isSelected = option == selected;
                        final subtitle = option.subtitle;
                        return InkWell(
                          onTap: () => widget.onSelected(option.value),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: _SelectMenu.rowHeight,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? tokens.wash : null,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                if (option.icon != null) ...[
                                  Icon(
                                    option.icon,
                                    size: 17,
                                    color: tokens.brandStrong,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        option.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: isSelected
                                              ? tokens.brandStrong
                                              : tokens.ink,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      if (subtitle != null &&
                                          subtitle.isNotEmpty &&
                                          subtitle != option.label)
                                        Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            height: 1.3,
                                            color: tokens.muted,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    LucideIcons.check,
                                    color: tokens.brand,
                                    size: 17,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
