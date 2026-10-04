import 'upscale/upscale_options.dart';

/// Which view fills the stage once an image is loaded.
enum StageView { crop, preview }

const _frameTvCompact = '3840×2160';

const noImageStatus = 'No image';
const emptyStatusHint = 'Output $_frameTvCompact';

/// Which side the crop slides along and where the window starts in output pixels, or null when
/// the image is already exactly 16:9 and nothing is cropped.
({String axis, int px})? cropInfo(PixelSize size, double position) {
  final covered = coverSize(size);
  if (covered == frameTvSize) return null;
  final offset = cropOffset(covered, position);
  return covered.width > frameTvSize.width
      ? (axis: 'x', px: offset.x)
      : (axis: 'y', px: offset.y);
}

/// Left side of the status bar: `{file}  {w}×{h}  →  3840×2160  ·  crop {x|y} {px}`.
String fileSummary({
  required String name,
  required PixelSize size,
  required double position,
}) {
  final base = '$name  ${size.width}×${size.height}  →  $_frameTvCompact';
  return switch (cropInfo(size, position)) {
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

/// Make button label while running: `Upscaling…  62%`, or without a percent when [progress]
/// can't be reported.
String? progressPercent(double? progress) =>
    progress == null ? null : '${(progress * 100).round().clamp(0, 100)}%';
