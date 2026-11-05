import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/presentation/bottles/widgets/log_dialog.dart';
import 'package:bodega/app/presentation/bottles/widgets/run_options_dialog.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/widgets/collapsible_section.dart';
import 'package:bodega/app/shared/widgets/confirm_dialog.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

/// What can be done with a bottle: the column at its right (V8–V10).
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

  static const windowsNames = {
    'win11': 'Windows 11',
    'win10': 'Windows 10',
    'win81': 'Windows 8.1',
    'win7': 'Windows 7',
  };

  /// Wine's own tools: each one opens its window.
  static const panels = [
    ('Configuración de Wine', 'winecfg', <String>[]),
    ('Editor del registro', 'regedit', <String>[]),
    ('Administrador de tareas', 'taskmgr', <String>[]),
    ('Panel de control', 'control', <String>[]),
    ('Mandos', 'control', ['joy.cpl']),
    ('Desinstalar programas', 'uninstaller', <String>[]),
  ];

  Future<bool> _closes(BuildContext context, String title) => confirm(
    context,
    title: title,
    message:
        'Se cerrará todo lo que esté abierto en la botella ${detail.name}. '
        'Lo que no hayas guardado se perderá.',
    action: 'Cambiar',
  );

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

  Widget _action(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool enabled = true,
  }) => TextButton.icon(
    style: TextButton.styleFrom(alignment: Alignment.centerLeft),
    onPressed: isBusy || !enabled ? null : onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
  );

  Widget _switch(
    BuildContext context,
    String title,
    String note,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final styles = AppTextStyle(context);
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: styles.body),
      subtitle: Text(note, style: styles.caption),
      value: value,
      onChanged: isBusy ? null : onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final bloc = context.read<BottleDetailBloc>();
    final library = context.read<LibraryBloc>();
    final name = detail.name;
    // The current one too: it may have been uninstalled by hand.
    final backends = {'auto', ...detail.installedBackends, detail.backend};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollapsibleSection(
          id: 'actions',
          title: 'Acciones',
          children: [
            _action(
              Icons.play_arrow_rounded,
              'Ejecutar con opciones…',
              () => showRunOptions(
                context,
                bottle: name,
                backends: detail.installedBackends,
              ),
              enabled: detail.ready,
            ),
            _action(Icons.storefront_rounded, 'Instalar en esta botella', () {
              context.read<CatalogBloc>().add(CatalogEvent.target(name));
              RouterManager.go(AppRoute.catalog, context: context);
            }, enabled: detail.ready),
            _action(
              Icons.folder_open_rounded,
              'Abrir unidad C:',
              () => launchUrl(Uri.directory(detail.driveC)),
              enabled: detail.ready,
            ),
            _action(
              Icons.terminal_rounded,
              'Abrir terminal',
              () => library.add(LibraryEvent.run(name, 'wineconsole', ['cmd'])),
              enabled: detail.ready,
            ),
            if (isOpen)
              _action(Icons.stop_rounded, 'Parar', () => _stop(context)),
            _action(
              Icons.delete_outline_rounded,
              'Borrar botella',
              () => _delete(context),
            ),
          ],
        ),
        CollapsibleSection(
          id: 'settings',
          title: 'Configuración avanzada',
          children: [
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<String>(
              key: ValueKey('backend ${detail.backend}'),
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
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              key: ValueKey('windows ${detail.windows}'),
              initialValue: detail.windows,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Versión de Windows',
              ),
              items: [
                for (final MapEntry(:key, :value) in windowsNames.entries)
                  DropdownMenuItem(value: key, child: Text(value)),
              ],
              onChanged: isBusy || !detail.ready
                  ? null
                  : (version) {
                      if (version != null) {
                        bloc.add(BottleDetailEvent.setWindows(version));
                      }
                    },
            ),
            _switch(
              context,
              'msync',
              'Cambiarlo cierra lo que esté abierto.',
              detail.sync == 'msync',
              (value) async {
                if (await _closes(
                  context,
                  value ? 'Activar msync' : 'Desactivar msync',
                )) {
                  bloc.add(BottleDetailEvent.setSync(value ? 'msync' : 'none'));
                }
              },
            ),
            _switch(
              context,
              'Alta resolución',
              'Más nítido en pantallas Retina. Cierra lo que esté abierto.',
              detail.highRes,
              (value) async {
                final title = value
                    ? 'Activar alta resolución'
                    : 'Desactivar alta resolución';
                if (await _closes(context, title)) {
                  bloc.add(BottleDetailEvent.setHighRes(value));
                }
              },
            ),
            _switch(
              context,
              'DLSS',
              'Con D3DMetal o DXMT y un juego compatible. Sin probar.',
              detail.dlss,
              (value) => bloc.add(BottleDetailEvent.setDlss(value)),
            ),
            _switch(
              context,
              'Anunciar AVX',
              'Apágalo si un juego se cierra al empezar.',
              detail.avx,
              (value) => bloc.add(BottleDetailEvent.setAvx(value)),
            ),
          ],
        ),
        CollapsibleSection(
          id: 'panels',
          title: 'Paneles de control',
          children: [
            for (final (label, program, args) in panels)
              _action(
                Icons.tune_rounded,
                label,
                () => library.add(LibraryEvent.run(name, program, args)),
                enabled: detail.ready,
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
}
