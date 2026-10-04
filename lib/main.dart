import 'package:flutter/material.dart';

import 'home_page.dart';

void main() => runApp(const UpscalerApp());

class UpscalerApp extends StatelessWidget {
  const UpscalerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upscaler',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: .dark),
      home: const HomePage(),
    );
  }
}
