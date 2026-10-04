import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upscaler/crop_picker.dart';
import 'package:upscaler/home_page.dart';
import 'package:upscaler/theme.dart';
import 'package:upscaler/upscale/upscale_options.dart';
import 'package:upscaler/upscale/upscaler.dart';
import 'package:upscaler/widgets/stage_parts.dart';
import 'package:upscaler/widgets/toolbar.dart';

const _sample = '/photos/temple-garden.jpg';
const _sampleSize = (width: 2048, height: 1536);
const _output = '/photos/temple-garden_3840x2160.jpg';
const _portrait = (width: 1000, height: 1500);

/// Key of the stand-in the tests inject instead of a decoded image.
Key _img(String path) => ValueKey('img:$path');

Widget _fakeImage(String path) => SizedBox.expand(key: _img(path));

/// An upscale the test finishes by hand. It never touches the real pipeline; it only names the
/// output the way the real one would.
class _FakeUpscale {
  final started = Completer<void>();
  final _done = Completer<String>();
  void Function(double? progress)? _onProgress;
  String? _input;

  /// The Output Size [HomePage] asked for.
  OutputSize? outputSize;

  Future<String> call({
    required String input,
    required PixelSize size,
    required OutputSize outputSize,
    required UpscaleMode mode,
    required double cropPosition,
    required void Function(double? progress) onProgress,
  }) {
    _input = input;
    this.outputSize = outputSize;
    _onProgress = onProgress;
    started.complete();
    return _done.future;
  }

  void progress(double? p) => _onProgress!(p);
  void finish() => _done.complete(Upscaler.outputPathFor(_input!, outputSize!));
  void fail(Object error) => _done.completeError(error);
}

Future<void> _pump(
  WidgetTester tester, {
  String? picked = _sample,
  PixelSize size = _sampleSize,
  OutputSize outputSize = defaultOutputSize,
  RunUpscale? upscale,
  void Function(String)? reveal,
  void Function(String)? open,
}) async {
  tester.view
    ..physicalSize = const Size(960, 820)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: darkroomTheme,
      home: HomePage(
        initialOutputSize: outputSize,
        pickImage: () async => picked,
        readSize: (_) async => size,
        upscale: upscale ?? _FakeUpscale().call,
        imageBuilder: _fakeImage,
        revealInFinder: reveal ?? (_) {},
        openFile: open ?? (_) {},
      ),
    ),
  );
}

Future<void> _openImage(WidgetTester tester) async {
  await tester.tap(find.text('Open…'));
  await tester.pump();
  await tester.pump();
}

String _left(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('status-left'))).data!;
String _right(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('status-right'))).data!;

/// The enabled state of the button or segment labelled [label].
bool _enabled(WidgetTester tester, String label) {
  final buttons = find.ancestor(
    of: find.textContaining(label),
    matching: find.byWidgetPredicate((w) => w is FilledButton || w is InkWell),
  );
  final w = tester.widget(buttons.first);
  return w is FilledButton ? w.onPressed != null : (w as InkWell).onTap != null;
}

