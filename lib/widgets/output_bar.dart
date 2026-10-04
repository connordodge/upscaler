import 'package:flutter/material.dart';

import '../theme.dart';
import '../upscale/size_editing.dart';
import '../upscale/size_presets.dart';
import '../upscale/upscale_options.dart';
import 'controls.dart';

/// Stable selectors for every Output bar control.
abstract final class OutputBarKeys {
  static const bar = ValueKey('output-bar');
  static ValueKey<String> ratio(Ratio ratio) =>
      ValueKey('ratio-${ratioLabel(ratio)}');
  static const custom = ValueKey('ratio-custom');
  static const presets = ValueKey('output-presets');
  static ValueKey<String> presetGroup(Ratio ratio) =>
      ValueKey('preset-group-${ratioLabel(ratio)}');
  static ValueKey<String> preset(OutputSize size) =>
      ValueKey('preset-${size.width}x${size.height}');
  static const width = ValueKey('output-width');
  static const lock = ValueKey('ratio-lock');
  static const height = ValueKey('output-height');

  /// The `256–8192 px` hint shown while a typed side is invalid.
  static const rangeHint = ValueKey('output-range-hint');

  /// The field for [side].
  static ValueKey<String> field(Side side) => switch (side) {
    .width => width,
    .height => height,
  };
}

/// The 52px bar under the toolbar: `OUTPUT`, the Aspect Ratio chips (plus a selected `Custom` chip
/// when [ratio] is none of the seven), the Presets menu, then `W [____] 🔒 [____] H px`.
///
/// Presentational: [HomePage] owns the values and applies every change. A false [enabled] (while
/// upscaling) disables every control.
///
/// The fields report typed text through [onSizeTyped] on Enter, on focus loss and on a click
/// anywhere outside the field, never per keystroke. A side in [invalid] keeps its typed text, a red
/// outline and the `256–8192 px` hint until the page clears it; Escape restores the field's last
/// valid value and reports [onSizeReverted].
class OutputBar extends StatefulWidget {
  const OutputBar({
    super.key,
    required this.outputSize,
    required this.ratio,
    required this.locked,
    required this.enabled,
    required this.onRatioPicked,
    required this.onPresetPicked,
    this.invalid = const {},
    this.onLockChanged,
    this.onSizeTyped,
    this.onSizeReverted,
  });

  final OutputSize outputSize;
  final Ratio ratio;

  /// Whether the Ratio Lock is closed.
  final bool locked;
  final bool enabled;
  final ValueChanged<Ratio> onRatioPicked;

  /// A Size Preset picked from the menu, with the ratio it is listed under.
  final void Function(Ratio ratio, OutputSize size) onPresetPicked;

  /// Sides whose typed text the page rejected. Those fields keep showing it.
  final Set<Side> invalid;

  /// Until these are given, the lock and fields only show the current state.
  final ValueChanged<bool>? onLockChanged;

  /// Text typed into [side]'s field, to apply or reject. Only called when there is something new
  /// to apply: text that differs from the current value, or any text in an invalid field.
  final void Function(Side side, String text)? onSizeTyped;

  /// Escape in [side]'s field restored its last valid value.
  final ValueChanged<Side>? onSizeReverted;

  @override
  State<OutputBar> createState() => _OutputBarState();
}

class _OutputBarState extends State<OutputBar> {
  late final _text = {
    for (final side in Side.values)
      side: TextEditingController(text: '${side.of(widget.outputSize)}'),
  };
  final _focus = {
    for (final side in Side.values)
      side: FocusNode(debugLabel: 'Output ${side.name}'),
  };

  @override
  void initState() {
    super.initState();
    for (final MapEntry(key: side, value: node) in _focus.entries) {
      node.addListener(() {
        if (!node.hasFocus) _commit(side);
      });
    }
  }

