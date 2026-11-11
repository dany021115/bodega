import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/presentation/backends/widgets/gptk_section.dart';
import 'package:bodega/app/presentation/backends/widgets/probe_dialog.dart';
import 'package:bodega/app/shared/text/backend_text.dart';
import 'package:bodega/app/shared/text/progress_text.dart';
import 'package:bodega/app/shared/text/step_text.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BackendCard extends StatelessWidget {
  final BackendInfo backend;
  final BackendsState state;

  const BackendCard({super.key, required this.backend, required this.state});

  Future<void> _pickFile(BuildContext context) async {
    final bloc = context.read<BackendsBloc>();
    final tarballs = XTypeGroup(
      label: context.l10n.commonTarballFileType,
      extensions: const ['gz', 'GZ'],
    );
    final file = await openFile(acceptedTypeGroups: [tarballs]);
    if (file != null) {
      bloc.add(BackendsEvent.installFile(backend.name, file.path));
    }
  }

  Future<void> _check(BuildContext context) async {
    final bloc = context.read<BackendsBloc>();
    final bottle = await chooseProbeBottle(
      context,
      backend.name,
      state.bottles,
    );
    if (bottle != null) bloc.add(BackendsEvent.check(bottle, backend.name));
  }

  /// Under the progress bar: the check, D3DMetal's step, the download or the
  /// install, in that order.
  String _progress(AppL10n l10n, {required bool isChecking}) {
    if (isChecking) return l10n.backendChecking;
    if (state.gptkStep case final step?) return gptkStepText(l10n, step);
    if (state.isDownloading && state.fraction != 1) {
      return downloadProgressText(
        l10n,
        received: state.received,
        total: state.total,
      );
    }
    return l10n.commonInstalling;
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final l10n = context.l10n;
    final bloc = context.read<BackendsBloc>();
    final name = backend.name;
    final description = backendDescriptionText(l10n, name);
    final isBusy = state.busy == name;
    final isChecking = state.checking == name;
    final blocked = state.busy != null || state.checking != null;
    final results = state.results[name] ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(name, style: styles.cardTitle)),
                if (backend.installed)
                  StatusChip(
                    label: l10n.backendInstalled,
                    color: AppColor.statusTested,
                  )
                else
                  StatusChip(
                    label: l10n.backendNotInstalled,
                    color: AppColor.statusUntested,
                  ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(description, style: styles.bodySecondary),
            ],
            if (backend.role case final role?) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.backendUsedFor(backendRoleText(l10n, role)),
                style: styles.caption,
              ),
            ],
            if (name == 'd3dmetal') ...[
              const SizedBox(height: AppSpacing.md),
              GptkSection(state: state, installed: backend.version),
            ],
            if (isBusy || isChecking) ...[
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(
                value: isBusy && state.fraction != 1 ? state.fraction : null,
                minHeight: 2,
              ),
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                liveRegion: true,
                child: Text(
                  _progress(l10n, isChecking: isChecking),
                  style: styles.caption,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (isBusy && state.isDownloading && state.fraction != 1)
                  OutlinedButton(
                    onPressed: () => bloc.add(const BackendsEvent.cancel()),
                    child: Text(l10n.commonCancel),
                  ),
                if (!backend.installed && backend.downloadable) ...[
                  FilledButton(
                    onPressed: blocked
                        ? null
                        : () => bloc.add(BackendsEvent.download(name)),
                    child: Text(l10n.commonInstall),
                  ),
                  OutlinedButton(
                    onPressed: blocked ? null : () => _pickFile(context),
                    child: Text(l10n.commonChooseFile),
                  ),
                ],
                if (backend.installed)
                  OutlinedButton(
                    onPressed: blocked ? null : () => _check(context),
                    child: Text(l10n.backendCheck),
                  ),
              ],
            ),
            for (final result in results) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (result.ok)
                    StatusChip(
                      label: l10n.backendCheckPassed,
                      color: AppColor.statusTested,
                    )
                  else
                    StatusChip(
                      label: l10n.backendCheckFailed,
                      color: AppColor.statusBlocked,
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    l10n.backendCheckCase(result.bits, result.d3d),
                    style: styles.body,
                  ),
                ],
              ),
              SelectableText(result.log, style: styles.caption),
            ],
          ],
        ),
      ),
    );
  }
}
