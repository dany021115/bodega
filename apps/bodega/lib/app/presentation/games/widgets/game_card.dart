import 'package:bodega/app/presentation/games/widgets/game_chips.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:flutter/material.dart';

class GameCard extends StatelessWidget {
  final GameConfig game;

  const GameCard({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: AppRadius.mdBorder,
        onTap: () => RouterManager.go(
          AppRoute.gameDetail,
          params: {'id': game.id},
          context: context,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      game.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle(context).cardTitle,
                    ),
                  ),
                  if (game.antiCheat.isNotEmpty)
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      semanticLabel: game.antiCheat.join(', '),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              GameChips(game: game),
            ],
          ),
        ),
      ),
    );
  }
}
