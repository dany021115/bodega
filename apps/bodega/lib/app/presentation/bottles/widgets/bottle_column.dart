import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/presentation/bottles/widgets/log_dialog.dart';
import 'package:bodega/app/shared/widgets/collapsible_section.dart';
import 'package:bodega/app/shared/widgets/confirm_dialog.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What can be done with a bottle: the column at its right.
class BottleColumn extends StatelessWidget {
  final BottleDetail detail;
  final bool isBusy;
  final bool isOpen;

  const BottleColumn({
    super.key,
    required this.detail,
    required this.isBusy,
    required this.isOpen,
  });

  Future<void> _run(BuildContext context) async {
    final bloc = context.read<LibraryBloc>();
    const programs = XTypeGroup(label: 'Programas', extensions: ['exe']);
    final file = await openFile(acceptedTypeGroups: const [programs]);
    if (file != null) bloc.add(LibraryEvent.run(detail.name, file.path));
  }

  Future<void> _stop(BuildContext context) async {
    final bloc = context.read<LibraryBloc>();
    final confirmed = await confirm(
      context,
      title: 'Parar la botella ${detail.name}',
      message:
          'Se cerrará todo lo que esté abierto en ella. Lo que no hayas '
          'guardado se perderá.',
      action: 'Parar',
    );
    if (confirmed) bloc.add(LibraryEvent.stop(detail.name));
  }

  Future<void> _delete(BuildContext context) async {
    final bloc = context.read<BottleDetailBloc>();
    final confirmed = await confirm(
      context,
      title: 'Borrar la botella ${detail.name}',
      message:
          'Se cerrará lo que tenga abierto y se borrará su carpeta, con todo '
          'lo que hayas instalado dentro. No se puede deshacer.',
      action: 'Borrar',
    );
    if (confirmed) bloc.add(const BottleDetailEvent.delete());
  }

  Future<void> _setSync(BuildContext context, bool msync) async {
    final bloc = context.read<BottleDetailBloc>();
    final confirmed = await confirm(
      context,
      title: msync ? 'Activar msync' : 'Desactivar msync',
      message:
          'Se cerrará todo lo que esté abierto en la botella ${detail.name}. '
          'Lo que no hayas guardado se perderá.',
      action: 'Cambiar',
    );
    if (confirmed) {
      bloc.add(BottleDetailEvent.setSync(msync ? 'msync' : 'none'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final bloc = context.read<BottleDetailBloc>();
    // The current one too: it may have been uninstalled by hand.
    final backends = {'auto', ...detail.installedBackends, detail.backend};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollapsibleSection(
          id: 'actions',
          title: 'Acciones',
          children: [
            TextButton.icon(
              style: _leftAligned,
              onPressed: isBusy ? null : () => _run(context),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Ejecutar un programa'),
            ),
            if (isOpen)
              TextButton.icon(
                style: _leftAligned,
                onPressed: isBusy ? null : () => _stop(context),
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Parar'),
              ),
            TextButton.icon(
              style: _leftAligned,
              onPressed: isBusy ? null : () => _delete(context),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Borrar botella'),
            ),
          ],
        ),
        CollapsibleSection(
          id: 'settings',
          title: 'Configuración avanzada',
          children: [
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<String>(
              key: ValueKey(detail.backend),
              initialValue: detail.backend,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Gráficos'),
              items: [
                for (final backend in backends)
                  DropdownMenuItem(
                    value: backend,
                    child: Text(backend == 'auto' ? 'Automático' : backend),
                  ),
              ],
              onChanged: isBusy
                  ? null
                  : (backend) {
                      if (backend != null) {
                        bloc.add(BottleDetailEvent.setBackend(backend));
                      }
                    },
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('msync', style: styles.body),
              subtitle: Text(
                'Cambiarlo cierra lo que esté abierto.',
                style: styles.caption,
              ),
              value: detail.sync == 'msync',
              onChanged: isBusy ? null : (value) => _setSync(context, value),
            ),
          ],
        ),
        CollapsibleSection(
          id: 'details',
          title: 'Detalles',
          children: [
            if (detail.exceptions.isNotEmpty) ...[
              Text('Excepciones por programa', style: styles.caption),
              const SizedBox(height: AppSpacing.xs),
              for (final exception in detail.exceptions)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${exception.exe} → ${exception.backend}',
                        style: styles.body,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Quitar la excepción de ${exception.exe}',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: isBusy
                          ? null
                          : () => bloc.add(
                              BottleDetailEvent.removeException(exception.exe),
                            ),
                    ),
                  ],
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text('Logs', style: styles.caption),
            const SizedBox(height: AppSpacing.xs),
            if (detail.logs.isEmpty)
              Text('Todavía no hay logs.', style: styles.bodySecondary),
            for (final log in detail.logs)
              InkWell(
                borderRadius: AppRadius.xsBorder,
                onTap: () => showLogDialog(context, log.name, log.path),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.caption?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        log.exitCode == null
                            ? 'en curso'
                            : 'salió con ${log.exitCode}',
                        style: styles.caption,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static final ButtonStyle _leftAligned = TextButton.styleFrom(
    alignment: Alignment.centerLeft,
  );
}
