import 'package:flutter_test/flutter_test.dart';
import 'package:upscaler/upscale/upscale_options.dart';
import 'package:upscaler/upscale/upscaler.dart';

const _portrait = (width: 1000, height: 1500);

void main() {
  group('coverSize', () {
    test('taller than the Output Size matches width and overshoots height', () {
      // The Spec example: 100 × 200 → 1000 × 1500 is scaled to 1000 × 2000 before the crop.
      expect(coverSize((width: 100, height: 200), _portrait), (
        width: 1000,
        height: 2000,
      ));
    });

    test('wider than 16:9 matches height and overshoots width', () {
      expect(coverSize((width: 2752, height: 1536), defaultOutputSize), (
        width: 3870,
        height: 2160,
      ));
    });

    test('taller than 16:9 matches width and overshoots height', () {
      expect(coverSize((width: 1024, height: 1024), defaultOutputSize), (
        width: 3840,
        height: 3840,
      ));
    });

    test('exact 16:9 matches both sides', () {
      expect(
        coverSize((width: 1920, height: 1080), defaultOutputSize),
        defaultOutputSize,
      );
    });

    test('larger images scale down', () {
      expect(
        coverSize((width: 7680, height: 4320), defaultOutputSize),
        defaultOutputSize,
      );
    });
  });

  group('cropOffset', () {
    test('slides along the overshooting width', () {
      const covered = (width: 3870, height: 2160);
      expect(cropOffset(covered, defaultOutputSize, 0), (x: 0, y: 0));
      expect(cropOffset(covered, defaultOutputSize, 0.5), (x: 15, y: 0));
      expect(cropOffset(covered, defaultOutputSize, 1), (x: 30, y: 0));
    });

    test('slides along the overshooting height', () {
      expect(
        cropOffset((width: 3840, height: 3840), defaultOutputSize, 1),
        (x: 0, y: 1680),
      );
    });

    test('cuts the Output Size out of a non-16:9 cover', () {
      const covered = (width: 1000, height: 2000);
      expect(cropOffset(covered, _portrait, 0), (x: 0, y: 0));
      expect(cropOffset(covered, _portrait, 0.5), (x: 0, y: 250));
      expect(cropOffset(covered, _portrait, 1), (x: 0, y: 500));
    });
  });

  group('sipsSafeOffset', () {
    test('keeps ordinary offsets', () {
      const covered = (width: 3840, height: 2880);
      expect(sipsSafeOffset(covered, defaultOutputSize, (x: 0, y: 360)), (
        x: 0,
        y: 360,
      ));
    });

    test('keeps the Y offset off the bottom edge', () {
      const covered = (width: 3840, height: 2880);
      expect(sipsSafeOffset(covered, defaultOutputSize, (x: 0, y: 720)), (
        x: 0,
        y: 719,
      ));
    });

    test('does not pass an all-zero offset for a tall crop', () {
      const covered = (width: 3840, height: 2880);
      expect(sipsSafeOffset(covered, defaultOutputSize, (x: 0, y: 0)), (
        x: 0,
        y: 1,
      ));
    });

    test('does not pass an all-zero offset for a wide crop', () {
      const covered = (width: 3870, height: 2160);
      expect(sipsSafeOffset(covered, defaultOutputSize, (x: 0, y: 0)), (
        x: 1,
        y: 0,
      ));
    });

    test('allows the X offset to reach the right edge', () {
      const covered = (width: 3870, height: 2160);
      expect(sipsSafeOffset(covered, defaultOutputSize, (x: 30, y: 0)), (
        x: 30,
        y: 0,
      ));
    });

    test('leaves exact 16:9 alone', () {
      expect(
        sipsSafeOffset(defaultOutputSize, defaultOutputSize, (x: 0, y: 0)),
        (x: 0, y: 0),
      );
    });

    test('keeps a non-16:9 Y offset off the bottom edge', () {
      const covered = (width: 1000, height: 2000);
      expect(sipsSafeOffset(covered, _portrait, (x: 0, y: 500)), (
        x: 0,
        y: 499,
      ));
      expect(sipsSafeOffset(covered, _portrait, (x: 0, y: 0)), (x: 0, y: 1));
    });

    test('does not pass an all-zero offset for a wide non-16:9 crop', () {
      const covered = (width: 1500, height: 1500);
      expect(sipsSafeOffset(covered, _portrait, (x: 0, y: 0)), (x: 1, y: 0));
    });

    test('leaves an exact Output Size alone', () {
      expect(sipsSafeOffset(_portrait, _portrait, (x: 0, y: 0)), (
        x: 0,
        y: 0,
      ));
    });
  });

  group('outputPathFor', () {
    test('names the file after the Output Size', () {
      expect(
        Upscaler.outputPathFor('/photos/garden.png', defaultOutputSize),
        '/photos/garden_3840x2160.png',
      );
      expect(
        Upscaler.outputPathFor('/photos/garden.png', _portrait),
        '/photos/garden_1000x1500.png',
      );
    });

    test('saves JPEG inputs as jpg and everything else as png', () {
      expect(
        Upscaler.outputPathFor('/photos/a.JPEG', _portrait),
        '/photos/a_1000x1500.jpg',
      );
      expect(
        Upscaler.outputPathFor('/photos/a.jpg', _portrait),
        '/photos/a_1000x1500.jpg',
      );
      expect(
        Upscaler.outputPathFor('/photos/a.webp', _portrait),
        '/photos/a_1000x1500.png',
      );
    });
  });
}
