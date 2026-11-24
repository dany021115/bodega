import 'package:bodega/app/bloc/dependencies/dependencies_bloc.dart';
import 'package:bodega/app/presentation/bottles/widgets/log_dialog.dart';
import 'package:bodega/app/shared/text/dependency_text.dart';
import 'package:bodega/app/shared/text/error_text.dart';
import 'package:bodega/app/shared/widgets/collapsible_section.dart';
import 'package:bodega/app/shared/widgets/copy_details_button.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/dependency.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the bottle's programs need and what it has (DA7, RA5): each app with
/// its runtimes and its game settings, each with its state and its button;
/// every runtime with its state per architecture and its button; when the
/// bottle was read, with "Check again"; the job's progress under each line of
/// what it installs; a failure with its log. While the bottle is open, nothing
/// can start.
class DependenciesSection extends StatefulWidget {
  final String bottle;
  final bool isOpen;

  const DependenciesSection({
    super.key,
    required this.bottle,
    required this.isOpen,
  });

  @override
  State<DependenciesSection> createState() => _DependenciesSectionState();
}

class _DependenciesSectionState extends State<DependenciesSection> {
  @override
  void initState() {
    super.initState();
    context.read<DependenciesBloc>().add(DependenciesEvent.load(widget.bottle));
  }

  @override
  void didUpdateWidget(DependenciesSection old) {
    super.didUpdateWidget(old);
    if (old.bottle != widget.bottle) {
      context.read<DependenciesBloc>().add(
        DependenciesEvent.load(widget.bottle),
      );
    }
  }

