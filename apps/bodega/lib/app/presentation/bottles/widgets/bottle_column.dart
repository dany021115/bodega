import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/presentation/bottles/widgets/gamepads_section.dart';
import 'package:bodega/app/presentation/bottles/widgets/log_dialog.dart';
import 'package:bodega/app/presentation/bottles/widgets/rename_bottle_dialog.dart';
import 'package:bodega/app/presentation/bottles/widgets/run_options_dialog.dart';
import 'package:bodega/app/presentation/bottles/widgets/windows_user_dialog.dart';
import 'package:bodega/app/shared/graphics_of.dart';
import 'package:bodega/app/shared/text/backend_text.dart';
import 'package:bodega/app/shared/text/hint_text.dart';
import 'package:bodega/app/shared/widgets/collapsible_section.dart';
import 'package:bodega/app/shared/widgets/confirm_dialog.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/app/shared/widgets/stop_bottle.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/gradient.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/entities/run_hint.dart';
import 'package:bodega/l10n/l10n.dart';
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
  final List<RunHint> hints;

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
  static List<(String, String, List<String>)> panels(AppL10n l10n) => [
    (l10n.bottleToolWineConfig, 'winecfg', const <String>[]),
    (l10n.bottleToolRegistry, 'regedit', const <String>[]),
    (l10n.bottleToolTaskManager, 'taskmgr', const <String>[]),
    (l10n.bottleToolControlPanel, 'control', const <String>[]),
    (l10n.bottleToolGameControllers, 'control', const ['joy.cpl']),
    (l10n.bottleToolUninstall, 'uninstaller', const <String>[]),
  ];

  /// [backend] as the user reads it: its name, or the Automatic option.
  static String _backendName(AppL10n l10n, String backend) =>
      backend == 'auto' ? l10n.bottleGraphicsAuto : backend;

  Future<bool> _closes(BuildContext context, String title) => confirm(
    context,
    title: title,
    message: context.l10n.bottleStopConfirm(detail.name),
    action: context.l10n.commonChange,
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

  Future<void> _rename(BuildContext context) async {
    final bloc = context.read<BottleDetailBloc>();
    final newName = await showRenameBottleDialog(context, detail.name);
    if (newName != null) bloc.add(BottleDetailEvent.rename(newName));
  }

  Future<void> _delete(BuildContext context) async {
    final bloc = context.read<BottleDetailBloc>();
    final l10n = context.l10n;
    final confirmed = await confirm(
      context,
      title: l10n.bottleDeleteTitle(detail.name),
      message: l10n.bottleDeleteConfirm,
      action: l10n.commonDelete,
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
                            ? context.l10n.bottleRenameStopFirst
                            : context.l10n.commonRename,
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
              Expanded(
                child: Text(
                  hint.localized(context.l10n),
                  style: styles.bodySecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _facts(BuildContext context) {
    final l10n = context.l10n;
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
        fact(l10n.bottleFactApps(detail.apps.length), '${detail.apps.length}'),
        const SizedBox(width: AppSpacing.sm),
        fact('Windows', windowsNames[detail.windows] ?? detail.windows),
        const SizedBox(width: AppSpacing.sm),
        fact(l10n.bottleGraphics, _backendName(l10n, detail.backend)),
      ],
    );
  }

  /// G4: the apps that the backend chosen for the bottle does not suit.
  String? _misfits(BuildContext context) {
    final backend = detail.backend;
    if (backend == 'auto') return null;
    final l10n = context.l10n;
    final apps = [
      for (final app in detail.apps)
        if (graphicsOf(context, detail.name, app.exe) case final graphics?
            when graphics.misfits.contains(backend))
          '${app.title} (${graphicsLabelText(l10n, graphics)})',
    ];
    if (apps.isEmpty) return null;
    // The option it points to comes in by its own text, as the dropdown says.
    return l10n.bottleMisfitWarning(
      backend,
      apps.join(', '),
      l10n.bottleGraphicsAuto,
    );
  }

  Widget _quickActions(BuildContext context) {
    final l10n = context.l10n;
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
            l10n.commonStop,
            () => confirmStopBottle(context, name),
            color: colors.error,
          ),
        _quick(
          Icons.play_arrow_rounded,
          l10n.bottleRunWithOptions,
          () => showRunOptions(
            context,
            bottle: name,
            backends: detail.installedBackends,
          ),
          enabled: detail.ready,
        ),
        // Runs a program once: it is not kept in the bottle's list.
        _quick(Icons.file_open_rounded, l10n.bottleRunExe, () async {
          final file = await openFile(
            acceptedTypeGroups: [
              XTypeGroup(
                label: l10n.commonProgramsFileType,
                extensions: const ['exe', 'EXE'],
              ),
            ],
          );
          if (file != null) library.add(LibraryEvent.run(name, file.path));
        }, enabled: detail.ready),
        _quick(
          Icons.folder_open_rounded,
          l10n.bottleDriveC,
          () => launchUrl(Uri.directory(detail.driveC)),
          enabled: detail.ready,
        ),
        _quick(
          Icons.terminal_rounded,
          l10n.bottleTerminal,
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
      label: Text(context.l10n.bottleDelete),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    final bloc = context.read<BottleDetailBloc>();
    final library = context.read<LibraryBloc>();
    final caps = context.read<SetupBloc>().state.capabilities;
    final colors = Theme.of(context).colorScheme;
    final name = detail.name;
    // The current one too: it may have been uninstalled by hand.
    final backends = {'auto', ...detail.installedBackends, detail.backend};
    final (status, color) = !detail.ready
        ? ('incomplete', AppColor.statusFlaky)
        : isOpen
        ? ('open', AppColor.statusTested)
        : ('closed', AppColor.statusUntested);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _identity(context, l10n.bottleStatus(status), color),
        const SizedBox(height: AppSpacing.lg),
        _facts(context),
        const SizedBox(height: AppSpacing.lg),
        _quickActions(context),
        CollapsibleSection(
          id: 'settings',
          title: l10n.bottleSectionSettings,
          children: [
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<String>(
              key: ValueKey('backend ${detail.backend}'),
              initialValue: detail.backend,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.bottleGraphics),
              items: [
                for (final backend in backends)
                  DropdownMenuItem(
                    value: backend,
                    child: Text(_backendName(l10n, backend)),
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
              decoration: InputDecoration(labelText: l10n.bottleWindowsVersion),
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
                l10n.bottleWindowsUser,
                style: AppTextStyle(context).body,
              ),
              subtitle: Text(
                detail.user.isEmpty
                    ? l10n.bottleWindowsUserDefault(detail.macUser)
                    : detail.user,
                style: AppTextStyle(context).caption,
              ),
              trailing: TextButton(
                onPressed: isBusy ? null : () => _changeUser(context),
                child: Text(l10n.bottleChangeUser),
              ),
            ),
            if (caps.syncModes.length > 1)
              _switch(
                context,
                'msync',
                l10n.bottleChangeCloses,
                detail.sync == 'msync',
                (value) async {
                  if (await _closes(
                    context,
                    value ? l10n.bottleMsyncOn : l10n.bottleMsyncOff,
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
                l10n.bottleHighRes,
                // Two sentences, each its own message: the second is shared.
                '${l10n.bottleHighResNote} ${l10n.bottleChangeCloses}',
                detail.highRes,
                (value) async {
                  final title = value
                      ? l10n.bottleHighResOn
                      : l10n.bottleHighResOff;
                  if (await _closes(context, title)) {
                    bloc.add(BottleDetailEvent.setHighRes(value));
                  }
                },
              ),
            if (caps.dlss)
              _switch(
                context,
                'DLSS',
                l10n.bottleDlssNote,
                detail.dlss,
                (value) => bloc.add(BottleDetailEvent.setDlss(value)),
              ),
            if (caps.avx)
              _switch(
                context,
                l10n.bottleAvx,
                l10n.bottleAvxNote,
                detail.avx,
                (value) => bloc.add(BottleDetailEvent.setAvx(value)),
              ),
            if (caps.gpu) ...[
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                key: ValueKey('gpu ${detail.gpu}'),
                initialValue: detail.gpu,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.bottleGpu),
                items: [
                  DropdownMenuItem(
                    value: 'auto',
                    child: Text(l10n.bottleGpuAuto),
                  ),
                  DropdownMenuItem(
                    value: 'discrete',
                    child: Text(l10n.bottleGpuDiscrete),
                  ),
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
                l10n.bottleGameModeNote,
                detail.gamemode,
                (value) => bloc.add(BottleDetailEvent.setGamemode(value)),
              ),
          ],
        ),
        CollapsibleSection(
          id: 'panels',
          title: l10n.bottleSectionTools,
          children: [
            for (final (label, program, args) in panels(l10n))
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
          title: l10n.bottleSectionDetails,
          children: [
            if (detail.exceptions.isNotEmpty) ...[
              Text(l10n.bottleExceptions, style: styles.caption),
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
                      tooltip: l10n.bottleExceptionRemove(exception.exe),
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
            Text(l10n.bottleLogs, style: styles.caption),
            const SizedBox(height: AppSpacing.xs),
            if (detail.logs.isEmpty)
              Text(l10n.bottleLogsEmpty, style: styles.bodySecondary),
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
                      Text(switch (log.exitCode) {
                        final code? => l10n.bottleLogExited(code),
                        null => l10n.bottleLogRunning,
                      }, style: styles.caption),
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
