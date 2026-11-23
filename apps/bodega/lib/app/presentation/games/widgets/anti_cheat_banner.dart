import 'package:bodega/app/shared/text/game_text.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// What a game's anti-cheat means on the Mac. It only warns: Bodega never
/// hides Wine from anti-cheat.
class AntiCheatBanner extends StatelessWidget {
  final AntiCheatVerdict verdict;
  final List<String> names;

  const AntiCheatBanner({
    super.key,
    required this.verdict,
    required this.names,
  });

  @override
  Widget build(BuildContext context) {
    final color = verdict == AntiCheatVerdict.blocked
        ? AppColor.statusBlocked
        : AppColor.statusFlaky;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.mdBorder,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(Icons.shield_outlined, color: color)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.l10n.antiCheatOf(verdict, names),
              style: AppTextStyle(context).body,
            ),
          ),
        ],
      ),
    );
  }
}
