import 'package:flutter/material.dart';

import '../theme.dart';

/// Disabled controls sit at this opacity.
const disabledOpacity = 0.45;

enum DrButtonKind { primary, secondary }

/// Darkroom button: accent-filled [DrButtonKind.primary] or bordered [DrButtonKind.secondary].
///
/// A null [onPressed] disables it: secondary buttons fade, primary buttons switch to the divider
/// fill with muted text (or [busyLabelColor] when [busy], where it reads as a status, not as
/// unavailable).
class DrButton extends StatelessWidget {
  const DrButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = .secondary,
    this.height = 44,
    this.fontSize = 14,
    this.fontWeight = .w500,
    this.horizontalPadding = 14,
    this.minWidth = 0,
    this.busy = false,
  });

  final Widget label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final DrButtonKind kind;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final double horizontalPadding;
  final double minWidth;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final primary = kind == .primary;
    final enabled = onPressed != null;
    final style = FilledButton.styleFrom(
      minimumSize: Size(minWidth, height),
      maximumSize: Size.fromHeight(height),
      padding: .symmetric(horizontal: horizontalPadding),
      tapTargetSize: .shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: .circular(8),
        side: primary ? .none : const BorderSide(color: Dr.controlLine),
      ),
      backgroundColor: primary ? Dr.accent : Dr.control,
      foregroundColor: primary ? Colors.white : Dr.text,
      disabledBackgroundColor: primary ? Dr.divider : Dr.control,
      disabledForegroundColor: busy ? Dr.text : Dr.textDisabled,
      textStyle: Dr.sansStyle(fontSize, fontWeight),
    );
    final button = FilledButton(
      onPressed: onPressed,
      style: style,
      child: Row(
        mainAxisSize: .min,
        mainAxisAlignment: .center,
        spacing: 8,
        children: [
          if (icon case final icon?) Icon(icon, size: 16),
          Flexible(child: label),
        ],
      ),
    );
    return !primary && !enabled
        ? Opacity(opacity: disabledOpacity, child: button)
        : button;
  }
}

class SegmentItem<T> {
  const SegmentItem({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Pill-shaped segmented control. A null [onChanged] disables it and fades it to 45%.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.label,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<SegmentItem<T>> items;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final track = Container(
      padding: const .all(3),
      decoration: BoxDecoration(
        color: Dr.control,
        borderRadius: .circular(10),
        border: .all(color: Dr.controlLine),
      ),
      child: Row(
        mainAxisSize: .min,
        spacing: 2,
        children: [
          for (final item in items)
            _Segment(
              item: item,
              selected: item.value == selected,
              onTap: onChanged == null ? null : () => onChanged(item.value),
            ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: label,
      child: onChanged == null
          ? Opacity(opacity: disabledOpacity, child: track)
          : track,
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SegmentItem<dynamic> item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Dr.textSecondary;
    final icon = item.icon;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      excludeSemantics: true,
      label: item.label,
      onTap: onTap,
      child: Material(
        color: selected ? Dr.selected : Colors.transparent,
        borderRadius: .circular(7),
        clipBehavior: .antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.white.withValues(alpha: 0.06),
          child: Container(
            height: 38,
            padding: .symmetric(horizontal: icon == null ? 14 : 12),
            alignment: .center,
            child: Row(
              mainAxisSize: .min,
              spacing: 6,
              children: [
                if (icon != null) Icon(icon, size: 15, color: color),
                Text(
                  item.label,
                  style: Dr.sansStyle(13, selected ? .w600 : .w500, color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
