import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = File('THIRD_PARTY_NOTICES.md');
  final bundled = File('macos/Runner/realesrgan/THIRD_PARTY_NOTICES.md');

  test('notices include the Real-ESRGAN and font licenses', () {
    final text = root.readAsStringSync();
    expect(text, contains('Real-ESRGAN'));
    expect(text, contains('Hanken Grotesk Project Authors'));
    expect(text, contains('JetBrains Mono Project Authors'));
    expect(
      RegExp('SIL OPEN FONT LICENSE Version 1.1').allMatches(text),
      hasLength(2),
    );
  });

  test('the copy that ships in the app bundle matches the root file', () {
    expect(bundled.existsSync(), isTrue);
    expect(bundled.readAsStringSync(), root.readAsStringSync());
  });
}
