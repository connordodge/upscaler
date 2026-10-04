import 'package:flutter/material.dart';

import 'home_page.dart';
import 'output_settings.dart';
import 'theme.dart';

/// Loads the saved Output settings before the first frame, so the default never flashes and
/// nothing is saved before they're in.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const store = OutputSettingsStore();
  final settings = await loadOutputSettings(store);
  runApp(UpscalerApp(initialSettings: settings, settingsStore: store));
}

class UpscalerApp extends StatelessWidget {
  const UpscalerApp({
    super.key,
    this.initialSettings = defaultOutputSettings,
    this.settingsStore = const OutputSettingsStore(),
  });

  final OutputSettings initialSettings;
  final OutputSettingsStore settingsStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Upscaler',
      debugShowCheckedModeBanner: false,
      theme: darkroomTheme,
      darkTheme: darkroomTheme,
      themeMode: .dark,
      home: HomePage(
        initialSettings: initialSettings,
        settingsStore: settingsStore,
      ),
    );
  }
}