  Future<void> _pickInstaller(RuntimeItem item) async {
    final bloc = context.read<DependenciesBloc>();
    final programs = XTypeGroup(
      label: context.l10n.commonProgramsFileType,
      extensions: ['exe', 'EXE'],
    );
    final file = await openFile(acceptedTypeGroups: [programs]);
    if (file != null) {
      bloc.add(DependenciesEvent.installFile(widget.bottle, item, file.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    final state = context.watch<DependenciesBloc>().state;
    final bloc = context.read<DependenciesBloc>();
    final data = state.bottles[widget.bottle];
    final canAct = !widget.isOpen && !state.isBusy;
    final failed = state.failedBottle == widget.bottle ? state.failed : null;
    final busy = state.isBusy && state.bottle == widget.bottle;
    // The job's bar, under each line of what it installs. Only the table's
    // announces it, so a screen reader hears it once.
    Widget? progressOf(
      bool Function(NeedItem item) matches, {
      bool announce = false,
    }) => switch (state.item) {
      final item? when busy && matches(item) => _Progress(
        state: state,
        data: data,
        announce: announce,
      ),
      _ => null,
    };
    // The table's rows, each with its architectures, in the table's order.
    final runtimes = <String, List<Dependency>>{};
    for (final dependency in data?.all ?? const <Dependency>[]) {
      (runtimes[dependency.id] ??= []).add(dependency);
    }
    void install(Dependency dependency) => bloc.add(
      DependenciesEvent.install(widget.bottle, [
        NeedItem.runtime(dependency.id, dependency.arch),
      ]),
    );
    // A file of the user's stands for a runtime with one download only.
    final pickable = switch (failed) {
      RuntimeItem(:final id, :final arch) =>
        data?.all
                .where((d) => d.id == id && d.arch == arch)
                .firstOrNull
                ?.files ==
            1,
      _ => false,
    };

    return CollapsibleSection(
      id: 'dependencies',
      title: l10n.depsTitle,
      children: [
        if (data?.checkedAt case final checked?)
          Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.depsCheckedAt(
                  MaterialLocalizations.of(context)
                      .formatTimeOfDay(TimeOfDay.fromDateTime(checked)),
                ),
                style: styles.caption,
              ),
              TextButton(
                onPressed: state.isBusy
                    ? null
                    : () => bloc.add(DependenciesEvent.load(widget.bottle)),
                child: Text(l10n.depsCheckAgain),
              ),
            ],
          ),
        if (data == null)
          Text(l10n.depsLoading, style: styles.bodySecondary)
        else if (data.apps.isEmpty)
          Text(l10n.depsNothing, style: styles.bodySecondary),
        for (final app in data?.apps ?? const <AppNeeds>[]) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(app.title, style: styles.label),
          for (final need in app.dependencies)
            _Item(
              title: l10n.dependencyLine(need.dependency),
              reason: l10n.reasonOf(need),
              need: need.need,
              state: need.dependency.installed
                  ? StatusChip(
                      label: l10n.depsInstalled,
                      color: AppColor.statusTested,
                    )
                  : null,
              action: need.dependency.installed
                  ? null
                  : TextButton(
                      onPressed: canAct ? () => install(need.dependency) : null,
                      child: Text(l10n.commonInstall),
                    ),
              below: progressOf(
                (item) =>
                    item ==
                    NeedItem.runtime(need.dependency.id, need.dependency.arch),
              ),
            ),
          for (final setting in app.settings)
            _Item(
              title: l10n.settingLine(setting),
              reason: l10n.fixReason(setting.fix),
              need: Need.recommended,
              state: setting.state == SettingState.applied
                  ? StatusChip(
                      label: l10n.depsSettingApplied,
                      color: AppColor.statusTested,
                    )
                  : null,
              // A sentence, not a chip: it goes under the line, where it can
              // wrap.
              note: setting.state == SettingState.noFile
                  ? l10n.depsSettingNoFile
                  : null,
              action: setting.state == SettingState.notApplied
                  ? TextButton(
                      onPressed: canAct
                          ? () => bloc.add(
                              DependenciesEvent.install(widget.bottle, [
                                NeedItem.settings(setting.fix),
                              ]),
                            )
                          : null,
                      child: Text(l10n.depsApply),
                    )
                  : null,
              below: progressOf(
                (item) => item == NeedItem.settings(setting.fix),
                announce: true,
              ),
            ),
        ],
        if (runtimes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(l10n.depsAllRuntimes, style: styles.label),
          for (final archs in runtimes.values)
            _RuntimeRow(
              archs: archs,
              canAct: canAct,
              onInstall: install,
              progress: progressOf(
                (item) => item is RuntimeItem && item.id == archs.first.id,
                announce: true,
              ),
            ),
        ],
        if (widget.isOpen) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.depsStopFirst, style: styles.caption),
        ],
        // ponytail: with the bottle read, every job has its line above.
        if (busy && data == null) ...[
          const SizedBox(height: AppSpacing.md),
          _Progress(state: state, data: data, announce: true),
        ],
        if (state.error case final error? when failed != null) ...[
          const SizedBox(height: AppSpacing.md),
          SelectableText(
            error.localized(l10n),
            style: styles.body?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (state.failedLog case final log?)
                OutlinedButton(
                  onPressed: () =>
                      showLogDialog(context, log.split('/').last, log),
                  child: Text(l10n.depsDetails),
                ),
              if (failed case final RuntimeItem item when pickable)
                OutlinedButton(
                  onPressed: canAct ? () => _pickInstaller(item) : null,
                  child: Text(l10n.depsChooseFile),
                ),
              CopyDetailsButton(error: error),
            ],
          ),
        ],
      ],
    );
  }
}

/// One runtime or setting: its line, its reason and need, and at the right
/// its state or its button.
class _Item extends StatelessWidget {
  final String title;
  final String reason;
  final Need need;
  final Widget? state;
  final Widget? action;
  final String? note;

  /// The job's bar, when it installs this line.
  final Widget? below;

