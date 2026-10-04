import 'dart:io';

import 'package:flutter/material.dart';

import 'upscale/upscale_options.dart';

/// Shows the image with a draggable 16:9 window marking what ends up on the Frame TV. The image
/// is shown at its own aspect ratio; the window spans the matching side and slides along the
/// side that overshoots. [position] is 0 (left/top) to 1 (right/bottom), as in [cropOffset].
class CropPicker extends StatelessWidget {
  const CropPicker({
    super.key,
    required this.path,
    required this.size,
    required this.position,
    required this.onChanged,
  });

  final String path;
  final PixelSize size;
  final double position;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final covered = coverSize(size);
    final horizontal = covered.width > frameTvSize.width;
    final vertical = covered.height > frameTvSize.height;
    // Fraction of the overshooting side the crop window covers.
    final windowFraction = horizontal
        ? frameTvSize.width / covered.width
        : frameTvSize.height / covered.height;

    void drag(double delta, double extent) {
      final travel = extent * (1 - windowFraction);
      if (travel > 0) onChanged?.call((position + delta / travel).clamp(0, 1));
    }

    return AspectRatio(
      aspectRatio: size.width / size.height,
      child: LayoutBuilder(
        builder: (context, constraints) => MouseRegion(
          cursor: onChanged == null || !(horizontal || vertical)
              ? MouseCursor.defer
              : horizontal
              ? SystemMouseCursors.resizeLeftRight
              : SystemMouseCursors.resizeUpDown,
          child: GestureDetector(
            onHorizontalDragUpdate: horizontal
                ? (d) => drag(d.delta.dx, constraints.maxWidth)
                : null,
            onVerticalDragUpdate: vertical
                ? (d) => drag(d.delta.dy, constraints.maxHeight)
                : null,
            child: Stack(
              fit: .expand,
              children: [
                Image.file(File(path), fit: .fill),
                CustomPaint(
                  painter: _CropWindowPainter(
                    horizontal: horizontal,
                    windowFraction: windowFraction,
                    position: position,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CropWindowPainter extends CustomPainter {
  _CropWindowPainter({
    required this.horizontal,
    required this.windowFraction,
    required this.position,
  });

  final bool horizontal;
  final double windowFraction;
  final double position;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect window;
    if (horizontal) {
      final w = size.width * windowFraction;
      window = Rect.fromLTWH((size.width - w) * position, 0, w, size.height);
    } else {
      final h = size.height * windowFraction;
      window = Rect.fromLTWH(0, (size.height - h) * position, size.width, h);
    }

    final outside = Path.combine(
      .difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRect(window),
    );
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    canvas.drawRect(
      window.deflate(1),
      Paint()
        ..style = .stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_CropWindowPainter old) =>
      old.horizontal != horizontal ||
      old.windowFraction != windowFraction ||
      old.position != position;
}
