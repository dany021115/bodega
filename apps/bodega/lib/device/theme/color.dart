import 'package:flutter/material.dart';

abstract class AppColor {
  // === BASE (dark theme, the only one) ===
  static const Color background = Color(0xFF070B1A);
  static const Color sidebar = Color(0xFF0B1126);
  static const Color bottlePanel = Color(0xFF0A1030);
  static const Color surface = Color(0xFF10183A);
  static const Color surface2 = Color(0xFF172250);
  static const Color border = Color(0xFF222F66);
  static const Color text = Color(0xFFEAF0FF);
  static const Color textSecondary = Color(0xFF8C9BC8);
  static const Color onAccent = Color(0xFF04111F);

  // === ACCENTS ===
  static const Color cyan = Color(0xFF22D3EE);
  static const Color blue = Color(0xFF3B82F6);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color error = Color(0xFFF87171);

  // === LIGHT ===
  // The same neon accents, darker so that they read on white (4.5:1 or more).
  static const Color backgroundLight = Color(0xFFF5F7FF);
  static const Color sidebarLight = Color(0xFFEDF1FC);
  static const Color bottlePanelLight = Color(0xFFF0F3FD);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surface2Light = Color(0xFFE6EBFA);
  static const Color borderLight = Color(0xFFCBD3EE);
  static const Color textLight = Color(0xFF0B1126);
  static const Color textSecondaryLight = Color(0xFF4A5680);
  static const Color onAccentLight = Color(0xFFFFFFFF);
  static const Color cyanLight = Color(0xFF0E7490);
  static const Color blueLight = Color(0xFF2563EB);
  static const Color violetLight = Color(0xFF7C3AED);
  static const Color errorLight = Color(0xFFDC2626);

  // === CATALOG STATUS ===
  static const Color statusTested = Color(0xFF34D399);
  static const Color statusReported = Color(0xFF42A5F5);
  static const Color statusUntested = Color(0xFF9E9EA6);
  static const Color statusBlocked = Color(0xFFEF5350);
  static const Color statusFlaky = Color(0xFFFFB300);

  // === CATALOG BRANDS (simple-icons); the black ones use the theme's color ===
  static const Color brandRockstar = Color(0xFFFCAF17);
  static const Color brandBattleNet = Color(0xFF4381C3);
  static const Color brandGog = Color(0xFF86328A);
}
