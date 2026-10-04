typedef PixelSize = ({int width, int height});

/// Samsung Frame TV (4K) art size. Every output is exactly this.
const PixelSize frameTvSize = (width: 3840, height: 2160);

enum UpscaleMode {
  painting('Photo / Painting', model: 'realesrgan-x4plus'),
  illustration('Illustration', model: 'realesrgan-x4plus-anime'),
  plain('Plain Resize', model: null);

  const UpscaleMode(this.label, {required this.model});

  final String label;

  /// Real-ESRGAN model name, or null for a plain resize with no AI.
  final String? model;
}

/// Scales [size] to cover [frameTvSize]: one side matches exactly and the other overshoots
/// when the aspect ratio isn't 16:9 (e.g. 2752x1536 -> 3870x2160). The overshoot is cropped.
PixelSize coverSize(PixelSize size) {
  final scaleW = frameTvSize.width / size.width;
  final scaleH = frameTvSize.height / size.height;
  final scale = scaleW > scaleH ? scaleW : scaleH;
  final w = (size.width * scale).round();
  final h = (size.height * scale).round();
  return (
    width: w < frameTvSize.width ? frameTvSize.width : w,
    height: h < frameTvSize.height ? frameTvSize.height : h,
  );
}

/// Top-left of the [frameTvSize] crop inside [covered]. [position] runs from 0 (left/top) to
/// 1 (right/bottom) along whichever side overshoots.
({int x, int y}) cropOffset(PixelSize covered, double position) => (
  x: ((covered.width - frameTvSize.width) * position).round(),
  y: ((covered.height - frameTvSize.height) * position).round(),
);

/// Whether [mode] runs the AI model for an image of [size]. Images already at least as big as
/// the Frame TV size only need shrinking, so they skip the model. Mirrors the branch in
/// `Upscaler.upscale`.
bool needsAiUpscale(PixelSize size, UpscaleMode mode) =>
    mode.model != null && coverSize(size).width > size.width;

/// Nudges [offset] by 1px where `sips -c` (macOS 26) misbehaves: an all-zero `--cropOffset`
/// centers the crop instead of anchoring it top-left, and a Y offset that reaches the bottom edge
/// skips the crop entirely, leaving the image uncropped.
({int x, int y}) sipsSafeOffset(PixelSize covered, ({int x, int y}) offset) {
  final maxX = covered.width - frameTvSize.width;
  final maxY = covered.height - frameTvSize.height;
  var (:x, :y) = offset;
  if (maxY > 1 && y >= maxY) y = maxY - 1;
  if (x == 0 && y == 0) {
    if (maxY > 1) {
      y = 1;
    } else if (maxX > 0) {
      x = 1;
    }
  }
  return (x: x, y: y);
}
