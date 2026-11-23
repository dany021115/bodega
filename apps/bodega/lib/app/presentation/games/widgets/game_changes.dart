import 'package:bodega/app/shared/text/game_text.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// What a configuration changes, one line each: its backend, its steps and
/// its runtimes (G7). Values are shown as they are, and can be copied.
class GameChanges extends StatelessWidget {
  final String? backend;
  final List<GameStep> steps;
  final List<String> requires;

  const GameChanges({
    super.key,
    this.backend,
    required this.steps,
    required this.requires,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    final lines = [
      if (backend case final backend?) l10n.gamesStepBackend(backend),
      for (final step in steps) l10n.stepOf(step),
      for (final id in requires) l10n.gamesStepRuntime(id),
    ];
    if (lines.isEmpty) {
      return Text(l10n.gamesChangesNone, style: styles.bodySecondary);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: SelectableText(line, style: styles.body),
          ),
      ],
    );
  }
}
