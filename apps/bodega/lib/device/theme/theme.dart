import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData getDarkTheme() => _buildTheme();

  // === COLOR SCHEME ===

  static final ColorScheme _colors = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColor.cyan,
    onPrimary: AppColor.onAccent,
    primaryContainer: AppColor.blue,
    onPrimaryContainer: AppColor.text,
    secondary: AppColor.violet,
    onSecondary: AppColor.text,
    tertiary: AppColor.violet,
    onTertiary: AppColor.text,
    error: AppColor.error,
    onError: AppColor.onAccent,
    surface: AppColor.background,
    onSurface: AppColor.text,
    onSurfaceVariant: AppColor.textSecondary,
    surfaceContainerLow: AppColor.bottlePanel,
    surfaceContainer: AppColor.sidebar,
    surfaceContainerHigh: AppColor.surface,
    surfaceContainerHighest: AppColor.surface2,
    outline: AppColor.border,
    outlineVariant: AppColor.border,
    shadow: Colors.black.withValues(alpha: 0.5),
    scrim: Colors.black.withValues(alpha: 0.6),
  );

  // === COMPONENT THEMES ===

  static InputDecorationTheme get _inputTheme => InputDecorationTheme(
    filled: true,
    fillColor: _colors.surfaceContainerHigh,
    border: OutlineInputBorder(
      borderRadius: AppRadius.xsBorder,
      borderSide: BorderSide(color: _colors.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.xsBorder,
      borderSide: BorderSide(color: _colors.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.xsBorder,
      borderSide: BorderSide(color: _colors.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );

  static final FilledButtonThemeData _filledButtonTheme = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.xsBorder),
    ),
  );

  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.xsBorder),
        ),
      );

  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.xsBorder),
    ),
  );

  // === THEME BUILDER ===

  static ThemeData _buildTheme() {
    final colors = _colors;

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
      ),
      cardTheme: CardThemeData(
        color: colors.surfaceContainerHigh,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
          side: BorderSide(color: colors.outline.withValues(alpha: 0.5)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: colors.onSurface),
        actionTextColor: colors.primary,
      ),
      dividerTheme: DividerThemeData(
        color: colors.outline.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: _inputTheme,
      filledButtonTheme: _filledButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
  }
}
