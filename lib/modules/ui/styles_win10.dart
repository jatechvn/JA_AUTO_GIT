// lib/modules/ui/styles_win10.dart
import 'package:flutter/material.dart';
import 'styles.dart';

class StylesWin10 {
  // Dark theme colors (translucent for Aero Blur on Windows 10)
  static const dark = AppColors(
    bgPrimary: Color(0x80121212),       // 50% opacity main background
    bgSecondary: Color(0xB31F1F1F),     // 70% opacity sidebar
    bgTertiary: Color(0xCC252525),      // 80% opacity inputs/lists
    bgCard: Color(0xD92C2C2C),          // 85% opacity cards
    bgHover: Color(0x1F00ADB5),         // soft cyan hover highlight
    textPrimary: Color(0xFFEEEEEE),     // main text
    textSecondary: Color(0xFFB0B0B0),   // secondary text
    textMuted: Color(0xFF888888),       // muted text
    borderDefault: Color(0x2BFFFFFF),   // white with 17% opacity
    borderHighlight: Color(0xFF00ADB5), // cyan accent
    linkAccent: Color(0xFF00ADB5),      // primary theme color
    targetAccent: Color(0xFFB026FF),    // purple accent
    statusActive: Color(0xFF00FF9D),    // green
    statusRemoved: Color(0xFFFF5F56),   // red
    statusChanged: Color(0xFFFFBD2E),   // orange
    brightness: Brightness.dark,
  );

  // Light theme colors (translucent for Aero Blur on Windows 10)
  static const light = AppColors(
    bgPrimary: Color(0x80FAFAFA),       // 50% opacity main background
    bgSecondary: Color(0xB3F3F3F3),     // 70% opacity sidebar
    bgTertiary: Color(0xCCEAEAEA),      // 80% opacity inputs/lists
    bgCard: Color(0xD9FFFFFF),          // 85% opacity cards
    bgHover: Color(0x1900ADB5),         // soft cyan hover highlight
    textPrimary: Color(0xFF1F1F1F),     // main text
    textSecondary: Color(0xFF757575),   // secondary text
    textMuted: Color(0xFF9E9E9E),       // muted text
    borderDefault: Color(0x26000000),   // black with 15% opacity
    borderHighlight: Color(0xFF00ADB5), // cyan accent
    linkAccent: Color(0xFF00ADB5),      // primary theme color
    targetAccent: Color(0xFF8B21E0),    // purple accent
    statusActive: Color(0xFF00B36E),    // green
    statusRemoved: Color(0xFFD32F2F),
    statusChanged: Color(0xFFE65100),
    brightness: Brightness.light,
  );
}
