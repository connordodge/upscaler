import 'dart:developer';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'crop_picker.dart';
import 'image_view.dart';
import 'status_text.dart';
import 'theme.dart';
import 'upscale/upscale_options.dart';
import 'upscale/upscaler.dart';
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
    this.pickImage = _pickWithDialog,
    this.readSize = Upscaler.readSize,
    this.upscale = Upscaler.upscale,
    this.imageBuilder = fileImageBuilder,
    this.revealInFinder = _reveal,
    this.openFile = _open,
  });

  /// The Output Size the page starts with. The page owns it from then on.
  final OutputSize initialOutputSize;
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
  late final OutputSize _outputSize = widget.initialOutputSize;
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

  Future<void> _upscale() async {
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
              onUpscale: loaded && !_running ? _upscale : null,
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
                right: emptyStatusHint(outputSize),
              )
            else
              StatusBar(
                left: fileSummary(
                  name: input.split('/').last,
                  size: inputSize,
                  outputSize: outputSize,
                  position: _cropPosition,
                ),
                right: statusHint(
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
