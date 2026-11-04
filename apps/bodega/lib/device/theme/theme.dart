import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData getLightTheme() => _buildBaseTheme(Brightness.light);

  static ThemeData getDarkTheme() => _buildBaseTheme(Brightness.dark);

  // === COLOR SCHEMES ===

  static ColorScheme _colorScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ColorScheme(
      brightness: brightness,
      primary: isDark ? AppColor.primaryDark : AppColor.primaryLight,
      onPrimary: isDark ? AppColor.onPrimaryDark : AppColor.onPrimaryLight,
      primaryContainer: isDark
          ? AppColor.primaryContainerDark
          : AppColor.primaryContainerLight,
      onPrimaryContainer: isDark
          ? AppColor.onPrimaryContainerDark
          : AppColor.onPrimaryContainerLight,
      secondary: isDark ? AppColor.primaryDark : AppColor.primaryLight,
      onSecondary: isDark ? AppColor.onPrimaryDark : AppColor.onPrimaryLight,
      error: isDark ? AppColor.errorDark : AppColor.errorLight,
      onError: isDark ? AppColor.onErrorDark : AppColor.onErrorLight,
      surface: isDark ? AppColor.surfaceDark : AppColor.surfaceLight,
      onSurface: isDark ? AppColor.onSurfaceDark : AppColor.onSurfaceLight,
      onSurfaceVariant: isDark
          ? AppColor.onSurfaceVariantDark
          : AppColor.onSurfaceVariantLight,
      surfaceContainer: isDark
          ? AppColor.surfaceContainerDark
          : AppColor.surfaceContainerLight,
      surfaceContainerHigh: isDark
          ? AppColor.surfaceContainerHighDark
          : AppColor.surfaceContainerHighLight,
      surfaceContainerHighest: isDark
          ? AppColor.surfaceContainerHighestDark
          : AppColor.surfaceContainerHighestLight,
      outline: isDark ? AppColor.outlineDark : AppColor.outlineLight,
      outlineVariant: isDark ? AppColor.outlineDark : AppColor.outlineLight,
      shadow: Colors.black.withValues(alpha: 0.1),
      scrim: Colors.black.withValues(alpha: 0.5),
    );
  }

  // === COMPONENT THEMES ===

  static InputDecorationTheme _inputTheme(ColorScheme colors) =>
      InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: AppRadius.xsBorder,
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.xsBorder,
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.xsBorder,
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
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

  static ThemeData _buildBaseTheme(Brightness brightness) {
    final colors = _colorScheme(brightness);

    return ThemeData(
      brightness: brightness,
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
        color: colors.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
          side: BorderSide(color: colors.outline.withValues(alpha: 0.5)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outline.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: _inputTheme(colors),
      filledButtonTheme: _filledButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
  }
}