  @override
  void didUpdateWidget(OutputBar old) {
    super.didUpdateWidget(old);
    for (final side in Side.values) {
      // An invalid field keeps its typed text until it's fixed, replaced or reverted.
      if (widget.invalid.contains(side)) continue;
      // A focused field may hold text that isn't applied yet; it only follows a new Output Size
      // (or an error being cleared). Unfocused fields always show the value in use.
      final resync =
          !_focus[side]!.hasFocus ||
          old.outputSize != widget.outputSize ||
          old.invalid.contains(side);
      final value = '${side.of(widget.outputSize)}';
      if (resync && _text[side]!.text != value) _text[side]!.text = value;
    }
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Hands [side]'s typed text to the page, unless there's nothing new in it.
  void _commit(Side side) {
    final onSizeTyped = widget.onSizeTyped;
    if (!mounted || onSizeTyped == null || !widget.enabled) return;
    final text = _text[side]!.text;
    final unchanged = text == '${side.of(widget.outputSize)}';
    if (unchanged && !widget.invalid.contains(side)) return;
    onSizeTyped(side, text);
  }

  /// Escape: back to the last valid value, clearing any error.
  void _revert(Side side) {
    final controller = _text[side]!;
    final value = '${side.of(widget.outputSize)}';
    controller.value = TextEditingValue(
      text: value,
      selection: .collapsed(offset: value.length),
    );
    widget.onSizeReverted?.call(side);
  }

  Widget _field(Side side) => _SizeField(
    fieldKey: OutputBarKeys.field(side),
    side: side,
    controller: _text[side]!,
    focusNode: _focus[side]!,
    enabled: widget.enabled,
    invalid: widget.invalid.contains(side),
    editable: widget.onSizeTyped != null,
    onCommit: () => _commit(side),
    onRevert: () => _revert(side),
  );

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final onLockChanged = widget.onLockChanged;
    return Container(
      key: OutputBarKeys.bar,
      height: 52,
      padding: const .symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Dr.outputBar,
        border: Border(bottom: BorderSide(color: Dr.divider)),
      ),
      child: Row(
        spacing: 14,
        children: [
          Text(
            'OUTPUT',
            style: Dr.sansStyle(
              12,
              .w600,
              Dr.textMuted,
            ).copyWith(letterSpacing: 12 * 0.06),
          ),
          _Fade(
            enabled: enabled,
            child: _RatioChips(
              ratio: widget.ratio,
              onPicked: enabled ? widget.onRatioPicked : null,
            ),
          ),
          _Fade(
            enabled: enabled,
            child: _PresetsMenu(
              ratio: widget.ratio,
              outputSize: widget.outputSize,
              onPicked: enabled ? widget.onPresetPicked : null,
            ),
          ),
          _Fade(
            enabled: enabled,
            child: Row(
              mainAxisSize: .min,
              spacing: 6,
              children: [
                _field(.width),
                _LockButton(
                  locked: widget.locked,
                  onPressed: enabled
                      ? () => onLockChanged?.call(!widget.locked)
                      : null,
                ),
                _field(.height),
                Text('px', style: Dr.monoStyle(13)),
                if (widget.invalid.isNotEmpty)
                  Padding(
                    padding: const .only(left: 4),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        '$minSide–$maxSide px',
                        key: OutputBarKeys.rangeHint,
                        style: Dr.sansStyle(12, .w400, Dr.error),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      enabled ? child : Opacity(opacity: disabledOpacity, child: child);
}

/// The seven Aspect Ratio chips in a track, plus `Custom` (selected, not tappable) for any other
/// ratio. A null [onPicked] disables them.
class _RatioChips extends StatelessWidget {
  const _RatioChips({required this.ratio, required this.onPicked});

  final Ratio ratio;
  final ValueChanged<Ratio>? onPicked;

  @override
  Widget build(BuildContext context) {
    final onPicked = this.onPicked;
    return Semantics(
      container: true,
      label: 'Aspect Ratio',
      child: Container(
        padding: const .all(2),
        decoration: BoxDecoration(
          color: Dr.control,
          borderRadius: .circular(8),
          border: .all(color: Dr.controlLine),
        ),
        child: Row(
          mainAxisSize: .min,
          spacing: 2,
          children: [
            for (final (ratio: r, presets: _) in presetGroups)
              _Chip(
                key: OutputBarKeys.ratio(r),
                label: ratioLabel(r),
                selected: r == ratio,
                onTap: onPicked == null ? null : () => onPicked(r),
              ),
            if (!isPresetRatio(ratio))
              const _Chip(
                key: OutputBarKeys.custom,
                label: 'Custom',
                selected: true,
                onTap: null,
                tappable: false,
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.tappable = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  /// False for `Custom`, which only shows the current state.
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      height: 30,
      padding: const .symmetric(horizontal: 8),
      alignment: .center,
      child: Text(
        label,
        style: Dr.monoStyle(
          12,
          selected ? .w500 : .w400,
          selected ? Colors.white : Dr.textSecondary,
        ),
      ),
    );
    return Semantics(
      button: tappable,
      selected: selected,
      enabled: tappable ? onTap != null : null,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: Material(
        color: selected ? Dr.selected : Colors.transparent,
        borderRadius: .circular(6),
        clipBehavior: .antiAlias,
        child: tappable
            ? InkWell(
                onTap: onTap,
                hoverColor: Colors.white.withValues(alpha: 0.06),
                child: chip,
              )
            : chip,
      ),
    );
  }
}

/// `Presets ⌄`: the selected ratio's Size Presets, or every ratio's presets grouped by ratio when
/// [ratio] is custom. The preset matching [outputSize] is checked.
class _PresetsMenu extends StatelessWidget {
  const _PresetsMenu({
    required this.ratio,
    required this.outputSize,
    required this.onPicked,
  });

  final Ratio ratio;
  final OutputSize outputSize;
  final void Function(Ratio ratio, OutputSize size)? onPicked;

  @override
  Widget build(BuildContext context) {
    final onPicked = this.onPicked;
    final custom = !isPresetRatio(ratio);

    Widget item(Ratio ratio, SizePreset preset) {
      final checked = preset.size == outputSize;
      return Semantics(
        checked: checked,
        inMutuallyExclusiveGroup: true,
        child: MenuItemButton(
          key: OutputBarKeys.preset(preset.size),
          onPressed: onPicked == null
              ? null
              : () => onPicked(ratio, preset.size),
          trailingIcon: checked
              ? const Icon(Icons.check, size: 16, color: Dr.accentLight)
              : null,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(188, 34)),
            fixedSize: const WidgetStatePropertyAll(Size.fromHeight(34)),
            padding: const WidgetStatePropertyAll(.symmetric(horizontal: 10)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: .circular(6)),
            ),
            backgroundColor: WidgetStatePropertyAll(
              checked ? Dr.raised : Colors.transparent,
            ),
            foregroundColor: WidgetStatePropertyAll(
              checked ? Colors.white : Dr.text,
            ),
            overlayColor: WidgetStatePropertyAll(
              Colors.white.withValues(alpha: 0.06),
            ),
            textStyle: WidgetStatePropertyAll(Dr.monoStyle(13)),
          ),
          child: Text(presetLabel(preset)),
        ),
      );
    }

    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Dr.menu),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: 0.55),
        ),
        elevation: const WidgetStatePropertyAll(12),
        padding: const WidgetStatePropertyAll(.all(6)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: .circular(10),
            side: const BorderSide(color: Dr.controlLine),
          ),
        ),
      ),
      menuChildren: [
        if (custom)
          for (final (ratio: r, :presets) in presetGroups) ...[
            Padding(
              key: OutputBarKeys.presetGroup(r),
              padding: const .fromLTRB(10, 8, 10, 4),
              child: Text(
                ratioLabel(r),
                style: Dr.monoStyle(11, .w500, Dr.textMuted),
              ),
            ),
            for (final preset in presets) item(r, preset),
          ]
        else
          for (final preset in presetsFor(ratio)) item(ratio, preset),
      ],
      builder: (context, controller, _) {
        final open = controller.isOpen;
        return Semantics(
          button: true,
          expanded: open,
          child: FilledButton(
            key: OutputBarKeys.presets,
            onPressed: onPicked == null
                ? null
                : () => open ? controller.close() : controller.open(),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 34),
              maximumSize: const Size.fromHeight(34),
              padding: const .symmetric(horizontal: 10),
              tapTargetSize: .shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: .circular(8),
                side: const BorderSide(color: Dr.controlLine),
              ),
              backgroundColor: open ? Dr.selected : Dr.control,
              foregroundColor: open ? Colors.white : Dr.text,
              disabledBackgroundColor: Dr.control,
              disabledForegroundColor: Dr.text,
              textStyle: Dr.sansStyle(13, .w500),
            ),
            child: Row(
              mainAxisSize: .min,
              spacing: 6,
              children: [
                const Text('Presets'),
                Icon(
                  open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 14,
                  color: open ? Colors.white : Dr.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A 92px `W [____]` / `H [____]` field, outlined red while [invalid]. Read-only unless
/// [editable]. Enter, focus loss and a click outside call [onCommit]; Escape calls [onRevert].
class _SizeField extends StatelessWidget {
  const _SizeField({
    required this.fieldKey,
    required this.side,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.invalid,
    required this.editable,
    required this.onCommit,
    required this.onRevert,
  });

  final Key fieldKey;
  final Side side;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool invalid;
  final bool editable;
  final VoidCallback onCommit;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    final (prefix, label) = switch (side) {
      .width => ('W', 'Width'),
      .height => ('H', 'Height'),
    };
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, child) => Container(
        width: 92,
        height: 34,
        padding: const .symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Dr.background,
          borderRadius: .circular(7),
          border: invalid
              ? .all(color: Dr.error, width: 1.5)
              : .all(color: focusNode.hasFocus ? Dr.accent : Dr.controlLine),
        ),
        child: child,
      ),
      child: Row(
        spacing: 6,
        children: [
          ExcludeSemantics(child: Text(prefix, style: Dr.monoStyle(13))),
          Expanded(
            child: Actions(
              actions: {
                DismissIntent: CallbackAction<DismissIntent>(
                  onInvoke: (_) => editable ? onRevert() : null,
                ),
              },
              child: Semantics(
                label: label,
                validationResult: invalid ? .invalid : .none,
                child: TextField(
                  key: fieldKey,
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  readOnly: !editable,
                  onSubmitted: editable ? (_) => onCommit() : null,
                  // Apply as soon as a click elsewhere goes down, before that click lands, so
                  // clicking Upscale upscales what was just typed.
                  onTapOutside: (_) {
                    onCommit();
                    focusNode.unfocus();
                  },
                  keyboardType: TextInputType.number,
                  style: Dr.monoStyle(13, .w400, Dr.text),
                  decoration: const InputDecoration.collapsed(hintText: null),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Ratio Lock: a closed padlock when [locked], an open one otherwise.
class _LockButton extends StatelessWidget {
  const _LockButton({required this.locked, required this.onPressed});

  final bool locked;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = locked ? 'Ratio locked' : 'Ratio unlocked';
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        toggled: locked,
        enabled: onPressed != null,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: Material(
          key: OutputBarKeys.lock,
          color: locked ? Dr.raised : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: .circular(7),
            side: locked ? .none : const BorderSide(color: Dr.controlLine),
          ),
          clipBehavior: .antiAlias,
          child: InkWell(
            onTap: onPressed,
            hoverColor: Colors.white.withValues(alpha: 0.06),
            child: SizedBox.square(
              dimension: 34,
              child: Icon(
                locked ? Icons.lock_outline : Icons.lock_open_outlined,
                size: 16,
                color: locked ? Dr.text : Dr.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
