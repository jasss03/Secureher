import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityModel extends ChangeNotifier {
  // Large text scale toggle
  bool largeText = true;
  // High contrast toggle
  bool highContrast = false;
  // Voice guidance toggle
  bool voiceGuidance = false;
  // Accessory toggle
  bool? accessoryEnabled = false;
  // Travel Alone Mode toggle
  bool travelAloneMode = false;

  AccessibilityModel() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      largeText = prefs.getBool('largeText') ?? true;
      highContrast = prefs.getBool('highContrast') ?? false;
      voiceGuidance = prefs.getBool('voiceGuidance') ?? false;
      accessoryEnabled = prefs.getBool('accessoryEnabled') ?? false;
      travelAloneMode = prefs.getBool('travelAloneMode') ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleLargeText(bool v) async {
    largeText = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('largeText', v);
  }

  Future<void> toggleHighContrast(bool v) async {
    highContrast = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('highContrast', v);
  }

  Future<void> toggleVoiceGuidance(bool v) async {
    voiceGuidance = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voiceGuidance', v);
  }

  Future<void> toggleAccessory(bool v) async {
    accessoryEnabled = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('accessoryEnabled', v);
  }

  Future<void> toggleTravelAlone(bool v) async {
    travelAloneMode = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('travelAloneMode', v);
  }
}

class AppTheme {
  static ThemeData light({required bool highContrast}) {
    // Calming pastel tones
    const lavender = Color(0xFFEAE6FF);
    const blush = Color(0xFFFFE6F1);
    const accent = Color(0xFFFF4D6D); // pinkish red only for SOS

    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF9C73FF),
      brightness: Brightness.light,
    );

    final scheme = baseScheme.copyWith(
      primary: const Color(0xFF7B61FF),
      secondary: const Color(0xFF23B5A9),
      surface: Colors.white,
      error: accent,
      tertiary: const Color(0xFFFF8DB1),
      surfaceContainerHighest: lavender,
    );

    final textTheme = GoogleFonts.poppinsTextTheme().apply(
      bodyColor: highContrast ? Colors.black : const Color(0xFF2C2C2C),
      displayColor: highContrast ? Colors.black : const Color(0xFF2C2C2C),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: highContrast ? Colors.white : Colors.white,
      textTheme: textTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: highContrast
            ? const Color(0xFFF5F5F5)
            : const Color(0xFFF8F7FF),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: StadiumBorder(),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        selectedColor: blush,
      ),
    );
  }
}
