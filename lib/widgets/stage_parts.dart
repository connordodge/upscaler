import 'dart:math';
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../image_view.dart';
import '../status_text.dart';
import '../theme.dart';
import '../upscale/upscale_options.dart';
import 'controls.dart';

/// Widest the bezel gets before upscaling, and while the result card is shown.
const previewMaxWidth = 820.0;
const doneMaxWidth = 780.0;

/// Dashed, rounded drop zone shown before an image is loaded.
class DropZone extends StatelessWidget {
  const DropZone({super.key, required this.outputSize, required this.onChoose});

  final OutputSize outputSize;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: CustomPaint(
          painter: _DashedBorderPainter(),
          child: Padding(
            padding: const .all(24),
            child: Column(
              mainAxisAlignment: .center,
              spacing: 14,
              children: [
                const Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: Dr.textDisabled,
                ),
                Text(
                  'Drop an image to start',
                  style: Dr.sansStyle(22, .w600),
                  textAlign: .center,
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Text(
                    emptyStateHint(outputSize),
                    style: Dr.sansStyle(14, .w400, Dr.textMuted),
                    textAlign: .center,
                  ),
                ),
                DrButton(
                  kind: .primary,
                  icon: Icons.folder_open,
                  label: const Text('Choose Image…'),
                  fontWeight: .w600,
                  horizontalPadding: 18,
                  onPressed: onChoose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  static const _dash = 6.0;
  static const _gap = 5.0;
  static const _width = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_width / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const .circular(16)));
    final paint = Paint()
      ..style = .stroke
      ..strokeWidth = _width
      ..color = Dr.selected;
    for (final PathMetric metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(
          metric.extractPath(d, (d + _dash).clamp(0, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => false;
}

/// A TV bezel around a [child] in [outputSize]'s shape, as large as fits its constraints in both
/// directions, so tall and extreme Output Sizes shrink instead of overflowing.
class Bezel extends StatelessWidget {
  const Bezel({super.key, required this.outputSize, required this.child});

  static const _padding = 10.0;

  final OutputSize outputSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = outputSize.width / outputSize.height;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Largest screen of this shape inside the constraints, less the bezel itself.
        final maxWidth = max(0.0, constraints.maxWidth - _padding * 2);
        final maxHeight = max(0.0, constraints.maxHeight - _padding * 2);
        final width = min(maxWidth, maxHeight * aspectRatio);
        return Container(
          padding: const .all(_padding),
          decoration: BoxDecoration(
            color: Dr.bezel,
            borderRadius: .circular(3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x8C000000),
                offset: Offset(0, 30),
                blurRadius: 60,
              ),
            ],
          ),
          foregroundDecoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x0FFFFFFF))),
          ),
          child: SizedBox(
            width: width,
            height: width / aspectRatio,
            child: ClipRect(
              child: ColoredBox(color: Colors.black, child: child),
            ),
          ),
        );
      },
    );
  }
}

/// The part of the source image that survives the crop, scaled to fill a parent in
/// [outputSize]'s shape: the image is sized to cover the Output Size and shifted by [cropOffset].
class CroppedSource extends StatelessWidget {
  const CroppedSource({
    super.key,
    required this.path,
    required this.size,
    required this.outputSize,
    required this.position,
    this.imageBuilder = fileImageBuilder,
  });

  final String path;
  final PixelSize size;
  final OutputSize outputSize;
  final double position;
  final ImageBuilder imageBuilder;

  @override
  Widget build(BuildContext context) {
    final covered = coverSize(size, outputSize);
    final offset = cropOffset(covered, outputSize, position);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / outputSize.width;
        return Stack(
          clipBehavior: .hardEdge,
          children: [
            Positioned(
              left: -offset.x * scale,
              top: -offset.y * scale,
              width: covered.width * scale,
              height: covered.height * scale,
              child: imageBuilder(path),
            ),
          ],
        );
      },
    );
  }
}

/// Success or error card under the preview/crop stage.
class ResultCard extends StatelessWidget {
  ResultCard.success({
    super.key,
    required String fileName,
    required OutputSize outputSize,
    required VoidCallback this.onReveal,
    required VoidCallback this.onOpen,
  }) : title = 'Saved $fileName',
       detail = doneDetail(outputSize),
       isError = false;

  const ResultCard.error({super.key, required this.title, required this.detail})
    : isError = true,
      onReveal = null,
      onOpen = null;

  final String title;
  final String detail;
  final bool isError;
  final VoidCallback? onReveal;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: Dr.bar,
        borderRadius: .circular(12),
        border: .all(color: Dr.divider),
      ),
      child: Wrap(
        alignment: .spaceBetween,
        crossAxisAlignment: .center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: .min,
            crossAxisAlignment: isError ? .start : .center,
            spacing: 12,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                size: 22,
                color: isError ? Dr.error : Dr.success,
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 2,
                  children: [
                    Text(
                      title,
                      style: Dr.sansStyle(15, .w600),
                      overflow: .ellipsis,
                    ),
                    if (isError)
                      SelectableText(detail, style: Dr.monoStyle(12))
                    else
                      Text(detail, style: Dr.monoStyle(12)),
                  ],
                ),
              ),
            ],
          ),
          if (!isError)
            Row(
              mainAxisSize: .min,
              spacing: 8,
              children: [
                DrButton(
                  height: 40,
                  fontSize: 13,
                  label: const Text('Show in Finder'),
                  onPressed: onReveal,
                ),
                DrButton(
                  height: 40,
                  fontSize: 13,
                  label: const Text('Open'),
                  onPressed: onOpen,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 36px footer: file summary on the left, a hint for the current state on the right.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    final style = Dr.monoStyle(12);
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const .symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Dr.bar,
        border: Border(top: BorderSide(color: Dr.divider)),
      ),
      child: Wrap(
        alignment: .spaceBetween,
        crossAxisAlignment: .center,
        spacing: 16,
        runSpacing: 4,
        children: [
          Text(left, key: const ValueKey('status-left'), style: style),
          Text(right, key: const ValueKey('status-right'), style: style),
        ],
      ),
    );
  }
}
