import 'package:flutter/material.dart';

import 'image_view.dart';
import 'theme.dart';
import 'upscale/upscale_options.dart';

/// Shows the image with a draggable window in [outputSize]'s shape marking what ends up in the
/// saved image. The image is shown at its own Aspect Ratio; the window spans the matching side and
/// slides along the side that overshoots. [position] is 0 (left/top) to 1 (right/bottom), as in
/// [cropOffset].
///
/// While [busy] the image is dimmed, the guides are hidden and a pill with [busyLabel] covers it.
class CropPicker extends StatelessWidget {
  const CropPicker({
    super.key,
    required this.path,
    required this.size,
    required this.outputSize,
    required this.position,
    required this.onChanged,
    this.imageBuilder = fileImageBuilder,
    this.busy = false,
    this.busyLabel = '',
  });

  final String path;
  final PixelSize size;
  final OutputSize outputSize;
  final double position;
  final ValueChanged<double>? onChanged;
  final ImageBuilder imageBuilder;
  final bool busy;
  final String busyLabel;

  @override
  Widget build(BuildContext context) {
    final covered = coverSize(size, outputSize);
    final horizontal = covered.width > outputSize.width;
    final vertical = covered.height > outputSize.height;
    // Fraction of the overshooting side the crop window covers.
    final windowFraction = horizontal
        ? outputSize.width / covered.width
        : outputSize.height / covered.height;

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
            onHorizontalDragUpdate: horizontal && onChanged != null
                ? (d) => drag(d.delta.dx, constraints.maxWidth)
                : null,
            onVerticalDragUpdate: vertical && onChanged != null
                ? (d) => drag(d.delta.dy, constraints.maxHeight)
                : null,
            child: ClipRect(
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: .expand,
                  children: [
                    imageBuilder(path),
                    CustomPaint(
                      key: const ValueKey('crop-overlay'),
                      painter: CropWindowPainter(
                        horizontal: horizontal,
                        windowFraction: windowFraction,
                        position: position,
                        busy: busy,
                      ),
                    ),
                    if (busy) Center(child: _BusyPill(label: busyLabel)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BusyPill extends StatelessWidget {
  const _BusyPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Dr.bar.withValues(alpha: 0.92),
        borderRadius: .circular(999),
        border: .all(color: Dr.controlLine),
      ),
      child: Row(
        mainAxisSize: .min,
        spacing: 10,
        children: [
          const Icon(Icons.auto_awesome, size: 16, color: Dr.text),
          Flexible(
            child: Text(label, style: Dr.sansStyle(14, .w500)),
          ),
        ],
      ),
    );
  }
}

/// Paints the shaded outside area, outline, 3×3 guides and corner ticks of the crop window.
class CropWindowPainter extends CustomPainter {
  CropWindowPainter({
    required this.horizontal,
    required this.windowFraction,
    required this.position,
    this.busy = false,
  });

  final bool horizontal;
  final double windowFraction;
  final double position;
  final bool busy;

  /// Where the window sits inside [size].
  Rect window(Size size) {
    if (horizontal) {
      final w = size.width * windowFraction;
      return Rect.fromLTWH((size.width - w) * position, 0, w, size.height);
    }
    final h = size.height * windowFraction;
    return Rect.fromLTWH(0, (size.height - h) * position, size.width, h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final window = this.window(size);
    if (busy) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Dr.background.withValues(alpha: 0.55),
      );
    }
    final outside = Path.combine(
      .difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRect(window),
    );
    canvas.drawPath(
      outside,
      Paint()..color = Dr.background.withValues(alpha: busy ? 0.6 : 0.8),
    );

    final line = Paint()
      ..style = .stroke
      ..strokeWidth = 1;
    // Outline sits inside the window's edge, like a CSS border.
    canvas.drawRect(
      window.deflate(0.5),
      line..color = Colors.white.withValues(alpha: busy ? 0.5 : 0.85),
    );
    if (busy) return;

    line.color = Colors.white.withValues(alpha: 0.22);
    for (var i = 1; i < 3; i++) {
      final x = window.left + window.width * i / 3;
      final y = window.top + window.height * i / 3;
      canvas.drawLine(Offset(x, window.top), Offset(x, window.bottom), line);
      canvas.drawLine(Offset(window.left, y), Offset(window.right, y), line);
    }

    // 22px L-shaped ticks, 3px thick, hugging the corners (1px outside the outline).
    const length = 22.0;
    const thick = 3.0;
    const out = 1.0;
    final tick = Paint()..color = Colors.white;
    for (final (cx, cy) in [
      (window.left - out, window.top - out),
      (window.right + out, window.top - out),
      (window.left - out, window.bottom + out),
      (window.right + out, window.bottom + out),
    ]) {
      final dx = cx < window.center.dx ? 1.0 : -1.0;
      final dy = cy < window.center.dy ? 1.0 : -1.0;
      canvas.drawRect(
        Rect.fromPoints(
          Offset(cx, cy),
          Offset(cx + dx * length, cy + dy * thick),
        ),
        tick,
      );
      canvas.drawRect(
        Rect.fromPoints(
          Offset(cx, cy),
          Offset(cx + dx * thick, cy + dy * length),
        ),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(CropWindowPainter old) =>
      old.horizontal != horizontal ||
      old.windowFraction != windowFraction ||
      old.position != position ||
      old.busy != busy;
}
