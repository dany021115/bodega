import 'package:bodega/app/bloc/update/update_bloc.dart';
import 'package:bodega/app/shared/text/error_text.dart';
import 'package:bodega/app/shared/text/progress_text.dart';
import 'package:bodega/app/shared/widgets/copy_details_button.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

/// A3: the newer version, its notes, and its download or how to get it. The
/// notes and the package command show as the release publishes them.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UpdateBloc, UpdateState>(
      builder: (context, state) {
        final update = state.update;
        if (update == null) return const SizedBox.shrink();
        final bloc = context.read<UpdateBloc>();
        final styles = AppTextStyle(context);
        final colors = Theme.of(context).colorScheme;
        final l10n = context.l10n;

        return AlertDialog(
          // Long notes, an error and its Copy details button fill a small
          // window: the text scrolls, and the buttons stay.
          scrollable: true,
          title: Text(l10n.updateTitle),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.updateVersions(update.version, update.current),
                  style: styles.body,
                ),
                if (update.notes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        update.notes,
                        style: styles.bodySecondary,
                      ),
                    ),
                  ),
                ],
                if (!update.installable && update.command.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.updatePackageManager, style: styles.body),
                  SelectableText(update.command, style: styles.mono),
                ],
                if (state.phase == UpdatePhase.downloading) ...[
                  const SizedBox(height: AppSpacing.md),
                  LinearProgressIndicator(value: state.fraction, minHeight: 2),
                  const SizedBox(height: AppSpacing.xs),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      downloadProgressText(
                        l10n,
                        received: state.received,
                        total: state.total,
                      ),
                      style: styles.caption,
                    ),
                  ),
                ],
                if (state.phase == UpdatePhase.installing) ...[
                  const SizedBox(height: AppSpacing.md),
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: AppSpacing.xs),
                  Text(l10n.updateInstalling, style: styles.caption),
                ],
                if (state.error case final error?) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    error.localized(l10n),
                    style: styles.body?.copyWith(color: colors.error),
                  ),
                  CopyDetailsButton(error: error),
                ],
                const SizedBox(height: AppSpacing.md),
                // A5, said where the user decides.
                Text(l10n.updateKeepsData, style: styles.caption),
              ],
            ),
          ),
          actions: switch (state.phase) {
            UpdatePhase.available => [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  bloc.add(const UpdateEvent.dismiss());
                },
                child: Text(l10n.updateNotNow),
              ),
              if (update.installable)
                FilledButton(
                  onPressed: () => bloc.add(const UpdateEvent.install()),
                  child: Text(l10n.updateInstall),
                )
              else
                FilledButton(
                  onPressed: () => launchUrl(Uri.parse(update.page)),
                  child: Text(l10n.updateViewRelease),
                ),
            ],
            UpdatePhase.downloading => [
              OutlinedButton(
                onPressed: () => bloc.add(const UpdateEvent.cancel()),
                child: Text(l10n.commonCancel),
              ),
            ],
            UpdatePhase.installing => const [],
          },
        );
      },
    );
  }
}
