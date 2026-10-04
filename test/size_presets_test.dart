import 'package:flutter_test/flutter_test.dart';
import 'package:upscaler/upscale/size_presets.dart';
import 'package:upscaler/upscale/upscale_options.dart';

void main() {
  group('presetsFor', () {
    test('16:9 starts with the Frame TV 4K default, largest first', () {
      expect(presetsFor((w: 16, h: 9)).map(presetLabel), [
        '3840 × 2160 · Frame TV 4K',
        '2560 × 1440',
        '1920 × 1080',
      ]);
      expect(presetsFor((w: 16, h: 9)).first.size, defaultOutputSize);
    });

    for (final (ratio, sizes) in <(Ratio, List<String>)>[
      ((w: 3, h: 2), ['3840 × 2560', '2880 × 1920', '1920 × 1280']),
      ((w: 4, h: 3), ['3840 × 2880', '2880 × 2160', '1600 × 1200']),
      ((w: 1, h: 1), ['3840 × 3840', '2160 × 2160', '1080 × 1080']),
      ((w: 4, h: 5), ['3072 × 3840', '2160 × 2700', '1080 × 1350']),
      ((w: 2, h: 3), ['2560 × 3840', '1920 × 2880', '1280 × 1920']),
      ((w: 9, h: 16), ['2160 × 3840', '1440 × 2560', '1080 × 1920']),
    ]) {
      test('${ratio.w}:${ratio.h} lists its presets largest first', () {
        expect(presetsFor(ratio).map(presetLabel), sizes);
      });
    }

    test('a custom ratio has none', () {
      expect(presetsFor((w: 5, h: 6)), isEmpty);
    });
  });

  group('presetGroups', () {
    test('runs in chip order, each preset reducing to its ratio', () {
      expect(presetGroups.map((g) => ratioLabel(g.ratio)), [
        '16:9',
        '3:2',
        '4:3',
        '1:1',
        '4:5',
        '2:3',
        '9:16',
      ]);
      for (final (:ratio, :presets) in presetGroups) {
        for (final (:size, name: _) in presets) {
          expect(size.width * ratio.h, size.height * ratio.w, reason: '$size');
        }
      }
    });

    test('isPresetRatio is true only for the seven', () {
      expect(isPresetRatio((w: 4, h: 5)), isTrue);
      expect(isPresetRatio((w: 5, h: 4)), isFalse);
    });
  });
}
