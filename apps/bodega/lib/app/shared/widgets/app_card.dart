import 'package:bodega/app/shared/widgets/app_icon.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/gradient.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The covers of the design. An app keeps the same pair, as its id picks it.
const List<(Color, Color)> _covers = [
  (Color(0xFF8B5CF6), Color(0xFFF43F5E)),
  (Color(0xFF22D3EE), Color(0xFF2563EB)),
  (Color(0xFF38BDF8), Color(0xFF6366F1)),
  (Color(0xFF34D399), Color(0xFF0EA5E9)),
  (Color(0xFFF59E0B), Color(0xFFEF4444)),
  (Color(0xFFA78BFA), Color(0xFFEC4899)),
  (Color(0xFF312E81), Color(0xFF8B5CF6)),
  (Color(0xFFFACC15), Color(0xFFF97316)),
  (Color(0xFF22D3EE), Color(0xFF475569)),
  (Color(0xFFEF4444), Color(0xFF7C2D12)),
];

/// An application as a grid card. A double click plays it, and the menu
/// button or a right click asks the owner for its menu.
class AppCard extends StatelessWidget {
  static const double coverHeight = 128;

  /// The height a grid cell needs for a card: the cover, and the title and
  /// footer rows (about 100 px, as tall as the text scale makes them). Grids
  /// use it as `mainAxisExtent`, so the card has no spare room below.
  static double extent(BuildContext context) =>
      coverHeight + MediaQuery.textScalerOf(context).scale(100);

  final LibraryApp app;
  final String? bottleLabel;
  final bool running;

  /// What its exe draws with, like `DX9 · 32 bits` (G2).
  final String? graphics;

  /// Replaces the bottle label in the footer.
  final Widget? footerChip;
  final VoidCallback onPlay;
  final VoidCallback onStop;

  /// Gets the context of the menu button: the menu always opens beside it.
  final ValueChanged<BuildContext>? onMenu;

  const AppCard({
    super.key,
    required this.app,
    required this.running,
    required this.onPlay,
    required this.onStop,
    this.bottleLabel,
    this.footerChip,
    this.graphics,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = AppTextStyle(context);
    final l10n = context.l10n;
    final (from, to) = _covers[app.id.hashCode % _covers.length];
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The menu and play buttons sit outside this gesture area: inside it,
          // a double click would wait for the buttons' own taps.
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
                hint: l10n.appOpenHint,
                onTap: running ? null : onPlay,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The cover takes what the title and footer leave, so the
                    // card fits its cell whatever the font makes of those rows.
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppGradient.cover(from, to),
                            ),
                          ),
                          AppIcon(
                            id: app.id,
                            title: app.title,
                            iconPath: app.iconPath,
                            size: 64,
                          ),
                          if (graphics case final graphics?)
                            Positioned(
                              top: AppSpacing.sm,
                              right: AppSpacing.sm,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xxs,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surface.withValues(alpha: 0.8),
                                  borderRadius: AppRadius.xsBorder,
                                ),
                                child: Text(graphics, style: styles.caption),
                              ),
                            ),
                          if (running)
                            Positioned(
                              top: AppSpacing.sm,
                              left: AppSpacing.sm,
                              child: StatusChip(
                                label: l10n.appRunning,
                                color: AppColor.statusTested,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        0,
                      ),
                      child: Text(
                        app.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.cardTitle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: chip ?? const SizedBox.shrink(),
                  ),
                ),
                Tooltip(
                  message: running ? l10n.commonStop : l10n.commonPlay,
                  child: Ink(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: running ? null : AppGradient.brand,
                      color: running ? colors.surfaceContainerHighest : null,
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: running ? onStop : onPlay,
                      child: Icon(
                        running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        size: 18,
                        color: running ? colors.onSurface : colors.onPrimary,
                      ),
                    ),
                  ),
                ),
                if (menu != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Builder(
                    builder: (button) {
                      anchor = button;
                      return IconButton(
                        tooltip: l10n.appOptions(app.title),
                        // As small as the play button, so the chip has room.
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        iconSize: 18,
                        icon: const Icon(Icons.more_horiz_rounded),
                        onPressed: () => menu(button),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
