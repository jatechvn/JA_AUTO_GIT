// lib/modules/ui/styles_win11.dart
import 'package:flutter/material.dart';
import 'styles.dart';

class StylesWin11 {
  // Dark theme colors (transparent for Acrylic blur on Windows 11)
  static const dark = AppColors(
    bgPrimary: Color(0x1A000000),       // 10% opacity main background
    bgSecondary: Color(0x331C1C1C),     // 20% opacity sidebar
    bgTertiary: Color(0x40252525),      // 25% opacity inputs/lists
    bgCard: Color(0x592D2D2D),          // 35% opacity cards
    bgHover: Color(0x1F00ADB5),         // soft cyan hover highlight
    textPrimary: Color(0xFFFFFFFF),     // main text
    textSecondary: Color(0xFFCCCCCC),   // secondary text
    textMuted: Color(0xFF999999),       // muted text
    borderDefault: Color(0x2BFFFFFF),   // white with 17% opacity
    borderHighlight: Color(0xFF00ADB5), // cyan accent
    linkAccent: Color(0xFF00ADB5),      // primary theme color
    targetAccent: Color(0xFFB026FF),    // purple accent
    statusActive: Color(0xFF00FF9D),    // green
    statusRemoved: Color(0xFFFF5F56),   // red
    statusChanged: Color(0xFFFFBD2E),   // orange
    brightness: Brightness.dark,
  );

  // Light theme colors (transparent for Acrylic blur on Windows 11)
  static const light = AppColors(
    bgPrimary: Color(0x1AFAFAFA),       // 10% opacity main background
    bgSecondary: Color(0x33E5E5E5),     // 20% opacity sidebar
    bgTertiary: Color(0x40EAEAEA),      // 25% opacity inputs/lists
    bgCard: Color(0x59FFFFFF),          // 35% opacity cards
    bgHover: Color(0x1900ADB5),         // soft cyan hover highlight
    textPrimary: Color(0xFF000000),     // main text
    textSecondary: Color(0xFF555555),   // secondary text
    textMuted: Color(0xFF777777),       // muted text
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
