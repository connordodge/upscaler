import 'package:flutter_test/flutter_test.dart';
import 'package:upscaler/status_text.dart';
import 'package:upscaler/upscale/upscale_options.dart';

void main() {
  const wide = (width: 2752, height: 1536);
  const tall = (width: 1024, height: 1024);
  const sample = (width: 2048, height: 1536);
  const exact = (width: 1920, height: 1080);

  group('cropInfo', () {
    test('wide images slide along x', () {
      expect(cropInfo(wide, 1), (axis: 'x', px: 30));
    });

    test('tall images slide along y', () {
      expect(cropInfo(tall, 1), (axis: 'y', px: 1680));
    });

    test('is null for exact 16:9', () {
      expect(cropInfo(exact, 0.5), isNull);
      expect(cropInfo((width: 7680, height: 4320), 0.5), isNull);
    });
  });

  group('fileSummary', () {
    test('includes the crop for a 4:3 image at the default position', () {
      expect(
        fileSummary(name: 'temple-garden.jpg', size: sample, position: 0.5),
        'temple-garden.jpg  2048×1536  →  3840×2160  ·  crop y 360',
      );
    });

    test('follows the drag position', () {
      expect(
        fileSummary(name: 'a.png', size: sample, position: 0),
        'a.png  2048×1536  →  3840×2160  ·  crop y 0',
      );
    });

    test('omits the crop for exact 16:9', () {
      expect(
        fileSummary(name: 'tv.png', size: exact, position: 0.5),
        'tv.png  1920×1080  →  3840×2160',
      );
    });
  });

  group('statusHint', () {
    String hint({
      StageView view = .crop,
      bool needsCrop = true,
      bool running = false,
      bool usesAi = true,
      double? progress,
      bool done = false,
      bool failed = false,
    }) => statusHint(
      view: view,
      needsCrop: needsCrop,
      running: running,
      usesAi: usesAi,
      progress: progress,
      done: done,
      failed: failed,
    );

    test('crop view hints', () {
      expect(hint(), 'Drag frame to reposition');
      expect(hint(needsCrop: false), 'No crop needed');
    });

    test('preview view hint', () {
      expect(hint(view: .preview), 'Switch to Crop to adjust');
    });

    test('AI steps', () {
      expect(
        hint(running: true, progress: 0.62),
        'Step 1 of 2 · AI upscale, then resize and crop',
      );
      expect(
        hint(running: true, progress: null),
        'Step 2 of 2 · Resize and crop',
      );
    });

    test('plain wording when no AI runs', () {
      expect(
        hint(running: true, usesAi: false, progress: null),
        'Resizing and cropping',
      );
    });

    test('done only shows in the preview view', () {
      expect(hint(view: .preview, done: true), 'Done');
      expect(hint(done: true), 'Drag frame to reposition');
    });

    test('failure wins over everything', () {
      expect(hint(failed: true, done: true, running: true), 'Failed');
    });
  });

  test('progressPercent', () {
    expect(progressPercent(0.624), '62%');
    expect(progressPercent(1), '100%');
    expect(progressPercent(null), isNull);
  });

  test('busyPillLabel', () {
    expect(busyPillLabel(usesAi: true), 'AI upscaling on your Mac\'s GPU');
    expect(busyPillLabel(usesAi: false), 'Resizing and cropping');
  });

  group('needsAiUpscale', () {
    test('false for plain mode', () {
      expect(needsAiUpscale(sample, .plain), isFalse);
    });

    test('true when the image is smaller than the cover size', () {
      expect(needsAiUpscale(sample, .painting), isTrue);
      expect(needsAiUpscale(sample, .illustration), isTrue);
    });

    test('false for images already large enough', () {
      expect(needsAiUpscale((width: 7680, height: 4320), .painting), isFalse);
    });
  });
}
