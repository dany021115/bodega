import 'package:bodega/app/shared/text/game_text.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// A game's status, rating and backend here, as the catalog's chips are.
class GameChips extends StatelessWidget {
  final GameConfig game;

  const GameChips({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        StatusChip(
          label: l10n.gameStatusOf(game.status),
          color: switch (game.status) {
            GameStatus.verified => colors.primary,
            GameStatus.community => AppColor.statusReported,
            GameStatus.blocked => AppColor.statusBlocked,
          },
        ),
        if (game.status != GameStatus.blocked)
          StatusChip(
            label: l10n.ratingOf(game.rating),
            color: switch (game.rating) {
              GameRating.works => AppColor.statusTested,
              GameRating.playable => AppColor.statusFlaky,
              GameRating.broken || GameRating.blocked => AppColor.statusBlocked,
              null => AppColor.statusUntested,
            },
          ),
        if (game.backend case final backend?)
          StatusChip(label: backend, color: colors.secondary),
      ],
    );
  }
}
