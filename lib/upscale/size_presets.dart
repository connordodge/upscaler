import 'upscale_options.dart';

/// An Aspect Ratio W:H, always held reduced (`16:9`, never `32:18`).
typedef Ratio = ({int w, int h});

/// A named, ready-made Output Size for an Aspect Ratio.
typedef SizePreset = ({OutputSize size, String? name});

/// One Aspect Ratio and its Size Presets, largest first.
typedef PresetGroup = ({Ratio ratio, List<SizePreset> presets});

/// The Aspect Ratio of [defaultOutputSize].
const Ratio defaultRatio = (w: 16, h: 9);

/// Every Size Preset, grouped by Aspect Ratio in chip order.
const List<PresetGroup> presetGroups = [
  (
    ratio: defaultRatio,
    presets: [
      (size: defaultOutputSize, name: 'Frame TV 4K'),
      (size: (width: 2560, height: 1440), name: null),
      (size: (width: 1920, height: 1080), name: null),
    ],
  ),
  (
    ratio: (w: 3, h: 2),
    presets: [
      (size: (width: 3840, height: 2560), name: null),
      (size: (width: 2880, height: 1920), name: null),
      (size: (width: 1920, height: 1280), name: null),
    ],
  ),
  (
    ratio: (w: 4, h: 3),
    presets: [
      (size: (width: 3840, height: 2880), name: null),
      (size: (width: 2880, height: 2160), name: null),
      (size: (width: 1600, height: 1200), name: null),
    ],
  ),
  (
    ratio: (w: 1, h: 1),
    presets: [
      (size: (width: 3840, height: 3840), name: null),
      (size: (width: 2160, height: 2160), name: null),
      (size: (width: 1080, height: 1080), name: null),
    ],
  ),
  (
    ratio: (w: 4, h: 5),
    presets: [
      (size: (width: 3072, height: 3840), name: null),
      (size: (width: 2160, height: 2700), name: null),
      (size: (width: 1080, height: 1350), name: null),
    ],
  ),
  (
    ratio: (w: 2, h: 3),
    presets: [
      (size: (width: 2560, height: 3840), name: null),
      (size: (width: 1920, height: 2880), name: null),
      (size: (width: 1280, height: 1920), name: null),
    ],
  ),
  (
    ratio: (w: 9, h: 16),
    presets: [
      (size: (width: 2160, height: 3840), name: null),
      (size: (width: 1440, height: 2560), name: null),
      (size: (width: 1080, height: 1920), name: null),
    ],
  ),
];

/// `{W} × {H}`, plus ` · {name}` when the preset has one.
String presetLabel(SizePreset preset) {
  final (:size, :name) = preset;
  final dims = '${size.width} × ${size.height}';
  return name == null ? dims : '$dims · $name';
}

/// [ratio]'s Size Presets, largest first; empty for a custom ratio.
List<SizePreset> presetsFor(Ratio ratio) => [
  for (final group in presetGroups)
    if (group.ratio == ratio) ...group.presets,
];

/// `W:H`, as on the ratio chips.
String ratioLabel(Ratio ratio) => '${ratio.w}:${ratio.h}';

/// Whether [ratio] is one of the seven chip ratios rather than `Custom`.
bool isPresetRatio(Ratio ratio) => presetGroups.any((g) => g.ratio == ratio);
