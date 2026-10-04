import 'size_presets.dart';
import 'upscale_options.dart';

/// The smallest and largest typed Output Size side, in px.
const minSide = 256;
const maxSide = 8192;

final _digits = RegExp(r'^\d+$');

/// The typed [text] as a side length, or null unless it's a whole number from [minSide] to
/// [maxSide].
int? parseSide(String text) {
  // Digits only: int.tryParse would also take a sign or a `0x` prefix.
  if (!_digits.hasMatch(text)) return null;
  final side = int.tryParse(text);
  return side != null && _inRange(side) ? side : null;
}

/// One side of the Output Size, as typed into the `W` or `H` field.
enum Side {
  width,
  height;

  /// This side of [size].
  int of(OutputSize size) => this == width ? size.width : size.height;
}

/// The Output Size with [side] set to [value] and the other side following [ratio], rounded to a
/// whole pixel with `round()` (halves away from zero). Null when that other side falls outside
/// [minSide]–[maxSide].
OutputSize? lockedSize(Ratio ratio, Side side, int value) {
  final size = switch (side) {
    .width => (width: value, height: (value * ratio.h / ratio.w).round()),
    .height => (width: (value * ratio.w / ratio.h).round(), height: value),
  };
  return _inRange(size.width) && _inRange(size.height) ? size : null;
}

bool _inRange(int side) => side >= minSide && side <= maxSide;

/// An applied Output Size and the Aspect Ratio that goes with it.
typedef OutputEdit = ({OutputSize size, Ratio ratio});

/// What typing [text] into [side] makes of the current [size] and [ratio], or null when it's
/// invalid and nothing may be applied.
OutputEdit? typedEdit({
  required OutputSize size,
  required Ratio ratio,
  required bool locked,
  required Side side,
  required String text,
}) {
  final value = parseSide(text);
  if (value == null) return null;
  // Re-entering a rounded locked side mustn't recalculate the other one.
  if (value == side.of(size)) return (size: size, ratio: ratio);
  if (!locked) {
    final edited = switch (side) {
      .width => (width: value, height: size.height),
      .height => (width: size.width, height: value),
    };
    return (size: edited, ratio: reducedRatio(edited));
  }
  final edited = lockedSize(ratio, side, value);
  return edited == null ? null : (size: edited, ratio: ratio);
}

/// [size]'s exact W:H, reduced: one of the seven chip ratios, or `Custom` when [isPresetRatio] is
/// false.
Ratio reducedRatio(OutputSize size) {
  final d = size.width.gcd(size.height);
  return (w: size.width ~/ d, h: size.height ~/ d);
}
