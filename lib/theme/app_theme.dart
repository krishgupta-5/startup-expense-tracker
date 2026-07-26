import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppTheme {
  // Colors (Preserved legacy dark constants)
  static const Color background = Color(0xFF09090B);
  static const Color cardDark = Color(0xFF141416);
  static const Color accentWhite = Colors.white;
  static const Color textGrey = Color(0xFFA1A1AA);

  // Brand Colors (Neon Fintech Accents)
  static const Color greenSafe = Color(0xFF10B981);
  static const Color yellowWarning = Color(0xFFF59E0B);
  static const Color redCritical = Color(0xFFFF375F);
  static const Color credBlue = Color(0xFF3B82F6);

  // Fonts
  static const String fontSerif = 'Times New Roman';
  static const String fontSans = 'Satoshi';

  // Text Styles
  static TextStyle headerStyle = const TextStyle(
    fontFamily: 'Satoshi',
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: accentWhite,
    letterSpacing: -1.0,
  );

  static TextStyle sectionTitleStyle = const TextStyle(
    fontFamily: 'Satoshi',
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: textGrey,
    letterSpacing: 1.5,
  );

  static TextStyle bodyStyle = const TextStyle(
    fontFamily: 'Satoshi',
    fontSize: 14,
    color: accentWhite,
  );

  // --- Theme Data Definitions ---

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: 'Satoshi',
      scaffoldBackgroundColor: const Color(0xFF09090B),
      colorScheme: ColorScheme.fromSeed(
        seedColor: credBlue,
        brightness: Brightness.dark,
        surface: const Color(0xFF141416),
      ),
      useMaterial3: true,
      iconTheme: const IconThemeData(color: Colors.white),
      dividerColor: Colors.white.withValues(alpha: 0.06),
      cardColor: const Color(0xFF141416),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      fontFamily: 'Satoshi',
      scaffoldBackgroundColor: const Color(
        0xFFF9FAFB,
      ), // Crisp, modern cool-gray
      colorScheme: ColorScheme.fromSeed(
        seedColor: credBlue,
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      useMaterial3: true,
      iconTheme: const IconThemeData(color: Color(0xFF09090B)),
      dividerColor: Colors.black.withValues(alpha: 0.06),
      cardColor: Colors.white,
    );
  }

  static ShadThemeData get darkShadTheme {
    return ShadThemeData(
      brightness: Brightness.dark,
      colorScheme: const ShadSlateColorScheme.dark(),
      textTheme: ShadTextTheme(family: 'Satoshi'),
    );
  }

  static ShadThemeData get lightShadTheme {
    return ShadThemeData(
      brightness: Brightness.light,
      colorScheme: const ShadSlateColorScheme.light(),
      textTheme: ShadTextTheme(family: 'Satoshi'),
    );
  }
}

/// Adaptive theme colors extension on BuildContext
/// Provides instant access to vibrant, high-contrast colors depending on current theme mode
extension AppThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  // Backgrounds
  Color get appBackground => isDarkMode
      ? const Color(0xFF09090B)
      : const Color(0xFFF9FAFB); // Crisp ultra-light gray
  Color get cardBackground =>
      isDarkMode ? const Color(0xFF141416) : Colors.white;
  Color get cardSecondaryBackground => isDarkMode
      ? const Color(0xFF1C1C1E)
      : const Color(0xFFF4F4F5); // Zinc-100

  // Borders
  Color get borderColor => isDarkMode
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.black.withValues(alpha: 0.06);
  Color get borderColorStrong => isDarkMode
      ? Colors.white.withValues(alpha: 0.15)
      : Colors.black.withValues(alpha: 0.12);
  Color get borderSubtle => isDarkMode
      ? Colors.white.withValues(alpha: 0.04)
      : Colors.black.withValues(alpha: 0.03);

  // Typography & Icons
  Color get textPrimary => isDarkMode
      ? Colors.white
      : const Color(0xFF09090B); // True Charcoal Black
  Color get textSecondary =>
      isDarkMode ? Colors.white54 : const Color(0xFF71717A); // Zinc-500
  Color get textTertiary =>
      isDarkMode ? Colors.white38 : const Color(0xFFA1A1AA); // Zinc-400
  Color get textSubtle =>
      isDarkMode ? Colors.white24 : const Color(0xFFE4E4E7); // Zinc-200

  Color get iconPrimary => isDarkMode ? Colors.white : const Color(0xFF09090B);
  Color get iconSecondary =>
      isDarkMode ? Colors.white54 : const Color(0xFF71717A);

  // Glass & subtle fills
  Color get glassBackground => isDarkMode
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.black.withValues(alpha: 0.04);
  Color get glassBackgroundStrong => isDarkMode
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);

  // Inputs & Nav
  Color get inputBackground =>
      isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
  Color get navBackground =>
      isDarkMode ? const Color(0xFF141416) : Colors.white;
  Color get navActiveTab => isDarkMode ? Colors.white : const Color(0xFF09090B);

  // Accents & Brand
  Color get primaryColor => isDarkMode ? Colors.white : const Color(0xFF09090B);
  Color get accentColor =>
      const Color(0xFF3B82F6); // Punchy blue that works on both
}
