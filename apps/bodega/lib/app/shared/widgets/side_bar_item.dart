import 'package:bodega/device/theme/gradient.dart';
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
    final foreground = selected ? colors.onSurface : colors.onSurfaceVariant;
    final brand = AppGradient.brand;
    final tint = LinearGradient(
      begin: brand.begin,
      end: brand.end,
      colors: [for (final c in brand.colors) c.withValues(alpha: 0.16)],
      stops: brand.stops,
    );

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
          color: Colors.transparent,
          borderRadius: AppRadius.xsBorder,
          child: Ink(
            decoration: BoxDecoration(
              gradient: selected ? tint : null,
              borderRadius: AppRadius.xsBorder,
              border: selected ? Border.all(color: colors.primary) : null,
            ),
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
      ),
    );
  }
}
