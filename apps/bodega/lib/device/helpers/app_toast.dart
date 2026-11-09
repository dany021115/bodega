import 'package:bodega/device/theme/color.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

abstract class AppToast {
  static void error(BuildContext context, String message) {
    _show(context, message, ToastificationType.error);
  }

  static void success(BuildContext context, String message) {
    _show(context, message, ToastificationType.success);
  }

  static void warning(BuildContext context, String message) {
    _show(context, message, ToastificationType.warning);
  }

  static void info(BuildContext context, String message) {
    _show(context, message, ToastificationType.info);
  }

  static void _show(
    BuildContext context,
    String message,
    ToastificationType type,
  ) {
    final colors = Theme.of(context).colorScheme;
    final accent = switch (type) {
      ToastificationType.success => AppColor.statusTested,
      ToastificationType.error => colors.error,
      ToastificationType.warning => AppColor.statusFlaky,
      _ => colors.primary,
    };
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flat,
      backgroundColor: colors.surfaceContainerHigh,
      foregroundColor: colors.onSurface,
      primaryColor: accent,
      borderSide: BorderSide(color: accent),
      title: Semantics(liveRegion: true, child: Text(message, maxLines: 4)),
      autoCloseDuration: const Duration(seconds: 5),
      alignment: Alignment.topRight,
      showProgressBar: false,
      dragToClose: true,
    );
  }
}
