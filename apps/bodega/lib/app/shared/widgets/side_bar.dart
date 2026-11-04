import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/theme/theme_bloc.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/widgets/bottle_row.dart';
import 'package:bodega/app/shared/widgets/side_bar_item.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
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
    final expanded = widget.expanded;
    final isDark = context.select((ThemeBloc bloc) => bloc.state.isDark);
    final open = context.select((LibraryBloc bloc) => bloc.state.open);
    final bottles = context.select((BottlesBloc bloc) => bloc.state.bottles);

    return Container(
      width: expanded ? 220 : 68,
      color: colors.surfaceContainer,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (expanded)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    bottom: AppSpacing.lg,
                  ),
                  child: Text('Bodega', style: styles.sectionTitle),
                ),
              _section(
                Icons.apps_rounded,
                'Biblioteca',
                AppRoute.library,
                '/library',
              ),
              _section(
                Icons.storefront_rounded,
                'Instalar',
                AppRoute.catalog,
                '/catalog',
              ),
              const SizedBox(height: AppSpacing.sm),
              if (expanded)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    bottom: AppSpacing.xs,
                  ),
                  child: Text('Botellas', style: styles.label),
                )
              else
                const Divider(),
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
                'Backends',
                AppRoute.backends,
                '/backends',
              ),
              SideBarItem(
                icon: isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                label: isDark ? 'Tema claro' : 'Tema oscuro',
                selected: false,
                expanded: expanded,
                onTap: () =>
                    context.read<ThemeBloc>().add(const ThemeEvent.toggle()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
