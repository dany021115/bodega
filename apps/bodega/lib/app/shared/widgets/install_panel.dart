import 'package:bodega/app/bloc/install/install_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/widgets/app_icon.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The installation in course, under every section: it goes on while the user
/// moves around the app.
class InstallPanel extends StatelessWidget {
  const InstallPanel({super.key});

  String _size(int bytes) => '${(bytes / (1 << 20)).toStringAsFixed(0)} MB';

  String _progress(InstallState state) {
    final total = state.total;
    if (total == null) return 'Descargando · ${_size(state.received)}';
    final percent = (state.fraction! * 100).toStringAsFixed(0);
    return 'Descargando · $percent % · ${_size(state.received)} de '
        '${_size(total)}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InstallBloc, InstallState>(
      builder: (context, state) {
        final app = state.app;
        if (app == null) return const SizedBox.shrink();

        final styles = AppTextStyle(context);
        final colors = Theme.of(context).colorScheme;
        final bloc = context.read<InstallBloc>();

        final (String headline, Widget? detail) = switch (state.phase) {
          InstallPhase.downloading => (
            _progress(state),
            app.hasChecksum
                ? null
                : Text(
                    'Este instalador no tiene checksum fijo: se confía en '
                    'HTTPS y en ${app.host}.',
                    style: styles.caption,
                  ),
          ),
          InstallPhase.installing => (state.step ?? 'Instalando', null),
          InstallPhase.done => (
            'Instalada',
            app.notes.isEmpty
                ? null
                : Text(app.notes.join('\n\n'), style: styles.bodySecondary),
          ),
          InstallPhase.failed => (
            'No se pudo instalar',
            SelectableText(
              state.error?.message ?? '',
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
                              child: const Text('Cancelar'),
                            ),
                          if (state.phase == InstallPhase.done)
                            FilledButton(
                              onPressed: () {
                                context.read<LibraryBloc>().add(
                                  LibraryEvent.open(app.id),
                                );
                                bloc.add(const InstallEvent.dismiss());
                                RouterManager.go(
                                  AppRoute.library,
                                  context: context,
                                );
                              },
                              child: const Text('Abrir'),
                            ),
                          if (state.bottleLeft)
                            OutlinedButton(
                              onPressed: () =>
                                  bloc.add(const InstallEvent.removeBottle()),
                              child: const Text('Borrar botella'),
                            ),
                          if (!state.isRunning)
                            TextButton(
                              onPressed: () =>
                                  bloc.add(const InstallEvent.dismiss()),
                              child: const Text('Cerrar'),
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
