import 'package:bodega/app/bloc/game_detail/game_detail_bloc.dart';
import 'package:bodega/app/presentation/catalog/widgets/detail_section.dart';
import 'package:bodega/app/presentation/games/widgets/anti_cheat_banner.dart';
import 'package:bodega/app/presentation/games/widgets/game_changes.dart';
import 'package:bodega/app/presentation/games/widgets/game_chips.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/text/game_text.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/di.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

/// A game's page (A3).
class GameDetailPage extends StatelessWidget {
  final String id;

  const GameDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(id),
    create: (_) => getIt<GameDetailBloc>()..add(GameDetailEvent.load(id)),
    child: GameDetailView(id: id),
  );
}

class GameDetailView extends StatelessWidget {
  final String id;

  const GameDetailView({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    void back() => RouterManager.go(AppRoute.games, context: context);

    return Scaffold(
      body: BlocBuilder<GameDetailBloc, GameDetailState>(
        builder: (context, state) {
          if (state.isLoading) return const CustomLoading();
          final game = state.game;
          if (game == null) {
            return EmptyState(
              icon: Icons.search_off_rounded,
              title: l10n.gamesNoMatch,
              message: id,
              actionLabel: l10n.gamesAllGames,
              onAction: back,
            );
          }
          final ours = game.sourceUrl == null;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: back,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(l10n.gamesAllGames),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(game.title, style: styles.screenTitle),
              const SizedBox(height: AppSpacing.xs),
              GameChips(game: game),
              if (game.antiCheatVerdict case final verdict?) ...[
                const SizedBox(height: AppSpacing.lg),
                AntiCheatBanner(verdict: verdict, names: game.antiCheat),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (game.reports > 0) ...[
                Text(
                  l10n.gamesReports(
                    game.reports,
                    l10n.ratingOf(game.rating),
                    game.lastReport ?? '',
                  ),
                  style: styles.body,
                ),
                if (!ours)
                  Text(l10n.gamesReportsSource, style: styles.bodySecondary),
              ] else
                Text(l10n.gamesNoReports, style: styles.bodySecondary),
              if (game.nativeMac) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.gamesNativeMac, style: styles.body),
              ],
              DetailSection(
                title: l10n.gamesChangesTitle,
                children: [
                  GameChanges(
                    backend: game.backend,
                    steps: game.steps,
                    requires: game.requires,
                  ),
                ],
              ),
              if (game.notes.isNotEmpty || game.knownIssues.isNotEmpty)
                DetailSection(
                  title: ours ? l10n.gamesNotesBodega : l10n.gamesNotesHighball,
                  children: [
                    for (final note in game.notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: SelectableText(note, style: styles.body),
                      ),
                    if (game.knownIssues.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(l10n.gamesKnownIssues, style: styles.cardTitle),
                      const SizedBox(height: AppSpacing.xs),
                      for (final issue in game.knownIssues)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(issue.symptom, style: styles.body),
                              if (issue.fix.isNotEmpty)
                                SelectableText(
                                  issue.fix,
                                  style: styles.bodySecondary,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxl),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  children: [
                    Text(
                      ours ? l10n.gamesSourceBodega : l10n.gamesSourceHighball,
                      style: styles.caption,
                    ),
                    if (game.sourceUrl case final url?)
                      TextButton(
                        onPressed: () => launchUrl(Uri.parse(url)),
                        child: Text(l10n.gamesSourceOpen),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
