import 'package:flutter_test/flutter_test.dart';
import 'package:upscaler/status_text.dart';
import 'package:upscaler/upscale/upscale_options.dart';

void main() {
  const wide = (width: 2752, height: 1536);
  const tall = (width: 1024, height: 1024);
  const sample = (width: 2048, height: 1536);
  const exact = (width: 1920, height: 1080);
  const output = defaultOutputSize;
  const portrait = (width: 1000, height: 1500);

  group('cropInfo', () {
    test('wide images slide along x', () {
      expect(cropInfo(wide, output, 1), (axis: 'x', px: 30));
    });

    test('tall images slide along y', () {
      expect(cropInfo(tall, output, 1), (axis: 'y', px: 1680));
    });

    test('is null for exact 16:9', () {
      expect(cropInfo(exact, output, 0.5), isNull);
      expect(cropInfo((width: 7680, height: 4320), output, 0.5), isNull);
    });

    test('follows a non-16:9 Output Size', () {
      expect(cropInfo((width: 100, height: 200), portrait, 1), (
        axis: 'y',
        px: 500,
      ));
      expect(cropInfo(sample, portrait, 0), (axis: 'x', px: 0));
      expect(cropInfo((width: 2000, height: 1500), portrait, 1), (
        axis: 'x',
        px: 1000,
      ));
    });

    test('is null when the image matches the Output Size ratio exactly', () {
      expect(cropInfo((width: 200, height: 300), portrait, 0.5), isNull);
      expect(cropInfo((width: 4000, height: 6000), portrait, 0.5), isNull);
    });
  });

  group('fileSummary', () {
    test('includes the crop for a 4:3 image at the default position', () {
      expect(
        fileSummary(
          name: 'temple-garden.jpg',
          size: sample,
          outputSize: output,
          position: 0.5,
        ),
        'temple-garden.jpg  2048×1536  →  3840×2160  ·  crop y 360',
      );
    });

    test('follows the drag position', () {
      expect(
        fileSummary(
          name: 'a.png',
          size: sample,
          outputSize: output,
          position: 0,
        ),
        'a.png  2048×1536  →  3840×2160  ·  crop y 0',
      );
    });

    test('omits the crop for exact 16:9', () {
      expect(
        fileSummary(
          name: 'tv.png',
          size: exact,
          outputSize: output,
          position: 0.5,
        ),
        'tv.png  1920×1080  →  3840×2160',
      );
    });

    test('shows a non-16:9 Output Size', () {
      expect(
        fileSummary(
          name: 'a.png',
          size: (width: 100, height: 200),
          outputSize: portrait,
          position: 0.5,
        ),
        'a.png  100×200  →  1000×1500  ·  crop y 250',
      );
      expect(
        fileSummary(
          name: 'b.png',
          size: (width: 200, height: 300),
          outputSize: portrait,
          position: 0.5,
        ),
        'b.png  200×300  →  1000×1500',
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

  test('emptyStatusHint', () {
    expect(emptyStatusHint(output), 'Output 3840×2160');
    expect(emptyStatusHint(portrait), 'Output 1000×1500');
  });

  test('Output Size wording', () {
    expect(
      emptyStateHint(portrait),
      'PNG, JPEG or WebP. It becomes exact 1000 × 1500 art.',
    );
    expect(previewCaption(output), 'Output · 3840 × 2160');
    expect(previewCaption(portrait), 'Output · 1000 × 1500');
    expect(doneDetail(portrait), '1000 × 1500 · next to the original');
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
      expect(needsAiUpscale(sample, output, .plain), isFalse);
    });

    test('true when the image is smaller than the cover size', () {
      expect(needsAiUpscale(sample, output, .painting), isTrue);
      expect(needsAiUpscale(sample, output, .illustration), isTrue);
    });

    test('false for images already large enough', () {
      expect(
        needsAiUpscale((width: 7680, height: 4320), output, .painting),
        isFalse,
      );
      // Too small for 3840×2160 but already covers 1000×1500.
      expect(needsAiUpscale(sample, portrait, .painting), isFalse);
    });
  });
}
