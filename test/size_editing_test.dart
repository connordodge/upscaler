import 'package:flutter_test/flutter_test.dart';
import 'package:upscaler/upscale/size_editing.dart';
import 'package:upscaler/upscale/size_presets.dart';
import 'package:upscaler/upscale/upscale_options.dart';

void main() {
  group('parseSide', () {
    test('accepts whole numbers from 256 to 8192 inclusive', () {
      expect(parseSide('256'), 256);
      expect(parseSide('1000'), 1000);
      expect(parseSide('8192'), 8192);
    });

    test('rejects sides outside 256–8192', () {
      expect(parseSide('255'), isNull);
      expect(parseSide('8193'), isNull);
      expect(parseSide('0'), isNull);
    });

    test('rejects anything but a whole number', () {
      for (final text in [
        '',
        ' ',
        'abc',
        '12a4',
        '1000.5',
        '1000.0',
        '1e3',
        '-1000',
        '+1000',
        '0x400',
        '1 000',
        '1,000',
        '99999999999999999999999',
      ]) {
        expect(parseSide(text), isNull, reason: '"$text"');
      }
    });
  });

  group('lockedSize', () {
    test('a width follows the ratio, rounding halves away from zero', () {
      // 1000 × 9 / 16 = 562.5.
      expect(lockedSize((w: 16, h: 9), .width, 1000), (
        width: 1000,
        height: 563,
      ));
      expect(lockedSize((w: 16, h: 9), .width, 1920), (
        width: 1920,
        height: 1080,
      ));
    });

    test('a height follows the ratio too', () {
      // 1000 × 16 / 9 = 1777.78; 1000 × 2 / 3 = 666.67; 1001 × 4 / 5 = 800.8.
      expect(lockedSize((w: 16, h: 9), .height, 1000), (
        width: 1778,
        height: 1000,
      ));
      expect(lockedSize((w: 2, h: 3), .height, 1000), (
        width: 667,
        height: 1000,
      ));
      expect(lockedSize((w: 4, h: 5), .height, 1001), (
        width: 801,
        height: 1001,
      ));
      // A custom ratio: 2900 × 24 / 29 = 2400.
      expect(lockedSize((w: 24, h: 29), .height, 2900), (
        width: 2400,
        height: 2900,
      ));
    });

    test('is null when the other side lands outside 256–8192', () {
      // 9:16 at H 400 → W 225; 16:9 at W 8000 → H 4500 is fine, at H 5000 → W 8889.
      expect(lockedSize((w: 9, h: 16), .height, 400), isNull);
      expect(lockedSize((w: 16, h: 9), .height, 5000), isNull);
      expect(lockedSize((w: 16, h: 9), .width, 8000), isNotNull);
    });

    test('accepts the other side landing exactly on 256 or 8192', () {
      expect(lockedSize((w: 1, h: 2), .height, 512), (width: 256, height: 512));
      expect(lockedSize((w: 1, h: 2), .height, 510), isNull);
      expect(lockedSize((w: 1, h: 32), .width, 256), (
        width: 256,
        height: 8192,
      ));
      expect(lockedSize((w: 1, h: 32), .width, 257), isNull);
    });
  });

  group('typedEdit', () {
    OutputEdit? edit(
      Side side,
      String text, {
      OutputSize size = (width: 3840, height: 2160),
      Ratio ratio = (w: 16, h: 9),
      bool locked = true,
    }) => typedEdit(
      size: size,
      ratio: ratio,
      locked: locked,
      side: side,
      text: text,
    );

    test('locked: the other side follows and the ratio stays', () {
      expect(edit(.width, '1000'), (
        size: (width: 1000, height: 563),
        ratio: (w: 16, h: 9),
      ));
    });

    test('unlocked: only that side changes and the ratio becomes W:H', () {
      expect(
        edit(.height, '2900', size: (width: 2400, height: 2160), locked: false),
        (
          size: (width: 2400, height: 2900),
          ratio: (w: 24, h: 29),
        ),
      );
      expect(
        edit(.width, '1728', size: (width: 2400, height: 2160), locked: false),
        (
          size: (width: 1728, height: 2160),
          ratio: (w: 4, h: 5),
        ),
      );
    });

    test('invalid text applies nothing, locked or not', () {
      for (final locked in [true, false]) {
        for (final text in ['', 'abc', '1000.5', '255', '8193']) {
          expect(edit(.width, text, locked: locked), isNull, reason: text);
          expect(edit(.height, text, locked: locked), isNull, reason: text);
        }
      }
    });

    test(
      'locked: a side pushing the other outside 256–8192 applies nothing',
      () {
        // 16:9 at H 5000 → W 8889; at W 400 → H 225.
        expect(edit(.height, '5000'), isNull);
        expect(edit(.width, '400'), isNull);
        // Unlocked, the other side stays as it is.
        expect(edit(.height, '5000', locked: false), (
          size: (width: 3840, height: 5000),
          ratio: (w: 96, h: 125),
        ));
      },
    );

    test('the value already in use changes nothing', () {
      // Recalculating W from H 563 would give 1001.
      const rounded = (width: 1000, height: 563);
      expect(edit(.height, '563', size: rounded), (
        size: rounded,
        ratio: (w: 16, h: 9),
      ));
      // Unlocked, the ratio stays rather than becoming 1000:563.
      expect(edit(.width, '1000', size: rounded, locked: false), (
        size: rounded,
        ratio: (w: 16, h: 9),
      ));
    });
  });

  group('reducedRatio', () {
    test('reduces a preset size to its chip ratio', () {
      expect(reducedRatio((width: 3840, height: 2160)), (w: 16, h: 9));
      expect(reducedRatio((width: 1080, height: 1350)), (w: 4, h: 5));
      expect(isPresetRatio(reducedRatio((width: 1080, height: 1350))), isTrue);
    });

    test('anything else is a Custom ratio', () {
      expect(reducedRatio((width: 2400, height: 2900)), (w: 24, h: 29));
      expect(isPresetRatio(reducedRatio((width: 2400, height: 2900))), isFalse);
      // A rounded locked size no longer reduces to its locked ratio.
      expect(reducedRatio((width: 1000, height: 563)), (w: 1000, h: 563));
      expect(reducedRatio((width: 8192, height: 8191)), (w: 8192, h: 8191));
    });
  });
}
