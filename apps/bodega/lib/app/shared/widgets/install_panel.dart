import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/text/catalog_text.dart';
import 'package:bodega/app/shared/text/error_text.dart';
import 'package:bodega/app/shared/text/progress_text.dart';
import 'package:bodega/app/shared/text/step_text.dart';
import 'package:bodega/app/shared/widgets/app_icon.dart';
import 'package:bodega/app/shared/widgets/copy_details_button.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The installation in course, under every section: it goes on while the user
/// moves around the app.
class InstallPanel extends StatelessWidget {
  const InstallPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InstallBloc, InstallState>(
      builder: (context, state) {
        final app = state.app;
        if (app == null) return const SizedBox.shrink();

        final styles = AppTextStyle(context);
        final colors = Theme.of(context).colorScheme;
        final l10n = context.l10n;
        final bloc = context.read<InstallBloc>();

        final (String headline, Widget? detail) = switch (state.phase) {
          InstallPhase.downloading => (
            downloadProgressText(
              l10n,
              received: state.received,
              total: state.total,
            ),
            app.hasChecksum
                ? null
                : Text(l10n.installNoChecksum(app.host), style: styles.caption),
          ),
          InstallPhase.installing => (
            switch (state.step) {
              final step? => installStepText(l10n, step, app),
              null => l10n.commonInstalling,
            },
            null,
          ),
          InstallPhase.done => (
            l10n.catalogAppInstalled,
            switch (catalogProse(app.id, l10n)?.notes) {
              final notes? when notes.isNotEmpty => Text(
                notes.join('\n\n'),
                style: styles.bodySecondary,
              ),
              _ => null,
            },
          ),
          InstallPhase.failed => (
            l10n.installFailed,
            SelectableText(
              state.error?.localized(l10n) ?? '',
              style: styles.body?.copyWith(color: colors.error),
            ),
          ),
          InstallPhase.idle => ('', null),
        };

        return Material(
          color: colors.surfaceContainer,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                if (state.isRunning)
                  LinearProgressIndicator(
                    value: state.phase == InstallPhase.downloading
                        ? state.fraction
                        : null,
                    minHeight: 2,
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIcon(id: app.id, title: app.title, size: 40),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(app.title, style: styles.cardTitle),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                headline,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: styles.bodySecondary,
                              ),
                            ),
                            if (detail != null) ...[
                              const SizedBox(height: AppSpacing.xs),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 120,
                                ),
                                child: SingleChildScrollView(child: detail),
                              ),
                            ],
                            // Below the error's box: a long error never hides
                            // it.
                            if (state.error case final error?
                                when state.phase == InstallPhase.failed)
                              CopyDetailsButton(error: error),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          if (state.phase == InstallPhase.downloading)
                            OutlinedButton(
                              onPressed: () =>
                                  bloc.add(const InstallEvent.cancel()),
                              child: Text(l10n.commonCancel),
                            ),
                          if (state.phase == InstallPhase.done)
                            FilledButton(
                              onPressed: () {
                                context.read<LibraryBloc>().add(
                                  LibraryEvent.open(
                                    state.bottle ?? app.id,
                                    app.installKey,
                                  ),
                                );
                                bloc.add(const InstallEvent.dismiss());
                                RouterManager.go(
                                  AppRoute.library,
                                  context: context,
                                );
                              },
                              child: Text(l10n.commonOpen),
                            ),
                          if (state.bottleLeft)
                            OutlinedButton(
                              onPressed: () =>
                                  bloc.add(const InstallEvent.removeBottle()),
                              child: Text(l10n.bottleDelete),
                            ),
                          if (!state.isRunning)
                            TextButton(
                              onPressed: () =>
                                  bloc.add(const InstallEvent.dismiss()),
                              child: Text(l10n.commonClose),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
