import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/shared/text/progress_text.dart';
import 'package:bodega/app/shared/text/runtime_text.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/mach9_step.dart';
import 'package:bodega/domain/entities/runtime_block.dart';
import 'package:bodega/domain/entities/runtime_info.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The native engine, Mach9, on the Backends page (MA5): what it is, whether
/// it is installed, and its install. Not a backend: never a `BackendCard`.
class EngineCard extends StatelessWidget {
  final RuntimeInfo runtime;
  final BackendsState state;

  const EngineCard({super.key, required this.runtime, required this.state});

  bool get _busy => state.busy == RuntimeKind.mach9.name;

  Future<void> _pickFile(BuildContext context) async {
    final bloc = context.read<BackendsBloc>();
    final types = XTypeGroup(
      label: context.l10n.engineFileType,
      extensions: const ['dmg'],
      uniformTypeIdentifiers: const ['com.apple.application-bundle'],
    );
    final file = await openFile(
      acceptedTypeGroups: [types],
      initialDirectory: '/Applications',
    );
    if (file != null) {
      bloc.add(
        BackendsEvent.installRuntime(RuntimeKind.mach9, file: file.path),
      );
    }
  }

  /// Under the progress bar: the download while it runs, else the step.
  String _progress(AppL10n l10n) {
    if (state.isDownloading && state.fraction != 1) {
      return downloadProgressText(
        l10n,
        received: state.received,
        total: state.total,
      );
    }
    return switch (state.runtimeStep) {
      final step? => mach9StepText(l10n, step),
      null => l10n.commonInstalling,
    };
  }

  /// What the card says of its state, under the description: none, one or
  /// two lines.
  List<String> _status(AppL10n l10n) {
    final download = megabytes(runtime.downloadBytes);
    final disk = megabytes(runtime.diskBytes);
    if (runtime.installed) {
      return [
        if (runtime.version case final version?) l10n.engineVersion(version),
        if (!runtime.checked && runtime.version != null)
          l10n.engineUntested(runtime.version!),
      ];
    }
    if (runtime.appMatchesPin) {
      return [
        l10n.engineUseApp(runtime.appVersion!, runtime.appPath!),
        l10n.engineSizeFromApp(disk),
      ];
    }
    return [
      if (runtime.appUntested) l10n.engineUntested(runtime.appVersion!),
      if (runtime.diskBytes > 0) l10n.engineSizeDownload(download, disk),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final l10n = context.l10n;
    final bloc = context.read<BackendsBloc>();
    final blocked = state.busy != null || state.checking != null;
    final tooOld = runtime.blocked == RuntimeBlock.macosTooOld;
    final installing = _busy;
    final downloading =
        installing &&
        state.isDownloading &&
        state.fraction != 1 &&
        (state.runtimeStep == Mach9Step.downloading ||
            state.runtimeStep == Mach9Step.downloadingMono);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.engineNativeTitle, style: styles.cardTitle),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (runtime.installed)
                  StatusChip(
                    label: l10n.engineInstalled,
                    color: AppColor.statusTested,
                  )
                else
                  StatusChip(
                    label: l10n.engineNotInstalled,
                    color: AppColor.statusUntested,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.engineNativeDescription, style: styles.bodySecondary),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.engineNativeIncludes, style: styles.caption),
            if (tooOld) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.engineNeedsMacos(runtime.minimumMacos ?? ''),
                style: styles.body?.copyWith(color: AppColor.statusFlaky),
              ),
            ] else ...[
              for (final line in _status(l10n)) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(line, style: styles.body),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${l10n.engineOwnCopy} ${l10n.engineNativeDock}',
                style: styles.caption,
              ),
              if (installing) ...[
                const SizedBox(height: AppSpacing.md),
                LinearProgressIndicator(
                  value: downloading ? state.fraction : null,
                  minHeight: 2,
                ),
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  liveRegion: true,
                  child: Text(_progress(l10n), style: styles.caption),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (downloading)
                    OutlinedButton(
                      onPressed: () => bloc.add(const BackendsEvent.cancel()),
                      child: Text(l10n.commonCancel),
                    ),
                  if (!runtime.installed) ...[
                    FilledButton(
                      onPressed: blocked
                          ? null
                          : () => bloc.add(
                              const BackendsEvent.installRuntime(
                                RuntimeKind.mach9,
                              ),
                            ),
                      child: Text(l10n.commonInstall),
                    ),
                    OutlinedButton(
                      onPressed: blocked ? null : () => _pickFile(context),
                      child: Text(l10n.commonChooseFile),
                    ),
                  ] else if (runtime.updateAvailable)
                    FilledButton(
                      onPressed: blocked
                          ? null
                          : () => bloc.add(
                              const BackendsEvent.installRuntime(
                                RuntimeKind.mach9,
                              ),
                            ),
                      child: Text(l10n.engineUpdate(runtime.pinnedVersion!)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
