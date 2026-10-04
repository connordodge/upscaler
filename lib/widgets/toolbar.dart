import 'package:flutter/material.dart';

import '../status_text.dart';
import '../theme.dart';
import '../upscale/upscale_options.dart';
import 'controls.dart';

const _methodLabels = {
  UpscaleMode.painting: 'AI · Photo',
  UpscaleMode.illustration: 'AI · Illustration',
  UpscaleMode.plain: 'Plain',
};

/// Top bar: Open…, upscale method, Crop/Preview view and the Upscale button. While [running] a 3px
/// accent line along the bottom edge tracks [progress] (pulsing full-width when it's null).
class Toolbar extends StatelessWidget {
  const Toolbar({
    super.key,
    required this.mode,
    required this.view,
    required this.running,
    required this.progress,
    required this.onOpen,
    required this.onModeChanged,
    required this.onViewChanged,
    required this.onUpscale,
  });

  final UpscaleMode mode;
  final StageView view;
  final bool running;
  final double? progress;

  /// Null while [running].
  final VoidCallback? onOpen;
  final ValueChanged<UpscaleMode>? onModeChanged;

  /// Null until an image is loaded.
  final ValueChanged<StageView>? onViewChanged;
  final VoidCallback? onUpscale;

  @override
  Widget build(BuildContext context) {
    final percent = progressPercent(progress);
    return Stack(
      fit: .passthrough,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const .symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: Dr.bar,
            border: Border(bottom: BorderSide(color: Dr.divider)),
          ),
          child: Wrap(
            alignment: .spaceBetween,
            crossAxisAlignment: .center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: .min,
                spacing: 12,
                children: [
                  Image.asset(
                    'assets/app_icon.png',
                    width: 28,
                    height: 28,
                    filterQuality: .medium,
                    semanticLabel: 'Upscaler',
                  ),
                  DrButton(
                    icon: Icons.folder_open,
                    label: const Text('Open…'),
                    onPressed: onOpen,
                  ),
                ],
              ),
              SegmentedControl<UpscaleMode>(
                label: 'Upscale method',
                items: [
                  for (final m in UpscaleMode.values)
                    SegmentItem(value: m, label: _methodLabels[m]!),
                ],
                selected: mode,
                onChanged: onModeChanged,
              ),
              Row(
                mainAxisSize: .min,
                spacing: 10,
                children: [
                  SegmentedControl<StageView>(
                    label: 'View',
                    items: const [
                      SegmentItem(
                        value: StageView.crop,
                        label: 'Crop',
                        icon: Icons.crop,
                      ),
                      SegmentItem(
                        value: StageView.preview,
                        label: 'Preview',
                        icon: Icons.tv,
                      ),
                    ],
                    selected: view,
                    onChanged: onViewChanged,
                  ),
                  DrButton(
                    kind: .primary,
                    icon: running ? null : Icons.auto_awesome,
                    busy: running,
                    minWidth: running ? 150 : 0,
                    horizontalPadding: 18,
                    fontWeight: .w600,
                    onPressed: onUpscale,
                    label: running
                        ? Text.rich(
                            TextSpan(
                              text: 'Upscaling…',
                              children: [
                                if (percent != null)
                                  TextSpan(
                                    text: '  $percent',
                                    style: Dr.monoStyle(
                                      14,
                                      .w500,
                                      Dr.text,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : const Text('Upscale'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (running)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 3,
            child: _ProgressLine(progress: progress),
          ),
      ],
    );
  }
}

class _ProgressLine extends StatefulWidget {
  const _ProgressLine({required this.progress});

  final double? progress;

  @override
  State<_ProgressLine> createState() => _ProgressLineState();
}

class _ProgressLineState extends State<_ProgressLine>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_ProgressLine old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.progress == null) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    const line = ColoredBox(color: Dr.accent);
    if (progress == null) {
      return FadeTransition(
        key: const ValueKey('progress-line'),
        opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
        child: line,
      );
    }
    return Align(
      key: const ValueKey('progress-line'),
      alignment: .centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress.clamp(0, 1),
        heightFactor: 1,
        child: line,
      ),
    );
  }
}
