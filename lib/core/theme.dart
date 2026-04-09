import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentCyan = Color(0xFF06B6D4);
  
  // Light Theme Palette
  static const Color lightBg = Color(0xFFF9FAFB);
  static const Color lightSurface = Colors.white;
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark Theme Palette
  static const Color darkBg = Color(0xFF0B0D17);
  static const Color darkSurface = Color(0xFF151828);

  static ThemeData get lightTheme {
    return _buildTheme(Brightness.light);
  }

  static ThemeData get darkTheme {
    return _buildTheme(Brightness.dark);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    final scaffoldBg = isDark ? darkBg : lightBg;
    final surfaceColor = isDark ? darkSurface : lightSurface;
    final textColor = isDark ? Colors.white : lightTextPrimary;
    final subTextColor = isDark ? Colors.white54 : lightTextSecondary;

    return base.copyWith(
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryIndigo,
        brightness: brightness,
        primary: primaryIndigo,
        secondary: accentRose,
        outlineVariant: isDark ? Colors.white10 : Colors.black12,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: textColor),
        titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: textColor),
        bodyLarge: GoogleFonts.inter(color: textColor),
        bodyMedium: GoogleFonts.inter(color: subTextColor),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20, 
          fontWeight: FontWeight.w600, 
          color: textColor
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: isDark ? 8 : 2,
        shadowColor: isDark ? Colors.black : Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryIndigo, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: subTextColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryIndigo,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white10 : Colors.black12,
        thickness: 1,
      ),
    );
  }
}
