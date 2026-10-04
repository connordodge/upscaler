import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'upscale_options.dart';

/// Port of ~/code/scripts/upscale/upscale.sh: Real-ESRGAN 4x, a `sips` resize to cover the Frame
/// TV size, then a crop to exactly 3840x2160, keeping the original's color profile and saving
/// JPEGs at max quality.
class Upscaler {
  /// Real-ESRGAN is bundled at Upscaler.app/Contents/Resources/realesrgan.
  static final _resources =
      '${File(Platform.resolvedExecutable).parent.parent.path}/Resources/realesrgan';
  static final _progressPattern = RegExp(r'(\d+(?:\.\d+)?)%');

  static Future<PixelSize> readSize(String path) async {
    final out = await _run('sips', [
      '-g',
      'pixelWidth',
      '-g',
      'pixelHeight',
      path,
    ]);
    int value(String key) =>
        int.parse(RegExp('$key: (\\d+)').firstMatch(out)!.group(1)!);
    return (width: value('pixelWidth'), height: value('pixelHeight'));
  }

  static String outputPathFor(String input) {
    final dot = input.lastIndexOf('.');
    final base = input.substring(0, dot);
    final ext = input.substring(dot + 1).toLowerCase();
    return '${base}_4k.${_isJpeg(ext) ? 'jpg' : 'png'}';
  }

  /// Upscales [input] to exactly [frameTvSize] and returns the output path. [cropPosition] picks
  /// what's kept along the side that overshoots (see [cropOffset]). [onProgress] gets 0..1, or
  /// null while the current step can't report progress.
  static Future<String> upscale({
    required String input,
    required PixelSize size,
    required UpscaleMode mode,
    required double cropPosition,
    required void Function(double? progress) onProgress,
  }) async {
    final output = outputPathFor(input);
    final covered = coverSize(size);
    final offset = cropOffset(covered, cropPosition);
    final tmp = await Directory.systemTemp.createTemp('upscaler');
    try {
      final mid = '${tmp.path}/mid.png';
      final model = mode.model;
      // Images already bigger than the Frame TV size only need shrinking, not AI.
      if (model == null || covered.width <= size.width) {
        onProgress(null);
        await _run('sips', ['-s', 'format', 'png', input, '--out', mid]);
      } else {
        await _realEsrgan(
          input: input,
          output: mid,
          model: model,
          onProgress: (p) => onProgress(p * 0.9),
        );
      }

      onProgress(null);
      // Embed the original's color profile into the lossless intermediate; embedding into the
      // final JPEG would re-save it at sips' default (lower) quality.
      final icc = '${tmp.path}/profile.icc';
      try {
        await _run('sips', ['--extractProfile', icc, input]);
        if (await File(icc).exists() && await File(icc).length() > 0) {
          await _run('sips', ['--embedProfile', icc, mid]);
        }
      } on ProcessException catch (e) {
        log('No color profile carried over from $input', error: e);
      }

      // Resize losslessly first, then crop and encode once so a JPEG is only compressed once.
      final resized = '${tmp.path}/resized.png';
      await _run('sips', [
        '-z',
        '${covered.height}',
        '${covered.width}',
        mid,
        '--out',
        resized,
      ]);
      final format = _isJpeg(output.split('.').last) ? 'jpeg' : 'png';
      await _run('sips', [
        '-c',
        '${frameTvSize.height}',
        '${frameTvSize.width}',
        '--cropOffset',
        '${offset.y}',
        '${offset.x}',
        '-s',
        'format',
        format,
        '-s',
        'formatOptions',
        'best',
        resized,
        '--out',
        output,
      ]);
      onProgress(1);
      return output;
    } finally {
      await tmp.delete(recursive: true);
    }
  }

  static Future<void> _realEsrgan({
    required String input,
    required String output,
    required String model,
    required void Function(double progress) onProgress,
  }) async {
    final process = await Process.start('$_resources/realesrgan-ncnn-vulkan', [
      '-i',
      input,
      '-o',
      output,
      '-n',
      model,
      '-s',
      '4',
      '-m',
      '$_resources/models',
      '-f',
      'png',
    ]);
    final stderr = StringBuffer();
    // Real-ESRGAN prints tile progress like "25.00%" on stderr.
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) {
          stderr.writeln(line);
          final match = _progressPattern.firstMatch(line);
          if (match != null) onProgress(double.parse(match.group(1)!) / 100);
        });
    await process.stdout.drain<void>();
    final code = await process.exitCode;
    await stderrDone;
    if (code != 0 || !await File(output).exists()) {
      throw ProcessException(
        'realesrgan-ncnn-vulkan',
        [input],
        stderr.toString().trim(),
        code,
      );
    }
  }

  static Future<String> _run(String exe, List<String> args) async {
    final result = await Process.run(exe, args);
    if (result.exitCode != 0) {
      throw ProcessException(
        exe,
        args,
        '${result.stderr}'.trim(),
        result.exitCode,
      );
    }
    return '${result.stdout}';
  }

  static bool _isJpeg(String ext) => ext == 'jpg' || ext == 'jpeg';
}
