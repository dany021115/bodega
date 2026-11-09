import 'package:bodega/device/theme/gradient.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:flutter/material.dart';

/// Switches the library between its grid and its list. The chosen one is in
/// the brand gradient.
class ViewToggle extends StatelessWidget {
  final bool isGrid;
  final ValueChanged<bool> onChanged;

  const ViewToggle({super.key, required this.isGrid, required this.onChanged});

  Widget _option(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected ? AppGradient.brand : null,
            borderRadius: AppRadius.xsBorder,
          ),
          child: InkWell(
            borderRadius: AppRadius.xsBorder,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Icon(
                icon,
                size: 18,
                color: selected ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: AppRadius.smBorder,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _option(
              context,
              icon: Icons.grid_view_rounded,
              tooltip: 'Vista en cuadrícula',
              selected: isGrid,
              onTap: () => onChanged(true),
            ),
            _option(
              context,
              icon: Icons.view_list_rounded,
              tooltip: 'Vista en lista',
              selected: !isGrid,
              onTap: () => onChanged(false),
            ),
          ],
        ),
      ),
    );
  }
}
