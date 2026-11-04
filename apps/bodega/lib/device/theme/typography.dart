import 'package:flutter/material.dart';

class AppTextStyle {
  /// null makes Flutter use the system font, SF Pro on macOS.
  static String? get fontFamily => null;

  /// Fixed width, for logs and commands.
  static const String monoFamily = 'Menlo';

  final BuildContext context;

  AppTextStyle(this.context);

  TextTheme get textTheme => Theme.of(context).textTheme;

  ColorScheme get colorScheme => Theme.of(context).colorScheme;

  TextStyle? get screenTitle => textTheme.headlineLarge?.copyWith(
    color: colorScheme.onSurface,
    fontWeight: FontWeight.w700,
    fontSize: 28,
    height: 1.2,
  );

  TextStyle? get sectionTitle => textTheme.headlineMedium?.copyWith(
    color: colorScheme.onSurface,
    fontWeight: FontWeight.w600,
    fontSize: 20,
    height: 1.3,
  );

  TextStyle? get subsectionTitle => textTheme.titleLarge?.copyWith(
    color: colorScheme.onSurface,
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 1.3,
  );

  TextStyle? get cardTitle => textTheme.titleLarge?.copyWith(
    color: colorScheme.onSurface,
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 1.4,
  );

  TextStyle? get body => textTheme.bodyMedium?.copyWith(
    color: colorScheme.onSurface,
    fontSize: 14,
    height: 1.45,
  );

  TextStyle? get bodySecondary => textTheme.bodyMedium?.copyWith(
    color: colorScheme.onSurfaceVariant,
    fontSize: 14,
    height: 1.45,
  );

  TextStyle? get caption => textTheme.bodySmall?.copyWith(
    color: colorScheme.onSurfaceVariant,
    fontSize: 12,
    height: 1.4,
  );

  TextStyle? get label => textTheme.labelMedium?.copyWith(
    fontWeight: FontWeight.w600,
    fontSize: 12,
    height: 1.3,
  );

  TextStyle? get mono => textTheme.bodySmall?.copyWith(
    fontFamily: monoFamily,
    color: colorScheme.onSurface,
    fontSize: 12,
    height: 1.45,
  );
}
