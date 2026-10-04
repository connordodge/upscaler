import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:upscaler/upscale/upscale_options.dart';
import 'package:upscaler/upscale/upscaler.dart';

/// Runs the real bundled Real-ESRGAN binary from inside the app. Needs a sample image:
/// flutter test integration_test -d macos --dart-define=SAMPLE=/path/to/image.jpg
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const sample = String.fromEnvironment('SAMPLE');

  for (final outputSize in [defaultOutputSize, (width: 1000, height: 1500)]) {
    final (:width, :height) = outputSize;
    for (final mode in [UpscaleMode.painting, UpscaleMode.plain]) {
      testWidgets('${mode.name} upscale makes exact $width × $height art', (
        tester,
      ) async {
        final dir = await Directory.systemTemp.createTemp('upscaler_test');
        addTearDown(() => dir.delete(recursive: true));
        final input = File(sample)
            .copySync('${dir.path}/${sample.split('/').last}')
            .path;
        final size = await Upscaler.readSize(input);
        final progress = <double?>[];

        final output = await Upscaler.upscale(
          input: input,
          size: size,
          outputSize: outputSize,
          mode: mode,
          cropPosition: 1,
          onProgress: progress.add,
        );

        expect(output, Upscaler.outputPathFor(input, outputSize));
        expect(output, endsWith('_${width}x$height.${output.split('.').last}'));
        expect(await Upscaler.readSize(output), outputSize);
        expect(progress.last, 1);
      }, skip: sample.isEmpty);
    }
  }
}
