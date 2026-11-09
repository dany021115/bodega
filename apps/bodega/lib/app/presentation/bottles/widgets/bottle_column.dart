import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/presentation/bottles/widgets/gamepads_section.dart';
import 'package:bodega/app/presentation/bottles/widgets/log_dialog.dart';
import 'package:bodega/app/presentation/bottles/widgets/rename_bottle_dialog.dart';
import 'package:bodega/app/presentation/bottles/widgets/run_options_dialog.dart';
import 'package:bodega/app/presentation/bottles/widgets/windows_user_dialog.dart';
import 'package:bodega/app/shared/graphics_of.dart';
import 'package:bodega/app/shared/widgets/collapsible_section.dart';
import 'package:bodega/app/shared/widgets/confirm_dialog.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/gradient.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

/// What can be done with a bottle: its panel at the right of the applications,
/// or below them when there is no room.
class BottleColumn extends StatelessWidget {
  final BottleDetail detail;
  final bool isBusy;
  final bool isOpen;
  final List<String> hints;

  const BottleColumn({
    super.key,
    required this.detail,
    required this.isBusy,
    required this.isOpen,
    required this.hints,
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

  Future<void> _changeUser(BuildContext context) async {
    final bloc = context.read<BottleDetailBloc>();
    final user = await showWindowsUserDialog(
      context,
      current: detail.user,
      macUser: detail.macUser,
      problem: bloc.userProblem,
    );
    if (user != null) {
      bloc.add(BottleDetailEvent.setUser(user.isEmpty ? null : user));
    }
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

  Future<void> _rename(BuildContext context) async {
    final bloc = context.read<BottleDetailBloc>();
    final newName = await showRenameBottleDialog(context, detail.name);
    if (newName != null) bloc.add(BottleDetailEvent.rename(newName));
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

  Widget _quick(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool enabled = true,
    Color? color,
  }) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(foregroundColor: color),
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

  Widget _identity(BuildContext context, String label, Color color) {
    final styles = AppTextStyle(context);
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppGradient.brand,
                borderRadius: AppRadius.smBorder,
              ),
              child: ExcludeSemantics(
                child: Icon(Icons.wine_bar_rounded, color: colors.onPrimary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          detail.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.sectionTitle,
                        ),
                      ),
                      IconButton(
                        tooltip: isOpen
                            ? 'Párala para renombrarla'
                            : 'Renombrar',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        onPressed: isBusy || isOpen
                            ? null
                            : () => _rename(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  StatusChip(label: label, color: color),
                ],
              ),
            ),
          ],
        ),
        for (final hint in hints) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: colors.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(hint, style: styles.bodySecondary)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _facts(BuildContext context) {
    final styles = AppTextStyle(context);
    final colors = Theme.of(context).colorScheme;

    Widget fact(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: AppRadius.xsBorder,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.body?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(label, style: styles.caption),
          ],
        ),
      ),
    );

    return Row(
      children: [
        fact('Apps', '${detail.apps.length}'),
        const SizedBox(width: AppSpacing.sm),
        fact('Windows', windowsNames[detail.windows] ?? detail.windows),
        const SizedBox(width: AppSpacing.sm),
        fact(
          'Gráficos',
          detail.backend == 'auto' ? 'Automático' : detail.backend,
        ),
      ],
    );
  }

  /// G4: the apps that the backend chosen for the bottle does not suit.
  String? _misfits(BuildContext context) {
    final backend = detail.backend;
    if (backend == 'auto') return null;
    final apps = [
      for (final app in detail.apps)
        if (graphicsOf(context, detail.name, app.exe) case final graphics?
            when graphics.misfits.contains(backend))
          '${app.title} (${graphics.label})',
    ];
    return apps.isEmpty
        ? null
        : '$backend no le sirve a: ${apps.join(', ')}. Usa Automático.';
  }

  Widget _quickActions(BuildContext context) {
    final library = context.read<LibraryBloc>();
    final colors = Theme.of(context).colorScheme;
    final name = detail.name;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        if (isOpen)
          _quick(
            Icons.stop_rounded,
            'Parar',
            () => _stop(context),
            color: colors.error,
          ),
        _quick(
          Icons.play_arrow_rounded,
          'Ejecutar con opciones…',
          () => showRunOptions(
            context,
            bottle: name,
            backends: detail.installedBackends,
          ),
          enabled: detail.ready,
        ),
        // Runs a program once: it is not kept in the bottle's list.
        _quick(Icons.file_open_rounded, 'Ejecutar .exe…', () async {
          final file = await openFile(
            acceptedTypeGroups: const [
              XTypeGroup(label: 'Programas', extensions: ['exe', 'EXE']),
            ],
          );
          if (file != null) library.add(LibraryEvent.run(name, file.path));
        }, enabled: detail.ready),
        _quick(
          Icons.folder_open_rounded,
          'Unidad C:',
          () => launchUrl(Uri.directory(detail.driveC)),
          enabled: detail.ready,
        ),
        _quick(
          Icons.terminal_rounded,
          'Terminal',
          () => library.add(LibraryEvent.run(name, 'wineconsole', ['cmd'])),
          enabled: detail.ready,
        ),
      ],
    );
  }

  Widget _deleteButton(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.error,
        side: BorderSide(color: colors.error),
      ),
      onPressed: isBusy ? null : () => _delete(context),
      icon: const Icon(Icons.delete_outline_rounded, size: 18),
      label: const Text('Borrar botella'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final bloc = context.read<BottleDetailBloc>();
    final library = context.read<LibraryBloc>();
    final caps = context.read<SetupBloc>().state.capabilities;
    final colors = Theme.of(context).colorScheme;
    final name = detail.name;
    // The current one too: it may have been uninstalled by hand.
    final backends = {'auto', ...detail.installedBackends, detail.backend};
    final (label, color) = !detail.ready
        ? ('Incompleta', AppColor.statusFlaky)
        : isOpen
        ? ('Abierta', AppColor.statusTested)
        : ('Cerrada', AppColor.statusUntested);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _identity(context, label, color),
        const SizedBox(height: AppSpacing.lg),
        _facts(context),
        const SizedBox(height: AppSpacing.lg),
        _quickActions(context),
        CollapsibleSection(
          id: 'settings',
          title: 'Configuración',
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
            if (_misfits(context) case final warning?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                warning,
                style: AppTextStyle(context).caption
                    ?.copyWith(color: AppColor.statusFlaky),
              ),
            ],
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Usuario de Windows',
                style: AppTextStyle(context).body,
              ),
              subtitle: Text(
                detail.user.isEmpty
                    ? '${detail.macUser} (el de tu equipo)'
                    : detail.user,
                style: AppTextStyle(context).caption,
              ),
              trailing: TextButton(
                onPressed: isBusy ? null : () => _changeUser(context),
                child: const Text('Cambiar…'),
              ),
            ),
            if (caps.syncModes.length > 1)
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
                    bloc.add(
                      BottleDetailEvent.setSync(value ? 'msync' : 'none'),
                    );
                  }
                },
              ),
            if (caps.highRes)
              _switch(
                context,
                'Pantalla de alta densidad',
                'Más nítido en pantallas de alta densidad. Cierra lo que esté abierto.',
                detail.highRes,
                (value) async {
                  final title = value
                      ? 'Activar pantalla de alta densidad'
                      : 'Desactivar pantalla de alta densidad';
                  if (await _closes(context, title)) {
                    bloc.add(BottleDetailEvent.setHighRes(value));
                  }
                },
              ),
            if (caps.dlss)
              _switch(
                context,
                'DLSS',
                'Con D3DMetal o DXMT y un juego compatible. Sin probar.',
                detail.dlss,
                (value) => bloc.add(BottleDetailEvent.setDlss(value)),
              ),
            if (caps.avx)
              _switch(
                context,
                'Anunciar AVX',
                'Apágalo si un juego se cierra al empezar.',
                detail.avx,
                (value) => bloc.add(BottleDetailEvent.setAvx(value)),
              ),
            if (caps.gpu) ...[
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                key: ValueKey('gpu ${detail.gpu}'),
                initialValue: detail.gpu,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'GPU'),
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('Automática')),
                  DropdownMenuItem(value: 'discrete', child: Text('Discreta')),
                ],
                onChanged: isBusy
                    ? null
                    : (gpu) {
                        if (gpu != null) {
                          bloc.add(BottleDetailEvent.setGpu(gpu));
                        }
                      },
              ),
            ],
            if (caps.gameMode)
              _switch(
                context,
                'GameMode',
                'Usa gamemoderun si está instalado.',
                detail.gamemode,
                (value) => bloc.add(BottleDetailEvent.setGamemode(value)),
              ),
          ],
        ),
        CollapsibleSection(
          id: 'panels',
          title: 'Herramientas de Wine',
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
        const GamepadsSection(),
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
                          color: colors.onSurface,
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
        const SizedBox(height: AppSpacing.lg),
        _deleteButton(context),
      ],
    );
  }
}
