import 'package:flutter/material.dart';

abstract class AppColor {
  // === PRIMARY (burdeos) ===
  static const Color primaryDark = Color(0xFFE58AA0);
  static const Color onPrimaryDark = Color(0xFF3A0A18);
  static const Color primaryContainerDark = Color(0xFF6E1F35);
  static const Color onPrimaryContainerDark = Color(0xFFFFE3EA);

  static const Color primaryLight = Color(0xFF8E2442);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color primaryContainerLight = Color(0xFFFADDE4);
  static const Color onPrimaryContainerLight = Color(0xFF3A0A18);

  // === SURFACES ===
  static const Color surfaceDark = Color(0xFF17171A);
  static const Color surfaceContainerDark = Color(0xFF1F1F23);
  static const Color surfaceContainerHighDark = Color(0xFF29292E);
  static const Color surfaceContainerHighestDark = Color(0xFF34343A);
  static const Color onSurfaceDark = Color(0xFFF2F2F4);
  static const Color onSurfaceVariantDark = Color(0xFFA9A9B2);
  static const Color outlineDark = Color(0xFF3D3D44);

  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color surfaceContainerLight = Color(0xFFF2F2F3);
  static const Color surfaceContainerHighLight = Color(0xFFE8E8EA);
  static const Color surfaceContainerHighestLight = Color(0xFFDDDDE0);
  static const Color onSurfaceLight = Color(0xFF1A1A1E);
  static const Color onSurfaceVariantLight = Color(0xFF5E5E66);
  static const Color outlineLight = Color(0xFFD2D2D6);

  // === FEEDBACK ===
  static const Color errorDark = Color(0xFFFF8A80);
  static const Color onErrorDark = Color(0xFF3B0A06);
  static const Color errorLight = Color(0xFFC62828);
  static const Color onErrorLight = Color(0xFFFFFFFF);

  // === CATALOG STATUS ===
  static const Color statusTested = Color(0xFF4CAF50);
  static const Color statusReported = Color(0xFF42A5F5);
  static const Color statusUntested = Color(0xFF9E9EA6);
  static const Color statusBlocked = Color(0xFFEF5350);
  static const Color statusFlaky = Color(0xFFFFB300);
}
