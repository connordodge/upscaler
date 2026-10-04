import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the bundled fonts so text measures as in the app. The default test font draws every glyph
/// a full em wide, which makes width checks like the Output bar fit meaningless.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final (family, weights) in [
    ('HankenGrotesk', [400, 500, 600]),
    ('JetBrainsMono', [400, 500]),
  ]) {
    final loader = FontLoader(family);
    for (final weight in weights) {
      loader.addFont(rootBundle.load('assets/fonts/$family-$weight.ttf'));
    }
    await loader.load();
  }
  await testMain();
}
