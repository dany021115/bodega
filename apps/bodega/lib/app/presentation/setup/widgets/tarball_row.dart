import 'package:bodega/l10n/l10n.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';

class TarballRow extends StatelessWidget {
  final String label;
  final String? path;
  final VoidCallback? onPick;

  const TarballRow({
    super.key,
    required this.label,
    required this.path,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: styles.cardTitle),
              Text(
                path?.split('/').last ?? context.l10n.setupNotChosen,
                overflow: TextOverflow.ellipsis,
                style: styles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        OutlinedButton(
          onPressed: onPick,
          child: Text(context.l10n.commonChooseFile),
        ),
      ],
    );
  }
}
