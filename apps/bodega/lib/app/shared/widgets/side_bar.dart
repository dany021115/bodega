import 'package:bodega/app/bloc/theme/theme_bloc.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/widgets/side_bar_item.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SideBar extends StatelessWidget {
  final int selectedIndex;
  final bool expanded;

  const SideBar({
    super.key,
    required this.selectedIndex,
    required this.expanded,
  });

  static const _items = [
    (icon: Icons.apps_rounded, label: 'Biblioteca', route: AppRoute.library),
    (
      icon: Icons.storefront_rounded,
      label: 'Catálogo',
      route: AppRoute.catalog,
    ),
    (icon: Icons.wine_bar_rounded, label: 'Botellas', route: AppRoute.bottles),
    (icon: Icons.memory_rounded, label: 'Backends', route: AppRoute.backends),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = context.select((ThemeBloc bloc) => bloc.state.isDark);

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
                  child: Text(
                    'Bodega',
                    style: AppTextStyle(context).sectionTitle,
                  ),
                ),
              for (final (index, item) in _items.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: SideBarItem(
                    icon: item.icon,
                    label: item.label,
                    selected: index == selectedIndex,
                    expanded: expanded,
                    onTap: () => RouterManager.go(item.route, context: context),
                  ),
                ),
              const Spacer(),
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
