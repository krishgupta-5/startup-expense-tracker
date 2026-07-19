import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppTheme {
  // Colors (Preserved legacy dark constants)
  static const Color background = Colors.black;
  static const Color cardDark = Color(0xFF161616);
  static const Color accentWhite = Colors.white;
  static const Color textGrey = Color(0xFF888888);

  // Brand Colors
  static const Color greenSafe = Color(0xFF00BFA5);
  static const Color yellowWarning = Color(0xFFFFA000);
  static const Color redCritical = Color(0xFFFF4081);
  static const Color credBlue = Color(0xFF3A4B8A);

  // Fonts
  static const String fontSerif =
      'Times New Roman'; // Represents a Classy Serif
  static const String fontSans = 'Roboto'; // Represents a Clean Sans-Serif

  // Text Styles
  static TextStyle headerStyle = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: accentWhite,
    letterSpacing: 0.5,
  );

  static TextStyle sectionTitleStyle = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: textGrey,
    letterSpacing: 1.5,
  );

  static TextStyle bodyStyle = GoogleFonts.inter(
    fontSize: 14,
    color: accentWhite,
  );

  // --- Theme Data Definitions ---

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF09090B),
      colorScheme: ColorScheme.fromSeed(
        seedColor: credBlue,
        brightness: Brightness.dark,
        surface: const Color(0xFF141416),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      useMaterial3: true,
      iconTheme: const IconThemeData(color: Colors.white),
      dividerColor: Colors.white.withValues(alpha: 0.06),
      cardColor: const Color(0xFF141416),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFAF8F5), // Warm cream white
      colorScheme: ColorScheme.fromSeed(
        seedColor: credBlue,
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      useMaterial3: true,
      iconTheme: const IconThemeData(color: Color(0xFF18181A)),
      dividerColor: const Color(0xFFE6E1D8),
      cardColor: Colors.white,
    );
  }

  static ShadThemeData get darkShadTheme {
    return ShadThemeData(
      brightness: Brightness.dark,
      colorScheme: const ShadSlateColorScheme.dark(),
    );
  }

  static ShadThemeData get lightShadTheme {
    return ShadThemeData(
      brightness: Brightness.light,
      colorScheme: const ShadSlateColorScheme.light(),
    );
  }
}

/// Adaptive theme colors extension on BuildContext
/// Provides instant access to vibrant, high-contrast colors depending on current theme mode
extension AppThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  // Backgrounds
  Color get appBackground =>
      isDarkMode ? const Color(0xFF09090B) : const Color(0xFFFAF8F5); // Warm cream white
  Color get cardBackground =>
      isDarkMode ? const Color(0xFF141416) : Colors.white;
  Color get cardSecondaryBackground =>
      isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFF2ECE6);

  // Borders
  Color get borderColor =>
      isDarkMode
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE6E1D8);
  Color get borderColorStrong =>
      isDarkMode
          ? Colors.white.withValues(alpha: 0.2)
          : const Color(0xFFC9C3B9);
  Color get borderSubtle =>
      isDarkMode
          ? Colors.white.withValues(alpha: 0.04)
          : const Color(0xFFF5F0E8);

  // Typography & Icons
  Color get textPrimary =>
      isDarkMode ? Colors.white : const Color(0xFF18181A); // Deep charcoal black
  Color get textSecondary =>
      isDarkMode ? Colors.white54 : const Color(0xFF5E5A54); // Sophisticated warm gray
  Color get textTertiary =>
      isDarkMode ? Colors.white38 : const Color(0xFF969088);
  Color get textSubtle =>
      isDarkMode ? Colors.white24 : const Color(0xFFC7C1B7);

  Color get iconPrimary =>
      isDarkMode ? Colors.white : const Color(0xFF18181A);
  Color get iconSecondary =>
      isDarkMode ? Colors.white70 : const Color(0xFF5E5A54);

  // Glass & subtle fills
  Color get glassBackground =>
      isDarkMode
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.04);
  Color get glassBackgroundStrong =>
      isDarkMode
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.08);

  // Inputs & Nav
  Color get inputBackground =>
      isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
  Color get navBackground =>
      isDarkMode ? Colors.black : const Color(0xFFFAF8F5);
  Color get navActiveTab =>
      isDarkMode ? const Color(0xFF222222) : const Color(0xFFEBE6DD);

  // Accents & Brand
  Color get primaryColor =>
      isDarkMode ? Colors.white : const Color(0xFF18181A);
  Color get accentColor =>
      isDarkMode ? const Color(0xFF00BFA5) : const Color(0xFF00BFA5);
}
