import 'package:bodega/app/shared/text/game_text.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

typedef GameReport = ({GameVerdict verdict, String note});

/// Asks how [game] ran (A5). Null when the user cancels.
Future<GameReport?> showReportDialog(BuildContext context, String game) =>
    showDialog<GameReport>(
      context: context,
      builder: (_) => ReportDialog(game: game),
    );

class ReportDialog extends StatefulWidget {
  final String game;

  const ReportDialog({super.key, required this.game});

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final _note = TextEditingController();
  GameVerdict? _verdict;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    final verdict = _verdict;

    return AlertDialog(
      title: Text(l10n.gamesReportTitle(widget.game)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final choice in GameVerdict.values)
                    ChoiceChip(
                      label: Text(l10n.verdictOf(choice)),
                      selected: verdict == choice,
                      onSelected: (_) => setState(() => _verdict = choice),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: InputDecoration(labelText: l10n.gamesReportNote),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.gamesReportExplain, style: styles.bodySecondary),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: verdict == null
              ? null
              : () =>
                    Navigator.of(context)
                        .pop<GameReport>((verdict: verdict, note: _note.text)),
          child: Text(l10n.gamesReportSend),
        ),
      ],
    );
  }
}
