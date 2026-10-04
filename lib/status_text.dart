import 'upscale/upscale_options.dart';

/// Which view fills the stage once an image is loaded.
enum StageView { crop, preview }

/// `{W}×{H}`, as in the status bar.
String _compact(PixelSize size) => '${size.width}×${size.height}';

/// `{W} × {H}`, as in the stage copy.
String _spaced(PixelSize size) => '${size.width} × ${size.height}';

const noImageStatus = 'No image';

/// Right side of the status bar when no image is loaded: `Output {W}×{H}`.
String emptyStatusHint(OutputSize outputSize) =>
    'Output ${_compact(outputSize)}';

/// Drop zone line under `Drop an image to start`.
String emptyStateHint(OutputSize outputSize) =>
    'PNG, JPEG or WebP. It becomes exact ${_spaced(outputSize)} art.';

/// Caption under the Preview bezel: `Output · {W} × {H}`.
String previewCaption(OutputSize outputSize) =>
    'Output · ${_spaced(outputSize)}';

/// Second line of the Done card: `{W} × {H} · next to the original`.
String doneDetail(OutputSize outputSize) =>
    '${_spaced(outputSize)} · next to the original';

/// Which side the crop slides along and where the window starts in output pixels, or null when
/// the image already has the Output Size's Aspect Ratio and nothing is cropped.
({String axis, int px})? cropInfo(
  PixelSize size,
  OutputSize outputSize,
  double position,
) {
  final covered = coverSize(size, outputSize);
  if (covered == outputSize) return null;
  final offset = cropOffset(covered, outputSize, position);
  return covered.width > outputSize.width
      ? (axis: 'x', px: offset.x)
      : (axis: 'y', px: offset.y);
}

/// Left side of the status bar: `{file}  {w}×{h}  →  {W}×{H}  ·  crop {x|y} {px}`.
String fileSummary({
  required String name,
  required PixelSize size,
  required OutputSize outputSize,
  required double position,
}) {
  final base = '$name  ${_compact(size)}  →  ${_compact(outputSize)}';
  return switch (cropInfo(size, outputSize, position)) {
    (:final axis, :final px) => '$base  ·  crop $axis $px',
    null => base,
  };
}

/// Right side of the status bar for a loaded image. A failure or a running upscale takes
/// priority; otherwise it's a hint for the current view.
String statusHint({
  required StageView view,
  required bool needsCrop,
  bool running = false,
  bool usesAi = false,
  double? progress,
  bool done = false,
  bool failed = false,
}) {
  if (failed) return 'Failed';
  if (running) {
    if (!usesAi) return 'Resizing and cropping';
    return progress == null
        ? 'Step 2 of 2 · Resize and crop'
        : 'Step 1 of 2 · AI upscale, then resize and crop';
  }
  if (done && view == .preview) return 'Done';
  return switch (view) {
    .crop => needsCrop ? 'Drag frame to reposition' : 'No crop needed',
    .preview => 'Switch to Crop to adjust',
  };
}

/// Text inside the pill that covers the crop view while upscaling.
String busyPillLabel({required bool usesAi}) =>
    usesAi ? 'AI upscaling on your Mac\'s GPU' : 'Resizing and cropping';

/// Upscale button label while running: `Upscaling…  62%`, or without a percent when [progress]
/// can't be reported.
String? progressPercent(double? progress) =>
    progress == null ? null : '${(progress * 100).round().clamp(0, 100)}%';
