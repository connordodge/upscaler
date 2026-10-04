import 'package:flutter/material.dart';

/// Darkroom design tokens (see design/HANDOFF.md).
abstract final class Dr {
  static const background = Color(0xFF0B0B0D);
  static const stage = Color(0xFF121214);
  static const bar = Color(0xFF18181B);
  static const outputBar = Color(0xFF141417);
  static const menu = Color(0xFF1E1E22);

  /// Checked menu item and closed Ratio Lock fill.
  static const raised = Color(0xFF2C2C33);
  static const control = Color(0xFF222226);
  static const selected = Color(0xFF3A3A42);
  static const bezel = Color(0xFF26262B);
  static const divider = Color(0xFF2A2A2F);
  static const controlLine = Color(0xFF34343A);
  static const text = Color(0xFFECECEF);
  static const textSecondary = Color(0xFFB4B4BC);
  static const textMuted = Color(0xFF9A9AA3);
  static const textDisabled = Color(0xFF6B6B74);
  static const accent = Color(0xFF6E3FF3);

  /// Accent on dark surfaces, e.g. the check on the selected Size Preset.
  static const accentLight = Color(0xFFA88BFF);
  static const success = Color(0xFF4ADE80);
  static const error = Color(0xFFF87171);

  static const sans = 'HankenGrotesk';
  static const mono = 'JetBrainsMono';

  static TextStyle sansStyle(
    double size, [
    FontWeight weight = .w400,
    Color color = text,
  ]) => TextStyle(
    fontFamily: sans,
    fontSize: size,
    fontWeight: weight,
    color: color,
  );

  static TextStyle monoStyle(
    double size, [
    FontWeight weight = .w400,
    Color color = textMuted,
  ]) => TextStyle(
    fontFamily: mono,
    fontSize: size,
    fontWeight: weight,
    color: color,
  );
}

final ThemeData darkroomTheme = _build();

ThemeData _build() {
  final base = ThemeData(
    brightness: .dark,
    fontFamily: Dr.sans,
    scaffoldBackgroundColor: Dr.background,
    canvasColor: Dr.background,
    colorScheme: const ColorScheme.dark(
      primary: Dr.accent,
      onPrimary: Colors.white,
      surface: Dr.bar,
      onSurface: Dr.text,
      error: Dr.error,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: Dr.sans,
      bodyColor: Dr.text,
      displayColor: Dr.text,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Dr.accent,
      selectionColor: Dr.accent.withValues(alpha: 0.4),
    ),
  );
}
