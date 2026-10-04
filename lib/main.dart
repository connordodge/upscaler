import 'package:flutter/material.dart';

import 'home_page.dart';
import 'theme.dart';

void main() => runApp(const UpscalerApp());

class UpscalerApp extends StatelessWidget {
  const UpscalerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upscaler',
      debugShowCheckedModeBanner: false,
      theme: darkroomTheme,
      darkTheme: darkroomTheme,
      themeMode: .dark,
      home: const HomePage(),
    );
  }
}
