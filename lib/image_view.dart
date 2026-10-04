import 'dart:io';

import 'package:flutter/widgets.dart';

/// Builds the widget that paints the image at [path], stretched to fill its box. A seam so widget
/// tests can avoid decoding real images (which hangs under `flutter test`).
typedef ImageBuilder = Widget Function(String path);

Widget fileImageBuilder(String path) => Image.file(
  File(path),
  fit: .fill,
  filterQuality: .medium,
  gaplessPlayback: true,
);
