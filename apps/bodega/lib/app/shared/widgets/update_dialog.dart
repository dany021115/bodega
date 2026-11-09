import 'package:bodega/app/bloc/update/update_bloc.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

/// A3: the newer version, its notes, and its download or how to get it.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  static String _mb(int bytes) => (bytes / (1 << 20)).toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UpdateBloc, UpdateState>(
      builder: (context, state) {
        final update = state.update;
        if (update == null) return const SizedBox.shrink();
        final bloc = context.read<UpdateBloc>();
        final styles = AppTextStyle(context);
        final colors = Theme.of(context).colorScheme;
        final total = state.total;

        return AlertDialog(
          title: const Text('Hay una versión nueva'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bodega ${update.version} (tienes ${update.current})',
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
                  Text(
                    'Actualízala con tu gestor de paquetes, con el archivo de '
                    'la versión:',
                    style: styles.body,
                  ),
                  SelectableText(update.command, style: styles.mono),
                ],
                if (state.phase == UpdatePhase.downloading) ...[
                  const SizedBox(height: AppSpacing.md),
                  LinearProgressIndicator(value: state.fraction, minHeight: 2),
                  const SizedBox(height: AppSpacing.xs),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      total == null
                          ? 'Descargando: ${_mb(state.received)} MB'
                          : 'Descargando: ${_mb(state.received)} de '
                                '${_mb(total)} MB',
                      style: styles.caption,
                    ),
                  ),
                ],
                if (state.phase == UpdatePhase.installing) ...[
                  const SizedBox(height: AppSpacing.md),
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Instalando. Bodega se cerrará y abrirá la versión nueva.',
                    style: styles.caption,
                  ),
                ],
                if (state.error case final error?) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    error.message,
                    style: styles.body?.copyWith(color: colors.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                // A5, said where the user decides.
                Text(
                  'Tus botellas, juegos y ajustes se quedan como están.',
                  style: styles.caption,
                ),
              ],
            ),
          ),
          actions: switch (state.phase) {
            UpdatePhase.available => [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  bloc.add(const UpdateEvent.skip());
                },
                child: const Text('Ahora no'),
              ),
              if (update.installable)
                FilledButton(
                  onPressed: () => bloc.add(const UpdateEvent.install()),
                  child: const Text('Actualizar'),
                )
              else
                FilledButton(
                  onPressed: () => launchUrl(Uri.parse(update.page)),
                  child: const Text('Ver la versión'),
                ),
            ],
            UpdatePhase.downloading => [
              OutlinedButton(
                onPressed: () => bloc.add(const UpdateEvent.cancel()),
                child: const Text('Cancelar'),
              ),
            ],
            UpdatePhase.installing => const [],
          },
        );
      },
    );
  }
}
