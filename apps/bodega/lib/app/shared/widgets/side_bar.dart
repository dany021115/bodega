import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/presentation/bottles/new_bottle_dialog.dart';
import 'package:bodega/app/presentation/settings/settings_dialog.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/widgets/app_version.dart';
import 'package:bodega/app/shared/widgets/bottle_row.dart';
import 'package:bodega/app/shared/widgets/side_bar_item.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/gradient.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:bodega/resources/assets_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SideBar extends StatefulWidget {
  /// The current path, which says what is selected.
  final String location;
  final bool expanded;

  const SideBar({super.key, required this.location, required this.expanded});

  @override
  State<SideBar> createState() => _SideBarState();
}

class _SideBarState extends State<SideBar> {
  @override
  void initState() {
    super.initState();
    context.read<BottlesBloc>().add(const BottlesEvent.load());
    // It also starts watching what is already open, whichever page comes first.
    context.read<LibraryBloc>().add(const LibraryEvent.load());
  }

  Widget _section(IconData icon, String label, AppRoute route, String prefix) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: SideBarItem(
          icon: icon,
          label: label,
          selected: widget.location.startsWith(prefix),
          expanded: widget.expanded,
          onTap: () => RouterManager.go(route, context: context),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final styles = AppTextStyle(context);
    final l10n = context.l10n;
    final expanded = widget.expanded;
    final bottles = context.select((BottlesBloc bloc) => bloc.state.bottles);
    final apps = context.select((LibraryBloc bloc) => bloc.state.apps);
    final loading = context.select((LibraryBloc bloc) => bloc.state.isLoading);
    final open = context.select((LibraryBloc bloc) => bloc.state.open);

    final counts = <String, int>{};
    for (final app in apps) {
      counts[app.bottle] = (counts[app.bottle] ?? 0) + 1;
    }

    return Container(
      width: expanded ? 220 : 68,
      color: colors.surfaceContainer,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: expanded ? AppSpacing.md : 0,
                  bottom: AppSpacing.lg,
                ),
                child: Row(
                  mainAxisAlignment: expanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      AssetsImages.logo,
                      width: 40,
                      height: 40,
                      excludeFromSemantics: true,
                    ),
                    if (expanded) ...[
                      const SizedBox(width: AppSpacing.md),
                      Text('Bodega', style: styles.sectionTitle),
                    ],
                  ],
                ),
              ),
              _section(
                Icons.apps_rounded,
                l10n.navLibrary,
                AppRoute.library,
                '/library',
              ),
              const SizedBox(height: AppSpacing.sm),
              if (expanded)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    bottom: AppSpacing.xs,
                  ),
                  child: Text(l10n.navBottles, style: styles.label),
                )
              else
                const Divider(),
              // The same dialog as the library's empty state: a bottle is
              // always created the same way.
              Tooltip(
                message: l10n.navNewBottle,
                // Ink paints on the nearest Material, which would sit under the
                // sidebar's own background and be hidden by it.
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: AppRadius.mdBorder,
                    onTap: () => showNewBottleDialog(context),
                    child: Ink(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppGradient.brand,
                        borderRadius: AppRadius.mdBorder,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 20,
                            color: colors.onPrimary,
                          ),
                          if (expanded) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                l10n.navNewBottle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: styles.body?.copyWith(
                                  color: colors.onPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView.builder(
                  itemCount: bottles.length,
                  itemBuilder: (context, index) {
                    final bottle = bottles[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: BottleRow(
                        bottle: bottle,
                        expanded: expanded,
                        isOpen: open.contains(bottle.name),
                        selected: widget.location == '/bottles/${bottle.name}',
                        appCount: loading ? null : counts[bottle.name] ?? 0,
                        onTap: () => RouterManager.go(
                          AppRoute.bottleDetail,
                          params: {'name': bottle.name},
                          context: context,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _section(
                Icons.memory_rounded,
                l10n.navBackends,
                AppRoute.backends,
                '/backends',
              ),
              // A dialog, not a page: it is never the selected item.
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: SideBarItem(
                  icon: Icons.settings_rounded,
                  label: l10n.navSettings,
                  selected: false,
                  expanded: expanded,
                  onTap: () => showSettingsDialog(context),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppVersion(compact: !expanded),
            ],
          ),
        ),
      ),
    );
  }
}
