typedef PixelSize = ({int width, int height});

/// The exact pixel width × height of every saved image.
typedef OutputSize = PixelSize;

/// The Output Size until the user picks another: the `Frame TV 4K` Size Preset.
const OutputSize defaultOutputSize = (width: 3840, height: 2160);

enum UpscaleMode {
  painting('Photo / Painting', model: 'realesrgan-x4plus'),
  illustration('Illustration', model: 'realesrgan-x4plus-anime'),
  plain('Plain Resize', model: null);

  const UpscaleMode(this.label, {required this.model});

  final String label;

  /// Real-ESRGAN model name, or null for a plain resize with no AI.
  final String? model;
}

/// Scales [size] to cover [outputSize]: one side matches exactly and the other overshoots when
/// the Aspect Ratios differ (e.g. 2752x1536 -> 3870x2160 for 3840x2160). The overshoot is cropped.
PixelSize coverSize(PixelSize size, OutputSize outputSize) {
  final scaleW = outputSize.width / size.width;
  final scaleH = outputSize.height / size.height;
  final scale = scaleW > scaleH ? scaleW : scaleH;
  final w = (size.width * scale).round();
  final h = (size.height * scale).round();
  return (
    width: w < outputSize.width ? outputSize.width : w,
    height: h < outputSize.height ? outputSize.height : h,
  );
}

/// Top-left of the [outputSize] crop inside [covered]. [position] runs from 0 (left/top) to 1
/// (right/bottom) along whichever side overshoots.
({int x, int y}) cropOffset(
  PixelSize covered,
  OutputSize outputSize,
  double position,
) => (
  x: ((covered.width - outputSize.width) * position).round(),
  y: ((covered.height - outputSize.height) * position).round(),
);

/// Whether [mode] runs the AI model for an image of [size]. Images that already cover
/// [outputSize] only need shrinking, so they skip the model. Mirrors the branch in
/// `Upscaler.upscale`.
bool needsAiUpscale(PixelSize size, OutputSize outputSize, UpscaleMode mode) =>
    mode.model != null && coverSize(size, outputSize).width > size.width;

/// Nudges [offset] by 1px where `sips -c` (macOS 26) misbehaves: an all-zero `--cropOffset`
/// centers the crop instead of anchoring it top-left, and a Y offset that reaches the bottom edge
/// skips the crop entirely, leaving the image uncropped.
({int x, int y}) sipsSafeOffset(
  PixelSize covered,
  OutputSize outputSize,
  ({int x, int y}) offset,
) {
  final maxX = covered.width - outputSize.width;
  final maxY = covered.height - outputSize.height;
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
