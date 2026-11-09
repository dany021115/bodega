import 'package:bodega/device/theme/gradient.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';

/// One of the two ways to add a program from a .exe, as a selectable card.
class InstallerChoice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const InstallerChoice({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = AppTextStyle(context);

    return Semantics(
      button: true,
      selected: selected,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: InkWell(
          borderRadius: AppRadius.mdBorder,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: selected ? AppGradient.brand : null,
                    color: selected ? null : colors.surfaceContainerHigh,
                    borderRadius: AppRadius.smBorder,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: styles.cardTitle),
                      const SizedBox(height: AppSpacing.xs),
                      Text(description, style: styles.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
