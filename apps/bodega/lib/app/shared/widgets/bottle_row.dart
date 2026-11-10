import 'package:bodega/l10n/l10n.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/gradient.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/bottle.dart';
import 'package:flutter/material.dart';

/// A bottle in the sidebar: its name and apps count or, when compact, its icon.
class BottleRow extends StatelessWidget {
  final Bottle bottle;
  final bool selected;
  final bool isOpen;
  final bool expanded;

  /// Null while the library loads, so that the count isn't shown as 0.
  final int? appCount;
  final VoidCallback onTap;

  const BottleRow({
    super.key,
    required this.bottle,
    required this.selected,
    required this.isOpen,
    required this.expanded,
    required this.onTap,
    this.appCount,
  });

  String _state(AppLocalizations l10n) => !bottle.ready
      ? l10n.shellBottleIncomplete
      : isOpen
      ? l10n.shellBottleOpen
      : l10n.shellBottleClosed;

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final l10n = context.l10n;
    final state = _state(l10n);
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.onSurface : colors.onSurfaceVariant;
    final brand = AppGradient.brand;
    final tint = LinearGradient(
      begin: brand.begin,
      end: brand.end,
      colors: [for (final c in brand.colors) c.withValues(alpha: 0.16)],
      stops: brand.stops,
    );
    final count = appCount;

    final mark = bottle.ready
        ? Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOpen ? AppColor.statusTested : Colors.transparent,
              shape: BoxShape.circle,
            ),
          )
        : const Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: AppColor.statusFlaky,
          );

    return Semantics(
      button: true,
      selected: selected,
      label: l10n.shellBottleSemantics(bottle.name, state),
      excludeSemantics: true,
      child: Tooltip(
        message: expanded ? '' : l10n.shellBottleTooltip(bottle.name, state),
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
                padding: EdgeInsets.symmetric(
                  horizontal: expanded ? AppSpacing.md : AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: expanded
                    ? Row(
                        children: [
                          Icon(
                            Icons.wine_bar_rounded,
                            size: 18,
                            color: foreground,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              bottle.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: styles.body?.copyWith(
                                color: foreground,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (count != null) ...[
                            Text(
                              l10n.shellAppCount(count),
                              style: styles.caption,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          mark,
                        ],
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.wine_bar_rounded,
                            size: 20,
                            color: foreground,
                          ),
                          Positioned(right: 0, top: 0, child: mark),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
