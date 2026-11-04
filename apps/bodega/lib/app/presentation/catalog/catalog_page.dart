import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/presentation/catalog/widgets/anti_cheat_section.dart';
import 'package:bodega/app/presentation/catalog/widgets/catalog_card.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:responsive_framework/responsive_framework.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  @override
  void initState() {
    super.initState();
    context.read<CatalogBloc>().add(const CatalogEvent.load());
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final columns = ResponsiveBreakpoints.of(context).largerOrEqualTo(DESKTOP)
        ? 2
        : 1;

    return Scaffold(
      body: BlocBuilder<CatalogBloc, CatalogState>(
        builder: (context, state) {
          final apps = state.visibleApps;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                  AppSpacing.lg,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Catálogo', style: styles.screenTitle),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        initialValue: state.query,
                        decoration: const InputDecoration(
                          hintText: 'Buscar una aplicación o un juego',
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
                        ),
                        onChanged: (query) => context.read<CatalogBloc>().add(
                          CatalogEvent.search(query),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (state.isLoading)
                const SliverToBoxAdapter(child: CustomLoading())
              else ...[
                if (state.error case final error?)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: SelectableText(
                        error.message,
                        style: styles.body?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                  ),
                  sliver: SliverList.separated(
                    itemCount: (apps.length / columns).ceil(),
                    separatorBuilder: (context, row) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, row) {
                      final cards = apps.skip(row * columns).take(columns);
                      // As tall as the tallest card of the row, whatever its
                      // chips need.
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (
                              var column = 0;
                              column < columns;
                              column++
                            ) ...[
                              if (column > 0)
                                const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: column < cards.length
                                    ? CatalogCard(app: cards.elementAt(column))
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (apps.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'Ninguna aplicación del catálogo coincide.',
                        style: styles.bodySecondary,
                      ),
                    ),
                  ),
                if (state.showsAntiCheat)
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    sliver: SliverToBoxAdapter(
                      child: AntiCheatSection(state: state),
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          );
        },
      ),
    );
  }
}
