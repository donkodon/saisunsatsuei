import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppConstants {
  static const Color primaryCyan = Color(0xFF00C2E0); // Main action color
  static const Color backgroundLight = Color(0xFFF5F7FA); // Dashboard bg
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGrey = Color(0xFF8E8E93);
  static const Color successGreen = Color(0xFF34C759); // "Ready" badge
  static const Color warningOrange = Color(0xFFFF9500); // "Draft" badge
  static const Color borderGrey = Color(0xFFE5E5EA);

  static TextStyle get headerStyle => GoogleFonts.notoSansJp(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textDark,
      );

  static TextStyle get subHeaderStyle => GoogleFonts.notoSansJp(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textDark,
      );

  static TextStyle get bodyStyle => GoogleFonts.notoSansJp(
        fontSize: 14,
        color: textDark,
      );
  
  static TextStyle get captionStyle => GoogleFonts.notoSansJp(
        fontSize: 12,
        color: textGrey,
      );
}
