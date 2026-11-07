import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';

/// Whether the library shows an application. Off, it still belongs to its
/// bottle.
class LibraryToggle extends StatelessWidget {
  final bool inLibrary;
  final VoidCallback onPressed;

  const LibraryToggle({
    super.key,
    required this.inLibrary,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = inLibrary ? AppColor.cyan : colors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: inLibrary,
      child: Material(
        color: inLibrary
            ? AppColor.cyan.withValues(alpha: 0.12)
            : colors.surfaceContainerHighest,
        borderRadius: AppRadius.xsBorder,
        child: InkWell(
          borderRadius: AppRadius.xsBorder,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            // Scales down when the footer is tight, instead of overflowing.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      inLibrary
                          ? Icons.bookmark_added_rounded
                          : Icons.bookmark_add_outlined,
                      size: 14,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    inLibrary ? 'En biblioteca' : 'Agregar a biblioteca',
                    maxLines: 1,
                    style: AppTextStyle(context).caption
                        ?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
