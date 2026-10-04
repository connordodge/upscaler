import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

import 'upscale/size_editing.dart';
import 'upscale/size_presets.dart';
import 'upscale/upscale_options.dart';

/// The Output Size, Aspect Ratio and Ratio Lock, remembered across launches. [ratio] is reduced
/// and isn't derived from [size]: a locked edit can round the size off its ratio.
typedef OutputSettings = ({OutputSize size, Ratio ratio, bool locked});

/// First launch: `16:9 · 3840 × 2160 (Frame TV 4K)`, lock closed.
const OutputSettings defaultOutputSettings = (
  size: defaultOutputSize,
  ratio: defaultRatio,
  locked: true,
);

const _width = 'width';
const _height = 'height';
const _ratioW = 'ratioW';
const _ratioH = 'ratioH';
const _locked = 'locked';

/// Settings stored under `width`, `height`, `ratioW`, `ratioH` and `locked`, or null unless all
/// five are there and make settings the Output bar could have applied: each side a whole number
/// from [minSide] to [maxSide], a positive ratio (reduced here if it wasn't) that the size matches
/// or rounds from, and a bool lock.
OutputSettings? outputSettingsFrom(Map<String, Object?> values) {
  if (values
      case {
        _width: final int width,
        _height: final int height,
        _ratioW: final int ratioW,
        _ratioH: final int ratioH,
        _locked: final bool locked,
      }
      when ratioW > 0 && ratioH > 0) {
    final size = (width: width, height: height);
    final ratio = reducedRatio((width: ratioW, height: ratioH));
    // A locked edit sets one side and rounds the other from the ratio; lockedSize also rejects
    // either side outside minSide–maxSide.
    final valid = Side.values.any(
      (side) => lockedSize(ratio, side, side.of(size)) == size,
    );
    if (valid) return (size: size, ratio: ratio, locked: locked);
  }
  return null;
}

/// Keeps [OutputSettings] in `shared_preferences`. Widget tests swap in a fake.
class OutputSettingsStore {
  const OutputSettingsStore();

  /// The saved settings, or [defaultOutputSettings] when nothing valid is saved. Throws when the
  /// preferences can't be read.
  Future<OutputSettings> load() async {
    final values = await SharedPreferencesAsync().getAll(
      allowList: {_width, _height, _ratioW, _ratioH, _locked},
    );
    return outputSettingsFrom(values) ?? defaultOutputSettings;
  }

  Future<void> save(OutputSettings settings) async {
    final prefs = SharedPreferencesAsync();
    final (:size, :ratio, :locked) = settings;
    await Future.wait([
      prefs.setInt(_width, size.width),
      prefs.setInt(_height, size.height),
      prefs.setInt(_ratioW, ratio.w),
      prefs.setInt(_ratioH, ratio.h),
      prefs.setBool(_locked, locked),
    ]);
  }
}

/// [store]'s settings, or [defaultOutputSettings] if loading fails.
Future<OutputSettings> loadOutputSettings(OutputSettingsStore store) async {
  try {
    return await store.load();
  } catch (e, st) {
    log('Failed to load the Output settings', error: e, stackTrace: st);
    return defaultOutputSettings;
  }
}
