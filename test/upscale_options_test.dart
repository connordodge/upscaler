import 'package:flutter_test/flutter_test.dart';
import 'package:upscaler/upscale/upscale_options.dart';

void main() {
  group('coverSize', () {
    test('wider than 16:9 matches height and overshoots width', () {
      expect(coverSize((width: 2752, height: 1536)), (
        width: 3870,
        height: 2160,
      ));
    });

    test('taller than 16:9 matches width and overshoots height', () {
      expect(coverSize((width: 1024, height: 1024)), (
        width: 3840,
        height: 3840,
      ));
    });

    test('exact 16:9 matches both sides', () {
      expect(coverSize((width: 1920, height: 1080)), frameTvSize);
    });

    test('larger images scale down', () {
      expect(coverSize((width: 7680, height: 4320)), frameTvSize);
    });
  });

  group('cropOffset', () {
    test('slides along the overshooting width', () {
      const covered = (width: 3870, height: 2160);
      expect(cropOffset(covered, 0), (x: 0, y: 0));
      expect(cropOffset(covered, 0.5), (x: 15, y: 0));
      expect(cropOffset(covered, 1), (x: 30, y: 0));
    });

    test('slides along the overshooting height', () {
      expect(cropOffset((width: 3840, height: 3840), 1), (x: 0, y: 1680));
    });
  });

  group('sipsSafeOffset', () {
    test('keeps ordinary offsets', () {
      const covered = (width: 3840, height: 2880);
      expect(sipsSafeOffset(covered, (x: 0, y: 360)), (x: 0, y: 360));
    });

    test('keeps the Y offset off the bottom edge', () {
      const covered = (width: 3840, height: 2880);
      expect(sipsSafeOffset(covered, (x: 0, y: 720)), (x: 0, y: 719));
    });

    test('does not pass an all-zero offset for a tall crop', () {
      const covered = (width: 3840, height: 2880);
      expect(sipsSafeOffset(covered, (x: 0, y: 0)), (x: 0, y: 1));
    });

    test('does not pass an all-zero offset for a wide crop', () {
      const covered = (width: 3870, height: 2160);
      expect(sipsSafeOffset(covered, (x: 0, y: 0)), (x: 1, y: 0));
    });

    test('allows the X offset to reach the right edge', () {
      const covered = (width: 3870, height: 2160);
      expect(sipsSafeOffset(covered, (x: 30, y: 0)), (x: 30, y: 0));
    });

    test('leaves exact 16:9 alone', () {
      expect(sipsSafeOffset(frameTvSize, (x: 0, y: 0)), (x: 0, y: 0));
    });
  });
}
