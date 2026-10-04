import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:upscaler/main.dart';
import 'package:upscaler/output_settings.dart';
import 'package:upscaler/upscale/size_presets.dart';
import 'package:upscaler/widgets/output_bar.dart';

/// Unlocked, at a `Custom` Aspect Ratio.
const OutputSettings _custom = (
  size: (width: 1000, height: 1400),
  ratio: (w: 5, h: 7),
  locked: false,
);

/// Locked 16:9 after typing W `1000`: the height rounds off the ratio.
const OutputSettings _rounded = (
  size: (width: 1000, height: 563),
  ratio: defaultRatio,
  locked: true,
);

const _saved = {
  'width': 1000,
  'height': 1400,
  'ratioW': 5,
  'ratioH': 7,
  'locked': false,
};

/// Replaces the shared_preferences platform with an in-memory one holding [data], so nothing
/// touches the real preferences on disk.
InMemorySharedPreferencesAsync _prefs([Map<String, Object> data = const {}]) {
  final prefs = InMemorySharedPreferencesAsync.withData(data);
  SharedPreferencesAsyncPlatform.instance = prefs;
  return prefs;
}

Future<Map<String, Object>> _stored(InMemorySharedPreferencesAsync prefs) =>
    prefs.getPreferences(
      const GetPreferencesParameters(filter: PreferencesFilters()),
      const SharedPreferencesOptions(),
    );

class _ThrowingStore implements OutputSettingsStore {
  @override
  Future<OutputSettings> load() async => throw StateError('unreadable');

  @override
  Future<void> save(OutputSettings settings) async {}
}

void main() {
  group('outputSettingsFrom', () {
    test('reads the five keys', () {
      expect(outputSettingsFrom(_saved), _custom);
      expect(
        outputSettingsFrom({
          'width': 1000,
          'height': 563,
          'ratioW': 16,
          'ratioH': 9,
          'locked': true,
        }),
        _rounded,
      );
    });

    test('reduces a ratio stored unreduced', () {
      expect(
        outputSettingsFrom({..._saved, 'ratioW': 10, 'ratioH': 14}),
        _custom,
      );
    });

    test('accepts the 256–8192 limits', () {
      expect(
        outputSettingsFrom({
          'width': 256,
          'height': 8192,
          'ratioW': 1,
          'ratioH': 32,
          'locked': true,
        }),
        (size: (width: 256, height: 8192), ratio: (w: 1, h: 32), locked: true),
      );
    });

    for (final (why, values) in <(String, Map<String, Object?>)>[
      ('nothing', {}),
      ('a missing width', {..._saved}..remove('width')),
      ('a missing height', {..._saved}..remove('height')),
      ('a missing ratioW', {..._saved}..remove('ratioW')),
      ('a missing ratioH', {..._saved}..remove('ratioH')),
      ('a missing lock', {..._saved}..remove('locked')),
      ('a null width', {..._saved, 'width': null}),
      (
        'a width below 256',
        {..._saved, 'width': 255, 'ratioW': 51, 'ratioH': 280},
      ),
      ('a height above 8192', {..._saved, 'height': 8193}),
      ('a text width', {..._saved, 'width': '1000'}),
      ('a fractional height', {..._saved, 'height': 1400.0}),
      ('a zero ratio side', {..._saved, 'ratioW': 0}),
      ('a negative ratio', {..._saved, 'ratioW': -5, 'ratioH': -7}),
      ('a text ratio', {..._saved, 'ratioH': '7'}),
      ('a lock that isn\'t a bool', {..._saved, 'locked': 0}),
      (
        'a ratio the size can\'t come from',
        {..._saved, 'ratioW': 16, 'ratioH': 9},
      ),
    ]) {
      test('rejects $why', () => expect(outputSettingsFrom(values), isNull));
    }
  });

  group('OutputSettingsStore', () {
    const store = OutputSettingsStore();

    test('loads the default from an empty store', () async {
      _prefs();
      expect(await store.load(), defaultOutputSettings);
    });

    test('the default is 16:9 · 3840 × 2160 with the lock closed', () {
      expect(defaultOutputSettings, (
        size: (width: 3840, height: 2160),
        ratio: (w: 16, h: 9),
        locked: true,
      ));
    });

    test('loads what was saved under the five keys', () async {
      _prefs(_saved);
      expect(await store.load(), _custom);
    });

    test('loads the default from invalid or partial data', () async {
      _prefs({..._saved, 'height': 9000});
      expect(await store.load(), defaultOutputSettings);
      _prefs({'width': 1000, 'height': 1400});
      expect(await store.load(), defaultOutputSettings);
    });

    test('saves width, height, ratioW, ratioH and locked', () async {
      final prefs = _prefs({'unrelated': 'kept'});
      await store.save(_rounded);
      expect(await _stored(prefs), {
        'unrelated': 'kept',
        'width': 1000,
        'height': 563,
        'ratioW': 16,
        'ratioH': 9,
        'locked': true,
      });

      await store.save(_custom);
      expect(await _stored(prefs), {'unrelated': 'kept', ..._saved});
      expect(await store.load(), _custom);
    });
  });

  group('loadOutputSettings', () {
    test('a throwing load gives the default', () async {
      expect(await loadOutputSettings(_ThrowingStore()), defaultOutputSettings);
    });

    test('passes on what the store loads', () async {
      _prefs(_saved);
      expect(
        await loadOutputSettings(const OutputSettingsStore()),
        _custom,
      );
    });
  });

  group('UpscalerApp', () {
    String field(WidgetTester tester, Key key) =>
        tester.widget<TextField>(find.byKey(key)).controller!.text;

    Future<void> pumpLoaded(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(960, 820)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const store = OutputSettingsStore();
      final settings = await tester.runAsync(() => loadOutputSettings(store));
      await tester.pumpWidget(
        UpscalerApp(initialSettings: settings!, settingsStore: store),
      );
    }

    testWidgets('starts with the saved settings and saves changes', (
      tester,
    ) async {
      final prefs = _prefs(_saved);
      await pumpLoaded(tester);

      expect(field(tester, OutputBarKeys.width), '1000');
      expect(field(tester, OutputBarKeys.height), '1400');
      expect(find.byKey(OutputBarKeys.custom), findsOneWidget);

      await tester.tap(find.byKey(OutputBarKeys.ratio((w: 4, h: 5))));
      await tester.pump();
      expect(await tester.runAsync(() => _stored(prefs)), {
        'width': 3072,
        'height': 3840,
        'ratioW': 4,
        'ratioH': 5,
        'locked': false,
      });
    });

    testWidgets('an empty store starts at 16:9 · 3840 × 2160 (Frame TV 4K), '
        'locked', (tester) async {
      _prefs();
      await pumpLoaded(tester);

      expect(field(tester, OutputBarKeys.width), '3840');
      expect(field(tester, OutputBarKeys.height), '2160');
      expect(find.byKey(OutputBarKeys.custom), findsNothing);
      expect(
        tester
            .getSemantics(find.byKey(OutputBarKeys.ratio(defaultRatio)))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.byKey(OutputBarKeys.lock))
            .getSemanticsData()
            .flagsCollection
            .isToggled,
        Tristate.isTrue,
      );
      await tester.tap(find.byKey(OutputBarKeys.presets));
      await tester.pumpAndSettle();
      expect(find.text('3840 × 2160 · Frame TV 4K'), findsOneWidget);
    });
  });
}
