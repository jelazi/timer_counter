import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Colors
  static const Color primaryColor = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color accentColor = Color(0xFF06B6D4);
  static const Color successColor = Color(0xFF22C55E);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF334155);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: primaryColor, brightness: Brightness.light, surface: surfaceLight),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        titleTextStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: const IconThemeData(color: primaryColor),
        selectedLabelTextStyle: GoogleFonts.inter(color: primaryColor, fontWeight: FontWeight.w600),
        unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
        unselectedLabelTextStyle: GoogleFonts.inter(color: Colors.grey.shade600),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: primaryColor, foregroundColor: Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: primaryColor, brightness: Brightness.dark, surface: surfaceDark),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: surfaceDark,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade800),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surfaceDark,
        selectedIconTheme: const IconThemeData(color: primaryColor),
        selectedLabelTextStyle: GoogleFonts.inter(color: primaryColor, fontWeight: FontWeight.w600),
        unselectedIconTheme: IconThemeData(color: Colors.grey.shade400),
        unselectedLabelTextStyle: GoogleFonts.inter(color: Colors.grey.shade400),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: primaryColor, foregroundColor: Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade800, thickness: 1),
    );
  }
}
