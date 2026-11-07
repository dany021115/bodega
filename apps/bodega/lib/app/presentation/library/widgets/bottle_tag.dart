import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';

/// The bottle's name on an application, with the anti-cheat hints of the bottle
/// when there are any.
class BottleTag extends StatelessWidget {
  final String bottle;
  final List<String> hints;

  const BottleTag({super.key, required this.bottle, required this.hints});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = AppTextStyle(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: AppRadius.xsBorder,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              child: Text(
                bottle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.caption,
              ),
            ),
          ),
        ),
        if (hints.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.sm),
          Tooltip(
            message: hints.join('\n'),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: colors.error,
            ),
          ),
        ],
      ],
    );
  }
}
