import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/bottle.dart';
import 'package:flutter/material.dart';

/// A bottle in the sidebar: its name or, when compact, its initial.
class BottleRow extends StatelessWidget {
  final Bottle bottle;
  final bool selected;
  final bool isOpen;
  final bool expanded;
  final VoidCallback onTap;

  const BottleRow({
    super.key,
    required this.bottle,
    required this.selected,
    required this.isOpen,
    required this.expanded,
    required this.onTap,
  });

  String get _state => !bottle.ready
      ? 'incompleta'
      : isOpen
      ? 'abierta'
      : 'cerrada';

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    final initial = bottle.name.characters.first.toUpperCase();

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
      label: 'Botella ${bottle.name}, $_state',
      excludeSemantics: true,
      child: Tooltip(
        message: expanded ? '' : '${bottle.name} ($_state)',
        child: Material(
          color: selected ? colors.primaryContainer : Colors.transparent,
          borderRadius: AppRadius.xsBorder,
          child: InkWell(
            borderRadius: AppRadius.xsBorder,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
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
                        const SizedBox(width: AppSpacing.sm),
                        mark,
                      ],
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          initial,
                          style: styles.body?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Positioned(right: 0, top: 0, child: mark),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
