import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/anti_cheat_game.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// What the anti-cheat list says about the game being searched (P5).
class AntiCheatSection extends StatelessWidget {
  final CatalogState state;

  const AntiCheatSection({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.catalogAntiCheat, style: styles.subsectionTitle),
        const SizedBox(height: AppSpacing.sm),
        if (state.antiCheatError != null)
          Text(
            context.l10n.catalogAntiCheatLoadFailed,
            style: styles.bodySecondary,
          ),
        for (final game in state.antiCheatMatches)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game.title, style: styles.cardTitle),
                      Text(game.anticheats.join(', '), style: styles.caption),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                if (game.verdict == AntiCheatVerdict.blocked)
                  StatusChip(
                    label: context.l10n.catalogAntiCheatBlocked,
                    color: AppColor.statusBlocked,
                  )
                else
                  StatusChip(
                    label: context.l10n.catalogAntiCheatMayFail,
                    color: AppColor.statusFlaky,
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(context.l10n.catalogAntiCheatNote, style: styles.caption),
      ],
    );
  }
}
