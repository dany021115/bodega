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
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.fillColored,
      title: Semantics(liveRegion: true, child: Text(message, maxLines: 4)),
      autoCloseDuration: const Duration(seconds: 5),
      alignment: Alignment.topRight,
      showProgressBar: false,
      dragToClose: true,
    );
  }
}
