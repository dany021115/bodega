import 'package:bodega/device/helpers/app_toast.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "Copy details" under an error: puts the error's [AppError.detail] on the
/// clipboard, for a bug report, and toasts that it did.
///
/// The detail is the raw text behind the code (the engine's English message, a
/// tool's stderr, Dio's text), so it is never shown (L9, E13): this button is
/// all the screen has of it, and an error without one gets no button. It sits
/// at the start of the line, under the error's text.
class CopyDetailsButton extends StatelessWidget {
  final AppError error;

  const CopyDetailsButton({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final detail = error.detail;
    if (detail == null) return const SizedBox.shrink();
    // Read before the await: the toast comes after it.
    final l10n = context.l10n;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: detail));
          if (context.mounted) AppToast.success(context, l10n.commonCopied);
        },
        icon: const Icon(Icons.copy_rounded, size: 18),
        label: Text(l10n.commonCopyDetails),
      ),
    );
  }
}
