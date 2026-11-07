import 'package:bodega/app/shared/widgets/app_icon.dart';
import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:flutter/material.dart';

/// An application as a list row. A double click plays it, and the menu button
/// or a right click asks the owner for its menu.
class AppRow extends StatelessWidget {
  final LibraryApp app;
  final String? bottleLabel;
  final bool running;

  /// Replaces the bottle label in the row.
  final Widget? footerChip;
  final VoidCallback onPlay;
  final VoidCallback onStop;

  /// Gets the context of the menu button: the menu always opens beside it.
  final ValueChanged<BuildContext>? onMenu;

  const AppRow({
    super.key,
    required this.app,
    required this.running,
    required this.onPlay,
    required this.onStop,
    this.bottleLabel,
    this.footerChip,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = AppTextStyle(context);
    final menu = onMenu;
    // Set by the button's Builder, so a right click opens the menu in the same
    // place as the button does.
    BuildContext? anchor;
    final label = bottleLabel;
    final chip =
        footerChip ??
        (label == null
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: AppRadius.xsBorder,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.caption,
                ),
              ));

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: AppRadius.mdBorder,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          // Only the information is inside the gesture area: the buttons
          // must answer their own taps, not wait for a double click.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: running ? null : onPlay,
              onSecondaryTapUp: menu == null
                  ? null
                  : (_) => menu(anchor ?? context),
              child: Semantics(
                button: true,
                label: app.title,
                hint: 'Doble toque para abrir',
                onTap: running ? null : onPlay,
                child: Row(
                  children: [
                    AppIcon(
                      id: app.id,
                      title: app.title,
                      iconPath: app.iconPath,
                      size: 40,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        app.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.cardTitle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (chip != null) ...[
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: chip,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: running
                            ? AppColor.statusTested
                            : AppColor.statusUntested,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        running ? 'En ejecución' : 'Cerrada',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.caption?.copyWith(
                          color: running
                              ? AppColor.statusTested
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ),
          GradientButton(
            label: running ? 'Parar' : 'Jugar',
            icon: running ? Icons.stop_rounded : Icons.play_arrow_rounded,
            onPressed: running ? onStop : onPlay,
          ),
          if (menu != null)
            Builder(
              builder: (button) {
                anchor = button;
                return IconButton(
                  tooltip: 'Opciones de ${app.title}',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onPressed: () => menu(button),
                );
              },
            ),
        ],
      ),
    );
  }
}
