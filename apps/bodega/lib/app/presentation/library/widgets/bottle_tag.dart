import 'package:bodega/app/shared/text/hint_text.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/run_hint.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The bottle's name on an application, with the hints of the bottle's runs
/// when there are any.
class BottleTag extends StatelessWidget {
  final String bottle;
  final List<RunHint> hints;

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
            message: hints
                .map((hint) => hint.localized(context.l10n))
                .join('\n'),
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
