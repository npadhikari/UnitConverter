import 'package:material_ui/material_ui.dart';

const crimson = Color(0xFFC8102E);
const nepalBlue = Color(0xFF1F3A93);
const ink = Color(0xFF16181D);
const ground = Color(0xFFF6F5F1);
const muted = Color(0xFF5B606B);
const lineGreen = Color(0xFF13A05A);

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: crimson,
    brightness: b,
    primary: dark ? const Color(0xFFFF8A9A) : crimson,
    secondary: dark ? const Color(0xFF9DB3FF) : nepalBlue,
    surface: dark ? const Color(0xFF15161A) : ground,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? const Color(0xFF202227) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: dark ? const Color(0xFF2E3138) : const Color(0xFFE4E2DA)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      isDense: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