  const _Item({
    required this.title,
    required this.reason,
    required this.need,
    this.state,
    this.action,
    this.note,
    this.below,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);

    final line = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: styles.body),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusChip(
                    label: l10n.needOf(need),
                    color: need == Need.recommended
                        ? AppColor.statusTested
                        : AppColor.statusUntested,
                  ),
                  Text(reason, style: styles.caption),
                ],
              ),
              if (note case final text?) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(text, style: styles.caption),
              ],
            ],
          ),
        ),
        if (state case final shown?) ...[
          const SizedBox(width: AppSpacing.sm),
          shown,
        ],
        ?action,
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line,
          if (below case final bar?) ...[
            const SizedBox(height: AppSpacing.xs),
            bar,
          ],
        ],
      ),
    );
  }
}

/// One runtime of the table: its name, what needs it, and per architecture
/// its state and, when it is not there, its button with the download's size.
class _RuntimeRow extends StatelessWidget {
  final List<Dependency> archs;
  final bool canAct;
  final ValueChanged<Dependency> onInstall;

  /// The job's bar, when it installs one of [archs].
  final Widget? progress;

  const _RuntimeRow({
    required this.archs,
    required this.canAct,
    required this.onInstall,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    final first = archs.first;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(first.name, style: styles.body),
          Text(l10n.runtimeLine(first.id), style: styles.caption),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final dependency in archs) ...[
                StatusChip(
                  label: dependency.arch == Arch.all
                      ? l10n.statusOf(dependency.status)
                      : l10n.depsArchStatus(
                          l10n.archOf(dependency.arch),
                          l10n.statusOf(dependency.status),
                        ),
                  color: switch (dependency.status) {
                    DependencyStatus.installed => AppColor.statusTested,
                    DependencyStatus.notInstalled => AppColor.statusUntested,
                    DependencyStatus.unknown => AppColor.statusFlaky,
                  },
                ),
                if (dependency.status == DependencyStatus.notInstalled)
                  TextButton(
                    onPressed: canAct ? () => onInstall(dependency) : null,
                    child: Text(
                      dependency.arch == Arch.all
                          ? l10n.depsInstallSize(l10n.sizeOf(dependency.bytes))
                          : l10n.depsInstallArch(
                              l10n.archOf(dependency.arch),
                              l10n.sizeOf(dependency.bytes),
                            ),
                    ),
                  ),
              ],
            ],
          ),
          if (progress case final bar?) ...[
            const SizedBox(height: AppSpacing.sm),
            bar,
          ],
        ],
      ),
    );
  }
}

/// What the job does now: how far a download is, in percent; an installer
/// tells nothing, so its bar only moves. With [announce], for screen readers
/// too.
class _Progress extends StatelessWidget {
  final DependenciesState state;
  final BottleDependencies? data;
  final bool announce;

  const _Progress({
    required this.state,
    required this.data,
    required this.announce,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);
    final item = state.item;
    final name = switch (item) {
      RuntimeItem(:final id, :final arch) =>
        data?.all
                .where((d) => d.id == id && d.arch == arch)
                .map((d) => l10n.depsInstalledItem(d.name, l10n.archOf(d.arch)))
                .firstOrNull ??
            id,
      SettingsItem(:final fix) =>
        data?.apps
                .expand((app) => app.settings)
                .where((setting) => setting.fix == fix)
                .map((setting) => setting.game)
                .firstOrNull ??
            fix,
      null => '',
    };
    final text = switch (state.phase) {
      DependencyPhase.downloading => switch (state.total) {
        final total? when total > 0 => l10n.downloadProgress(
          state.received / total,
          state.received / 1000000,
          total / 1000000,
        ),
        _ => l10n.downloadProgressNoTotal(state.received / 1000000),
      },
      DependencyPhase.installing => l10n.depsInstalling(name),
      DependencyPhase.applying => l10n.depsApplying(name),
      DependencyPhase.idle => '',
    };

    return Semantics(
      liveRegion: announce,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: state.phase == DependencyPhase.downloading
                ? state.fraction
                : null,
            minHeight: 6,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(child: Text(text, style: styles.caption)),
              if (state.phase == DependencyPhase.downloading)
                TextButton(
                  onPressed: () => context.read<DependenciesBloc>().add(
                    const DependenciesEvent.cancel(),
                  ),
                  child: Text(l10n.commonCancel),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
