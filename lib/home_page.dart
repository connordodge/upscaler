import 'dart:developer';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'crop_picker.dart';
import 'image_view.dart';
import 'status_text.dart';
import 'theme.dart';
import 'upscale/size_editing.dart';
import 'upscale/size_presets.dart';
import 'upscale/upscale_options.dart';
import 'upscale/upscaler.dart';
import 'widgets/output_bar.dart';
import 'widgets/stage_parts.dart';
import 'widgets/toolbar.dart';

const _imageExtensions = ['png', 'jpg', 'jpeg', 'webp'];

typedef PickImage = Future<String?> Function();
typedef ReadSize = Future<PixelSize> Function(String path);
typedef RunUpscale = Future<String> Function({
  required String input,
  required PixelSize size,
  required OutputSize outputSize,
  required UpscaleMode mode,
  required double cropPosition,
  required void Function(double? progress) onProgress,
});

Future<String?> _pickWithDialog() async {
  final file = await openFile(
    acceptedTypeGroups: [
      const XTypeGroup(label: 'Images', extensions: _imageExtensions),
    ],
  );
  return file?.path;
}

void _reveal(String path) => Process.run('open', ['-R', path]);
void _open(String path) => Process.run('open', [path]);

/// The seams default to the real file dialog, `sips`/Real-ESRGAN pipeline and file decoding; widget
/// tests swap them out.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.initialOutputSize = defaultOutputSize,
    this.initialRatio = defaultRatio,
    this.initialRatioLocked = true,
    this.pickImage = _pickWithDialog,
    this.readSize = Upscaler.readSize,
    this.upscale = Upscaler.upscale,
    this.imageBuilder = fileImageBuilder,
    this.revealInFinder = _reveal,
    this.openFile = _open,
  });

  /// The Output Size, Aspect Ratio and Ratio Lock the page starts with. The page owns them from
  /// then on. [initialRatio] is reduced and isn't derived from [initialOutputSize]: a locked edit
  /// can round the size off its ratio.
  final OutputSize initialOutputSize;
  final Ratio initialRatio;
  final bool initialRatioLocked;
  final PickImage pickImage;
  final ReadSize readSize;
  final RunUpscale upscale;
  final ImageBuilder imageBuilder;
  final void Function(String path) revealInFinder;
  final void Function(String path) openFile;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Every saved image is exactly this; the crop, preview, copy and upscale all read it from here.
  /// It, [_ratio] and [_ratioLocked] only change through [_applyOutput].
  late OutputSize _outputSize = widget.initialOutputSize;
  late Ratio _ratio = widget.initialRatio;
  late bool _ratioLocked = widget.initialRatioLocked;

  /// Fields whose typed text was rejected. Nothing of it is applied; while any is invalid, Upscale
  /// is disabled and the status bar asks for a fix.
  Set<Side> _invalid = {};
  String? _input;
  PixelSize? _inputSize;
  double _cropPosition = 0.5;
  UpscaleMode _mode = .painting;
  StageView _view = .crop;
  bool _running = false;
  double? _progress;
  String? _output;
  ({String title, String message})? _error;

  Future<void> _pick() async {
    final path = await widget.pickImage();
    if (path != null) await _load(path);
  }

  Future<void> _load(String path) async {
    if (!_imageExtensions.contains(path.split('.').last.toLowerCase())) {
      setState(
        () => _error = (
          title: 'Couldn\'t open that image',
          message: 'Not a PNG, JPEG or WebP image.',
        ),
      );
      return;
    }
    try {
      final size = await widget.readSize(path);
      // A file edited on disk under the same path shouldn't show a stale decode.
      await FileImage(File(path)).evict();
      if (!mounted) return;
      setState(() {
        _input = path;
        _inputSize = size;
        _cropPosition = 0.5;
        _view = .crop;
        _output = null;
        _error = null;
      });
    } catch (e, st) {
      log('Failed to read $path', error: e, stackTrace: st);
      if (!mounted) return;
      setState(
        () => _error = (title: 'Couldn\'t open that image', message: '$e'),
      );
    }
  }

  /// Moving the crop or changing the method makes a finished result stale.
  void _changeCrop(double position) => setState(() {
    _cropPosition = position;
    _output = null;
    _error = null;
  });

  void _changeMode(UpscaleMode mode) => setState(() {
    _mode = mode;
    _output = null;
    _error = null;
  });

  /// The one path for Output Size, Aspect Ratio and Ratio Lock changes. A new Output Size reshapes
  /// the crop, so it recenters and any result or error goes stale.
  void _applyOutput({OutputSize? size, Ratio? ratio, bool? locked}) =>
      setState(() {
        if (size != null && size != _outputSize) {
          _outputSize = size;
          _cropPosition = 0.5;
          _output = null;
          _error = null;
        }
        if (ratio != null) _ratio = ratio;
        if (locked != null) _ratioLocked = locked;
      });

  /// A ratio chip jumps to that ratio's largest Size Preset, replacing both fields.
  void _pickRatio(Ratio ratio) =>
      _pickPreset(ratio, presetsFor(ratio).first.size);

  void _pickPreset(Ratio ratio, OutputSize size) {
    setState(() => _invalid = {});
    _applyOutput(size: size, ratio: ratio);
  }

  /// Closing the lock in `Custom` keeps the exact current W:H; otherwise only the lock changes.
  void _changeLock(bool locked) => _applyOutput(
    locked: locked,
    ratio: locked && !isPresetRatio(_ratio) ? reducedRatio(_outputSize) : null,
  );

  /// Applies text typed into [side], or marks the field invalid and applies nothing.
  void _typeSize(Side side, String text) {
    final edit = typedEdit(
      size: _outputSize,
      ratio: _ratio,
      locked: _ratioLocked,
      side: side,
      text: text,
    );
    if (edit == null) {
      setState(() => _invalid = {..._invalid, side});
      return;
    }
    // A locked edit sets both sides, so it replaces the other field too.
    setState(
      () => _invalid = _ratioLocked ? {} : ({..._invalid}..remove(side)),
    );
    _applyOutput(size: edit.size, ratio: edit.ratio);
  }

  void _revertSize(Side side) =>
      setState(() => _invalid = {..._invalid}..remove(side));

  Future<void> _upscale() async {
    // The click that got here first applied any typed text; if that was invalid, don't start.
    if (_invalid.isNotEmpty) return;
    setState(() {
      _running = true;
      _progress = 0;
      _output = null;
      _error = null;
    });
    try {
      final output = await widget.upscale(
        input: _input!,
        size: _inputSize!,
        outputSize: _outputSize,
        mode: _mode,
        cropPosition: _cropPosition,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      // The output path is reused across runs, so drop any cached decode of the previous file.
      await FileImage(File(output)).evict();
      if (!mounted) return;
      setState(() {
        _output = output;
        _view = .preview;
      });
    } catch (e, st) {
      log('Upscale failed for $_input', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _error = (title: 'Upscale failed', message: '$e'));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = _input;
    final inputSize = _inputSize;
    final loaded = input != null && inputSize != null;
    final outputSize = _outputSize;
    final needsCrop = loaded && coverSize(inputSize, outputSize) != outputSize;
    final usesAi = loaded && needsAiUpscale(inputSize, outputSize, _mode);
    final output = _output;
    final error = _error;
    final showDone = output != null && _view == .preview && error == null;
    final fixHint = fixSizeHint(_invalid);

    final ResultCard? card = switch ((error, output)) {
      (final error?, _) => ResultCard.error(
        title: error.title,
        detail: error.message,
      ),
      (_, final output?) when showDone => ResultCard.success(
        fileName: output.split('/').last,
        outputSize: outputSize,
        onReveal: () => widget.revealInFinder(output),
        onOpen: () => widget.openFile(output),
      ),
      _ => null,
    };

    return Scaffold(
      body: DropTarget(
        enable: !_running,
        onDragDone: (details) {
          if (details.files.isNotEmpty) _load(details.files.first.path);
        },
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Toolbar(
              mode: _mode,
              view: _view,
              running: _running,
              progress: _progress,
              onOpen: _running ? null : _pick,
              onModeChanged: _running ? null : _changeMode,
              onViewChanged: loaded ? (v) => setState(() => _view = v) : null,
              onUpscale: loaded && !_running && _invalid.isEmpty
                  ? _upscale
                  : null,
            ),
            OutputBar(
              outputSize: outputSize,
              ratio: _ratio,
              locked: _ratioLocked,
              enabled: !_running,
              invalid: _invalid,
              onRatioPicked: _pickRatio,
              onPresetPicked: _pickPreset,
              onLockChanged: _changeLock,
              onSizeTyped: _typeSize,
              onSizeReverted: _revertSize,
            ),
            Expanded(
              child: !loaded
                  ? _Stage(
                      color: Dr.background,
                      card: card,
                      child: DropZone(outputSize: outputSize, onChoose: _pick),
                    )
                  : switch (_view) {
                      .crop => _Stage(
                        color: Dr.background,
                        card: card,
                        child: CropPicker(
                          path: input,
                          size: inputSize,
                          outputSize: outputSize,
                          position: _cropPosition,
                          onChanged: _running ? null : _changeCrop,
                          imageBuilder: widget.imageBuilder,
                          busy: _running,
                          busyLabel: busyPillLabel(usesAi: usesAi),
                        ),
                      ),
                      .preview => _PreviewStage(
                        outputSize: outputSize,
                        card: card,
                        caption: previewCaption(outputSize),
                        child: Stack(
                          fit: .expand,
                          children: [
                            // The source preview stays underneath so decoding the full-size
                            // output doesn't flash black.
                            CroppedSource(
                              path: input,
                              size: inputSize,
                              outputSize: outputSize,
                              position: _cropPosition,
                              imageBuilder: widget.imageBuilder,
                            ),
                            if (output != null)
                              KeyedSubtree(
                                key: ValueKey('output:$output'),
                                child: widget.imageBuilder(output),
                              ),
                          ],
                        ),
                      ),
                    },
            ),
            if (!loaded)
              StatusBar(
                left: noImageStatus,
                right: fixHint ?? emptyStatusHint(outputSize),
              )
            else
              StatusBar(
                left: fileSummary(
                  name: input.split('/').last,
                  size: inputSize,
                  outputSize: outputSize,
                  position: _cropPosition,
                ),
                right:
                    fixHint ??
                    statusHint(
                      view: _view,
                      needsCrop: needsCrop,
                      running: _running,
                      usesAi: usesAi,
                      progress: _progress,
                      done: output != null,
                      failed: error != null,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Edge-to-edge stage with 32px padding and [child] centered, plus an optional [card] below.
class _Stage extends StatelessWidget {
  const _Stage({required this.color, required this.child, required this.card});

  final Color color;
  final Widget child;
  final Widget? card;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Padding(
        padding: const .all(32),
        child: Column(
          children: [
            Expanded(child: Center(child: child)),
            if (card != null) ...[
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: doneMaxWidth),
                child: card,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Preview stage: [child] in a bezel of [outputSize]'s shape, with [caption] below or, when there
/// is one, a result [card]. The bezel takes whatever height the caption or card leaves, so tall
/// Output Sizes and short windows shrink it rather than overflow.
class _PreviewStage extends StatelessWidget {
  const _PreviewStage({
    required this.outputSize,
    required this.child,
    required this.card,
    required this.caption,
  });

  final OutputSize outputSize;
  final Widget child;
  final Widget? card;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    return ColoredBox(
      color: Dr.stage,
      child: Padding(
        padding: const .all(32),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth
                .clamp(0, card == null ? previewMaxWidth : doneMaxWidth)
                .toDouble();
            return Center(
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: .min,
                  spacing: card == null ? 18 : 20,
                  children: [
                    Flexible(
                      child: Bezel(outputSize: outputSize, child: child),
                    ),
                    if (card != null)
                      SizedBox(width: width, child: card)
                    else
                      Text(
                        caption,
                        style: Dr.monoStyle(12),
                        textAlign: .center,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
