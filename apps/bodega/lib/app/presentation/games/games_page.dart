import 'package:bodega/app/bloc/games/games_bloc.dart';
import 'package:bodega/app/presentation/games/widgets/game_card.dart';
import 'package:bodega/app/shared/text/error_text.dart';
import 'package:bodega/app/shared/text/game_text.dart';
import 'package:bodega/app/shared/widgets/copy_details_button.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/di.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Every game configuration (A2), with search and two filters.
class GamesPage extends StatelessWidget {
  const GamesPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => getIt<GamesBloc>()..add(const GamesEvent.load()),
    child: const GamesView(),
  );
}

class GamesView extends StatelessWidget {
  const GamesView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);

    return Scaffold(
      body: BlocBuilder<GamesBloc, GamesState>(
        builder: (context, state) {
          final bloc = context.read<GamesBloc>();
          final games = state.visibleGames;
          final backends = {
            for (final game in state.games) ?game.backend,
          }.toList()..sort();

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
                      Text(l10n.gamesTitle, style: styles.screenTitle),
                      const SizedBox(height: AppSpacing.sm),
                      Text(l10n.gamesIntro, style: styles.bodySecondary),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        initialValue: state.query,
                        decoration: InputDecoration(
                          hintText: l10n.gamesSearchHint,
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                        ),
                        onChanged: (query) =>
                            bloc.add(GamesEvent.search(query)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final rating in RatingFilter.values)
                            FilterChip(
                              label: Text(_ratingLabel(l10n, rating)),
                              selected: state.rating == rating,
                              onSelected: (_) =>
                                  bloc.add(GamesEvent.rating(rating)),
                            ),
                          for (final backend in backends)
                            FilterChip(
                              label: Text(backend),
                              selected: state.backend == backend,
                              onSelected: (_) =>
                                  bloc.add(GamesEvent.backend(backend)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (state.isLoading)
                const SliverToBoxAdapter(child: CustomLoading())
              else if (state.error case final error?)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SelectableText(
                          error.localized(l10n),
                          style: styles.body?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        CopyDetailsButton(error: error),
                      ],
                    ),
                  ),
                )
              else if (games.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(l10n.gamesNoMatch, style: styles.bodySecondary),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                  ),
                  sliver: SliverList.separated(
                    itemCount: games.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        GameCard(game: games[index]),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
          );
        },
      ),
    );
  }

  static String _ratingLabel(AppL10n l10n, RatingFilter rating) =>
      switch (rating) {
        RatingFilter.works => l10n.ratingOf(GameRating.works),
        RatingFilter.playable => l10n.ratingOf(GameRating.playable),
        RatingFilter.broken => l10n.ratingOf(GameRating.broken),
        RatingFilter.blocked => l10n.ratingOf(GameRating.blocked),
        RatingFilter.none => l10n.ratingOf(null),
      };
}
