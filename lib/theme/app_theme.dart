import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryNavy = Color(0xFF1A2744);
  static const Color primaryBlue = Color(0xFF1E4FC2);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color lightGreen = Color(0xFFDCFCE7);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color lightRed = Color(0xFFFEE2E2);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color lightAmber = Color(0xFFFEF3C7);
  static const Color surfaceWhite = Color(0xFFF8FAFC);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color borderGrey = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color chipBg = Color(0xFFEFF6FF);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: accentBlue,
        surface: surfaceWhite,
        background: surfaceWhite,
      ),
      scaffoldBackgroundColor: surfaceWhite,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: textLight, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderGrey),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: chipBg,
        labelStyle: const TextStyle(fontSize: 12, color: primaryBlue),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}

// Status Colors
Color getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending': return AppTheme.warningAmber;
    case 'approved': return AppTheme.successGreen;
    case 'dispatched': return AppTheme.primaryBlue;
    case 'partial': return const Color(0xFF7C3AED);
    default: return AppTheme.textSecondary;
  }
}

Color getStatusBg(String status) {
  switch (status.toLowerCase()) {
    case 'pending': return AppTheme.lightAmber;
    case 'approved': return AppTheme.lightGreen;
    case 'dispatched': return AppTheme.chipBg;
    case 'partial': return const Color(0xFFF3E8FF);
    default: return AppTheme.borderGrey;
  }
}