void main() {
  group('empty state', () {
    testWidgets('shows the drop zone and no-image status', (tester) async {
      await _pump(tester);

      expect(find.text('Drop an image to start'), findsOneWidget);
      // The bars span the whole window.
      for (final bar in [Toolbar, StatusBar]) {
        final background = find
            .descendant(of: find.byType(bar), matching: find.byType(Container))
            .first;
        expect(tester.getSize(background).width, 960, reason: '$bar');
      }
      expect(find.text('Choose Image…'), findsOneWidget);
      expect(_left(tester), 'No image');
      expect(_right(tester), 'Output 3840×2160');
      expect(
        find.text('PNG, JPEG or WebP. It becomes exact 3840 × 2160 art.'),
        findsOneWidget,
      );
      expect(find.byType(CropPicker), findsNothing);
    });

    testWidgets('names the Output Size', (tester) async {
      await _pump(tester, outputSize: _portrait);

      expect(_right(tester), 'Output 1000×1500');
      expect(
        find.text('PNG, JPEG or WebP. It becomes exact 1000 × 1500 art.'),
        findsOneWidget,
      );
    });

    testWidgets('Upscale and the view switch are disabled', (tester) async {
      await _pump(tester);

      expect(_enabled(tester, 'Upscale'), isFalse);
      expect(_enabled(tester, 'Crop'), isFalse);
      expect(_enabled(tester, 'Preview'), isFalse);
      expect(_enabled(tester, 'Open…'), isTrue);
      expect(_enabled(tester, 'AI · Photo'), isTrue);
    });

    testWidgets('Choose Image… loads an image', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('Choose Image…'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CropPicker), findsOneWidget);
    });

    testWidgets('rejects files that are not images', (tester) async {
      await _pump(tester, picked: '/photos/notes.txt');
      await _openImage(tester);

      expect(find.text('Couldn\'t open that image'), findsOneWidget);
      expect(find.text('Not a PNG, JPEG or WebP image.'), findsOneWidget);
      expect(find.byType(CropPicker), findsNothing);
    });
  });

  group('crop view', () {
    testWidgets('loading an image enables Upscale and the view switch', (
      tester,
    ) async {
      await _pump(tester);
      await _openImage(tester);

      expect(find.byType(CropPicker), findsOneWidget);
      expect(find.byKey(_img(_sample)), findsOneWidget);
      expect(find.byKey(const ValueKey('crop-overlay')), findsOneWidget);
      expect(_enabled(tester, 'Upscale'), isTrue);
      expect(_enabled(tester, 'Preview'), isTrue);
      expect(
        _left(tester),
        'temple-garden.jpg  2048×1536  →  3840×2160  ·  crop y 360',
      );
      expect(_right(tester), 'Drag frame to reposition');
    });

    testWidgets('exact 16:9 omits the crop and says none is needed', (
      tester,
    ) async {
      await _pump(tester, size: (width: 1920, height: 1080));
      await _openImage(tester);

      expect(_left(tester), 'temple-garden.jpg  1920×1080  →  3840×2160');
      expect(_right(tester), 'No crop needed');
    });

    testWidgets('an image matching a non-16:9 Output Size needs no crop', (
      tester,
    ) async {
      await _pump(
        tester,
        size: (width: 200, height: 300),
        outputSize: _portrait,
      );
      await _openImage(tester);

      expect(_left(tester), 'temple-garden.jpg  200×300  →  1000×1500');
      expect(_right(tester), 'No crop needed');
    });

    testWidgets('the crop window takes the Output Size\'s shape', (
      tester,
    ) async {
      // 100 × 200 covers 1000 × 1500 as 1000 × 2000, so the window is 3/4 of the height.
      await _pump(
        tester,
        size: (width: 100, height: 200),
        outputSize: _portrait,
      );
      await _openImage(tester);

      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('crop-overlay')),
                  )
                  .painter!
              as CropWindowPainter;
      expect(painter.horizontal, isFalse);
      expect(painter.windowFraction, 0.75);
      expect(
        _left(tester),
        'temple-garden.jpg  100×200  →  1000×1500  ·  crop y 250',
      );
    });

    testWidgets('dragging moves the crop and the status bar follows', (
      tester,
    ) async {
      await _pump(tester);
      await _openImage(tester);

      await tester.drag(
        find.byKey(const ValueKey('crop-overlay')),
        const Offset(0, -40),
      );
      await tester.pump();

      final y = int.parse(_left(tester).split('crop y ').last);
      expect(y, lessThan(360));
    });
  });

  group('preview view', () {
    testWidgets('switches between Crop and Preview', (tester) async {
      await _pump(tester);
      await _openImage(tester);

      await tester.tap(find.text('Preview'));
      await tester.pump();

      expect(find.byType(CropPicker), findsNothing);
      expect(find.byType(Bezel), findsOneWidget);
      expect(
        find.text('Output · 3840 × 2160'),
        findsOneWidget,
      );
      expect(_right(tester), 'Switch to Crop to adjust');
      // Before upscaling the preview comes from the source with the crop applied.
      expect(find.byKey(_img(_sample)), findsOneWidget);
      expect(find.byType(CroppedSource), findsOneWidget);

      await tester.tap(find.text('Crop'));
      await tester.pump();

      expect(find.byType(CropPicker), findsOneWidget);
      expect(find.byType(Bezel), findsNothing);
      expect(_right(tester), 'Drag frame to reposition');
    });
  });

  group('preview Output Size', () {
    /// The black screen inside the bezel.
    Finder screen() => find.descendant(
      of: find.byType(Bezel),
      matching: find.byType(ClipRect),
    );

    for (final outputSize in [
      (width: 1080, height: 1920),
      (width: 256, height: 8192),
    ]) {
      final (:width, :height) = outputSize;
      testWidgets('the bezel fits a $width × $height Output Size', (
        tester,
      ) async {
        await _pump(tester, outputSize: outputSize);
        await _openImage(tester);
        await tester.tap(find.text('Preview'));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.text('Output · $width × $height'), findsOneWidget);
        final bezel = tester.getRect(find.byType(Bezel));
        // The stage between the toolbar and the status bar, less its 32px padding.
        final stage = tester
            .getRect(
              find.byWidgetPredicate(
                (w) => w is ColoredBox && w.color == Dr.stage,
              ),
            )
            .deflate(32);
        expect(stage.contains(bezel.topLeft), isTrue);
        expect(stage.contains(bezel.bottomRight), isTrue);
        final screenSize = tester.getSize(screen());
        expect(
          screenSize.width / screenSize.height,
          moreOrLessEquals(width / height, epsilon: 0.01),
        );
        // The caption stays below the bezel, inside the stage.
        final caption = tester.getRect(
          find.text('Output · $width × $height'),
        );
        expect(caption.top, greaterThanOrEqualTo(bezel.bottom));
        expect(caption.bottom, lessThanOrEqualTo(stage.bottom));
      });
    }

    testWidgets('the extreme bezel still fits with the Done card', (
      tester,
    ) async {
      final upscale = _FakeUpscale();
      await _pump(
        tester,
        outputSize: (width: 256, height: 8192),
        upscale: upscale.call,
      );
      await _openImage(tester);
      await tester.tap(find.text('Upscale'));
      await tester.pump();
      upscale.finish();
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Saved temple-garden_256x8192.jpg'), findsOneWidget);
      expect(find.text('256 × 8192 · next to the original'), findsOneWidget);
    });
  });

  group('CroppedSource', () {
    Future<void> pumpAt(
      WidgetTester tester,
      double position, {
      PixelSize size = _sampleSize,
      OutputSize outputSize = defaultOutputSize,
      Size box = const Size(768, 432),
    }) => tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: const ValueKey('box'),
            width: box.width,
            height: box.height,
            child: CroppedSource(
              path: _sample,
              size: size,
              outputSize: outputSize,
              position: position,
              imageBuilder: _fakeImage,
            ),
          ),
        ),
      ),
    );

    testWidgets('scales and shifts from a non-16:9 Output Size', (
      tester,
    ) async {
      // 100 × 200 covers 1000 × 1500 as 1000 × 2000; at 400 wide that's 0.4px per pixel.
      await pumpAt(
        tester,
        0.5,
        size: (width: 100, height: 200),
        outputSize: _portrait,
        box: const Size(400, 600),
      );
      final image = find.byKey(_img(_sample));
      final box = find.byKey(const ValueKey('box'));
      expect(tester.getSize(image), const Size(400, 800));
      expect(
        tester.getTopLeft(image) - tester.getTopLeft(box),
        const Offset(0, -100),
      );

      await pumpAt(
        tester,
        1,
        size: (width: 100, height: 200),
        outputSize: _portrait,
        box: const Size(400, 600),
      );
      expect(
        tester.getTopLeft(image) - tester.getTopLeft(box),
        const Offset(0, -200),
      );
    });

    testWidgets('slides a wider image along x', (tester) async {
      // 2048 × 1536 covers 1000 × 1500 as 2000 × 1500; at 400 wide that's 0.4px per pixel.
      await pumpAt(
        tester,
        1,
        outputSize: _portrait,
        box: const Size(400, 600),
      );
      final image = find.byKey(_img(_sample));
      expect(tester.getSize(image), const Size(800, 600));
      expect(
        tester.getTopLeft(image) -
            tester.getTopLeft(find.byKey(const ValueKey('box'))),
        const Offset(-400, 0),
      );
    });

    testWidgets('shifts a taller image up by the crop offset', (tester) async {
      await pumpAt(tester, 0.5);
      // Covered image is 3840×2880; the 360px offset becomes 72px at 768 wide.
      final image = find.byKey(_img(_sample));
      expect(tester.getSize(image), const Size(768, 576));
      expect(
        tester.getTopLeft(image) -
            tester.getTopLeft(find.byKey(const ValueKey('box'))),
        const Offset(0, -72),
      );
    });

    testWidgets('position 0 shows the top', (tester) async {
      await pumpAt(tester, 0);
      final image = find.byKey(_img(_sample));
      expect(
        tester.getTopLeft(image) -
            tester.getTopLeft(find.byKey(const ValueKey('box'))),
        Offset.zero,
      );
    });
  });

  group('working state', () {
    testWidgets('disables Open, method and crop but keeps the view switch', (
      tester,
    ) async {
      final upscale = _FakeUpscale();
      await _pump(tester, upscale: upscale.call);
      await _openImage(tester);

      await tester.tap(find.text('Upscale'));
      await tester.pump();
      upscale.progress(0.62);
      await tester.pump();

      expect(_enabled(tester, 'Open…'), isFalse);
      expect(_enabled(tester, 'AI · Photo'), isFalse);
      expect(_enabled(tester, 'AI · Illustration'), isFalse);
      expect(_enabled(tester, 'Plain'), isFalse);
      expect(_enabled(tester, 'Preview'), isTrue);
      expect(_enabled(tester, 'Crop'), isTrue);
      expect(_enabled(tester, 'Upscaling…'), isFalse);
      expect(find.text('Upscaling…  62%'), findsOneWidget);
      expect(find.byKey(const ValueKey('progress-line')), findsOneWidget);
      expect(find.text('AI upscaling on your Mac\'s GPU'), findsOneWidget);
      expect(_right(tester), 'Step 1 of 2 · AI upscale, then resize and crop');

      // Dragging the crop does nothing while running.
      final before = _left(tester);
      await tester.drag(
        find.byKey(const ValueKey('crop-overlay')),
        const Offset(0, -40),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(_left(tester), before);

      upscale.progress(null);
      await tester.pump();
      expect(find.text('Upscaling…'), findsOneWidget);
      expect(_right(tester), 'Step 2 of 2 · Resize and crop');

      await tester.tap(find.text('Preview'));
      await tester.pump();
      expect(find.byType(Bezel), findsOneWidget);

      upscale.finish();
      await tester.pump();
      await tester.pump();
    });

    testWidgets('plain mode uses the resize wording', (tester) async {
      final upscale = _FakeUpscale();
      await _pump(tester, upscale: upscale.call);
      await _openImage(tester);
      await tester.tap(find.text('Plain'));
      await tester.pump();

      await tester.tap(find.text('Upscale'));
      await tester.pump();
      upscale.progress(null);
      await tester.pump();

      expect(find.text('Resizing and cropping'), findsNWidgets(2));

      upscale.finish();
      await tester.pump();
      await tester.pump();
    });
  });

  group('done state', () {
    Future<_FakeUpscale> finishUpscale(
      WidgetTester tester, {
      void Function(String)? reveal,
      void Function(String)? open,
    }) async {
      final upscale = _FakeUpscale();
      await _pump(tester, upscale: upscale.call, reveal: reveal, open: open);
      await _openImage(tester);
      await tester.tap(find.text('Upscale'));
      await tester.pump();
      upscale.finish();
      await tester.pump();
      await tester.pump();
      return upscale;
    }

    testWidgets('switches to Preview showing the output file', (tester) async {
      final upscale = await finishUpscale(tester);

      expect(upscale.outputSize, defaultOutputSize);
      expect(find.byType(CropPicker), findsNothing);
      expect(find.byKey(_img(_output)), findsOneWidget);
      expect(find.text('Saved temple-garden_3840x2160.jpg'), findsOneWidget);
      expect(find.text('3840 × 2160 · next to the original'), findsOneWidget);
      expect(_right(tester), 'Done');
      // Upscale is available again.
      expect(_enabled(tester, 'Upscale'), isTrue);
    });

    testWidgets('upscales to the HomePage Output Size', (tester) async {
      final upscale = _FakeUpscale();
      await _pump(tester, outputSize: _portrait, upscale: upscale.call);
      await _openImage(tester);
      await tester.tap(find.text('Upscale'));
      await tester.pump();

      expect(upscale.outputSize, _portrait);

      upscale.finish();
      await tester.pump();
      await tester.pump();

      expect(find.text('Saved temple-garden_1000x1500.jpg'), findsOneWidget);
      expect(find.text('1000 × 1500 · next to the original'), findsOneWidget);
      expect(find.text('Output · 1000 × 1500'), findsNothing);
      expect(
        find.byKey(_img('/photos/temple-garden_1000x1500.jpg')),
        findsOneWidget,
      );
    });

    testWidgets('Show in Finder and Open act on the output', (tester) async {
      final revealed = <String>[];
      final opened = <String>[];
      await finishUpscale(tester, reveal: revealed.add, open: opened.add);

      await tester.tap(find.text('Show in Finder'));
      await tester.tap(find.text('Open').last);

      expect(revealed, [_output]);
      expect(opened, [_output]);
    });

    testWidgets('changing the method clears it', (tester) async {
      await finishUpscale(tester);

      await tester.tap(find.text('Plain'));
      await tester.pump();

      expect(find.textContaining('Saved'), findsNothing);
      expect(find.byKey(_img(_output)), findsNothing);
      expect(find.byKey(_img(_sample)), findsOneWidget);
      expect(_right(tester), 'Switch to Crop to adjust');
    });

    testWidgets('moving the crop clears it', (tester) async {
      await finishUpscale(tester);

      await tester.tap(find.text('Crop'));
      await tester.pump();
      await tester.drag(
        find.byKey(const ValueKey('crop-overlay')),
        const Offset(0, -40),
      );
      await tester.pump();
      await tester.tap(find.text('Preview'));
      await tester.pump();

      expect(find.textContaining('Saved'), findsNothing);
      expect(find.byKey(_img(_output)), findsNothing);
    });

    testWidgets('loading another image clears it', (tester) async {
      await finishUpscale(tester);

      await _openImage(tester);

      expect(find.textContaining('Saved'), findsNothing);
      expect(find.byType(CropPicker), findsOneWidget);
    });
  });

  group('failure', () {
    testWidgets('shows an error card and Failed in the status bar', (
      tester,
    ) async {
      final upscale = _FakeUpscale();
      await _pump(tester, upscale: upscale.call);
      await _openImage(tester);
      await tester.tap(find.text('Upscale'));
      await tester.pump();

      upscale.fail(StateError('boom'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Upscale failed'), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
      expect(_right(tester), 'Failed');
      expect(_enabled(tester, 'Upscale'), isTrue);
    });
  });
}
