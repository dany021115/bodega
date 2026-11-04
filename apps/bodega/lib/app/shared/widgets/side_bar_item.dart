import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';

class SideBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  const SideBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;

    final content = Row(
      mainAxisAlignment: expanded
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: foreground),
        if (expanded) ...[
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle(context).body?.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: expanded ? '' : label,
        child: Material(
          color: selected ? colors.primaryContainer : Colors.transparent,
          borderRadius: AppRadius.xsBorder,
          child: InkWell(
            borderRadius: AppRadius.xsBorder,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
