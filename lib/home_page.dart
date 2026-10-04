import 'dart:developer';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'crop_picker.dart';
import 'upscale/upscale_options.dart';
import 'upscale/upscaler.dart';

const _imageExtensions = ['png', 'jpg', 'jpeg', 'webp'];
const _frameTvLabel = '3840 × 2160';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _input;
  PixelSize? _inputSize;
  double _cropPosition = 0.5;
  UpscaleMode _mode = .painting;
  bool _running = false;
  double? _progress;
  String? _output;
  String? _error;

  Future<void> _pick() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Images', extensions: _imageExtensions),
      ],
    );
    if (file != null) await _load(file.path);
  }

  Future<void> _load(String path) async {
    if (!_imageExtensions.contains(path.split('.').last.toLowerCase())) {
      setState(() => _error = 'Not a PNG, JPEG or WebP image.');
      return;
    }
    try {
      final size = await Upscaler.readSize(path);
      setState(() {
        _input = path;
        _inputSize = size;
        _cropPosition = 0.5;
        _output = null;
        _error = null;
      });
    } catch (e, st) {
      log('Failed to read $path', error: e, stackTrace: st);
      setState(() => _error = 'Couldn\'t read that image: $e');
    }
  }

  Future<void> _upscale() async {
    setState(() {
      _running = true;
      _progress = 0;
      _output = null;
      _error = null;
    });
    try {
      final output = await Upscaler.upscale(
        input: _input!,
        size: _inputSize!,
        mode: _mode,
        cropPosition: _cropPosition,
        onProgress: (p) => setState(() => _progress = p),
      );
      setState(() => _output = output);
    } catch (e, st) {
      log('Upscale failed for $_input', error: e, stackTrace: st);
      setState(() => _error = 'Upscale failed: $e');
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final input = _input;
    final inputSize = _inputSize;

    return Scaffold(
      body: DropTarget(
        enable: !_running,
        onDragDone: (details) {
          if (details.files.isNotEmpty) _load(details.files.first.path);
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const .all(24),
              child: Column(
                crossAxisAlignment: .stretch,
                spacing: 20,
                children: [
                  _ImageCard(
                    path: input,
                    size: inputSize,
                    cropPosition: _cropPosition,
                    onCropChanged: _running
                        ? null
                        : (p) => setState(() => _cropPosition = p),
                    onChoose: _running ? null : _pick,
                  ),
                  _ModePicker(
                    mode: _mode,
                    onChanged: _running
                        ? null
                        : (m) => setState(() => _mode = m),
                  ),
                  FilledButton.icon(
                    onPressed: input == null || _running ? null : _upscale,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Make Frame TV Art ($_frameTvLabel)'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                  if (_running) LinearProgressIndicator(value: _progress),
                  if (_error case final error?)
                    SelectableText(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_output case final output?) _Result(path: output),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.path,
    required this.size,
    required this.cropPosition,
    required this.onCropChanged,
    required this.onChoose,
  });

  final String? path;
  final PixelSize? size;
  final double cropPosition;
  final ValueChanged<double>? onCropChanged;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = this.path;
    final size = this.size;
    final covered = size == null ? null : coverSize(size);
    final needsCrop = covered != null && covered != frameTvSize;

    return Card.outlined(
      clipBehavior: .antiAlias,
      child: Padding(
        padding: const .all(16),
        child: Column(
          spacing: 12,
          children: [
            SizedBox(
              height: 360,
              child: path == null || size == null
                  ? Column(
                      mainAxisAlignment: .center,
                      spacing: 8,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        Text(
                          'Drop an image here',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    )
                  : Center(
                      child: CropPicker(
                        path: path,
                        size: size,
                        position: cropPosition,
                        onChanged: onCropChanged,
                      ),
                    ),
            ),
            if (path != null && size != null) ...[
              Text(
                path.split('/').last,
                style: theme.textTheme.titleSmall,
                overflow: .ellipsis,
              ),
              Text(
                needsCrop
                    ? '${size.width} × ${size.height}  →  $_frameTvLabel. '
                          'Drag the box to choose what to keep.'
                    : '${size.width} × ${size.height}  →  $_frameTvLabel',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            OutlinedButton.icon(
              onPressed: onChoose,
              icon: const Icon(Icons.folder_open),
              label: Text(path == null ? 'Choose Image…' : 'Choose Another…'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.mode, required this.onChanged});

  final UpscaleMode mode;
  final ValueChanged<UpscaleMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        SegmentedButton<UpscaleMode>(
          segments: [
            for (final m in UpscaleMode.values)
              ButtonSegment(value: m, label: Text(m.label)),
          ],
          selected: {mode},
          onSelectionChanged: onChanged == null
              ? null
              : (s) => onChanged(s.single),
        ),
        Text(
          switch (mode) {
            .painting => 'AI upscale. Sharpest result; may smooth fine texture like brush strokes.',
            .illustration => 'AI upscale tuned for flat art, sprites and UI.',
            .plain => 'Simple high-quality resize. Looks exactly like the original, slightly softer.',
          },
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: .center,
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      child: Padding(
        padding: const .all(16),
        child: Column(
          spacing: 12,
          children: [
            Row(
              spacing: 8,
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                Expanded(child: SelectableText('Saved $path')),
              ],
            ),
            Row(
              mainAxisAlignment: .end,
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => Process.run('open', ['-R', path]),
                  child: const Text('Show in Finder'),
                ),
                FilledButton.tonal(
                  onPressed: () => Process.run('open', [path]),
                  child: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
