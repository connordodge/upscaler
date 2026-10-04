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

  for (final mode in [UpscaleMode.painting, UpscaleMode.plain]) {
    testWidgets('${mode.name} upscale makes exact Frame TV art', (
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
        mode: mode,
        cropPosition: 1,
        onProgress: progress.add,
      );

      expect(output, Upscaler.outputPathFor(input));
      expect(await Upscaler.readSize(output), frameTvSize);
      expect(progress.last, 1);
    }, skip: sample.isEmpty);
  }
}
