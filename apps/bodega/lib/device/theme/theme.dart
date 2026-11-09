import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData getLightTheme() => _buildTheme(Brightness.light);

  static ThemeData getDarkTheme() => _buildTheme(Brightness.dark);

  // === COLOR SCHEME ===

  static ColorScheme _colorScheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final text = dark ? AppColor.text : AppColor.textLight;
    final onAccent = dark ? AppColor.onAccent : AppColor.onAccentLight;
    final violet = dark ? AppColor.violet : AppColor.violetLight;
    final border = dark ? AppColor.border : AppColor.borderLight;

    return ColorScheme(
      brightness: brightness,
      primary: dark ? AppColor.cyan : AppColor.cyanLight,
      onPrimary: onAccent,
      primaryContainer: dark ? AppColor.blue : AppColor.blueLight,
      onPrimaryContainer: dark ? AppColor.text : AppColor.onAccentLight,
      secondary: violet,
      onSecondary: dark ? text : onAccent,
      tertiary: violet,
      onTertiary: dark ? text : onAccent,
      error: dark ? AppColor.error : AppColor.errorLight,
      onError: onAccent,
      surface: dark ? AppColor.background : AppColor.backgroundLight,
      onSurface: text,
      onSurfaceVariant: dark
          ? AppColor.textSecondary
          : AppColor.textSecondaryLight,
      surfaceContainerLow: dark
          ? AppColor.bottlePanel
          : AppColor.bottlePanelLight,
      surfaceContainer: dark ? AppColor.sidebar : AppColor.sidebarLight,
      surfaceContainerHigh: dark ? AppColor.surface : AppColor.surfaceLight,
      surfaceContainerHighest: dark
          ? AppColor.surface2
          : AppColor.surface2Light,
      outline: border,
      outlineVariant: border,
      shadow: Colors.black.withValues(alpha: dark ? 0.5 : 0.15),
      scrim: Colors.black.withValues(alpha: dark ? 0.6 : 0.4),
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

  static ThemeData _buildTheme(Brightness brightness) {
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
      inputDecorationTheme: _inputTheme(colors),
      filledButtonTheme: _filledButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
  }
}
