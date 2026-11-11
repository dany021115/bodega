import 'package:bodega/app/bloc/gamepads/gamepads_bloc.dart';
import 'package:bodega/app/presentation/setup/widgets/requirement_card.dart';
import 'package:bodega/app/shared/widgets/collapsible_section.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/gamepad.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The gamepads the system sees and what keeps Wine from using them. Where
/// there is nothing to check (the Mac) or the first look has not finished, it
/// takes no room.
class GamepadsSection extends StatelessWidget {
  const GamepadsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GamepadsBloc>().state;
    final report = state.report;
    if (report == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final styles = AppTextStyle(context);

    return CollapsibleSection(
      id: 'gamepads',
      title: l10n.gamepadsTitle,
      children: [
        if (report.pads.isEmpty)
          Text(l10n.gamepadsNone, style: styles.bodySecondary),
        for (final pad in report.pads) _PadRow(pad: pad),
        for (final issue in report.issues) ...[
          const SizedBox(height: AppSpacing.md),
          RequirementCard(issue: issue),
        ],
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: state.isLoading
                ? null
                : () => context.read<GamepadsBloc>().add(
                    const GamepadsEvent.load(),
                  ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.commonCheckAgain),
          ),
        ),
      ],
    );
  }
}

class _PadRow extends StatelessWidget {
  final Gamepad pad;

  const _PadRow({required this.pad});

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.sports_esports_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              pad.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: styles.body,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusChip(
            label: context.l10n.gamepadsPadState(
              pad.readable ? 'ready' : 'noAccess',
            ),
            color: pad.readable ? AppColor.statusTested : AppColor.statusFlaky,
          ),
        ],
      ),
    );
  }
}
