import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/helpers/app_toast.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

/// D3DMetal's versions and their install (I1–I3). Bodega never downloads it:
/// the user's browser does, with their Apple ID, and they accept the license.
class GptkSection extends StatelessWidget {
  final BackendsState state;

  /// The version installed, or null.
  final String? installed;

  const GptkSection({super.key, required this.state, this.installed});

  Future<void> _pickDmg(BuildContext context) async {
    final bloc = context.read<BackendsBloc>();
    final dmgs = XTypeGroup(
      label: context.l10n.gptkDiskImage,
      extensions: const ['dmg'],
    );
    final file = await openFile(acceptedTypeGroups: [dmgs]);
    if (file != null) bloc.add(BackendsEvent.installGptkDmg(file.path));
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final l10n = context.l10n;
    final bloc = context.read<BackendsBloc>();
    final version = installed;
    final waiting = state.gptkWaiting;
    final blocked =
        state.busy != null || state.checking != null || waiting != null;

    return MultiBlocListener(
      listeners: [
        BlocListener<BackendsBloc, BackendsState>(
          listenWhen: (before, now) =>
              before.gptkWaiting == null && now.gptkWaiting != null,
          listener: (context, now) {
            final release = now.releases
                .where((r) => r.version == now.gptkWaiting)
                .firstOrNull;
            if (release != null) launchUrl(Uri.parse(release.url));
          },
        ),
        BlocListener<BackendsBloc, BackendsState>(
          listenWhen: (before, now) =>
              now.gptkInstalled != null &&
              before.gptkInstalled != now.gptkInstalled,
          listener: (context, now) {
            final done = now.gptkInstalled;
            if (done == null) return;
            final words = context.l10n;
            // Two sentences, one message each.
            final next = now.bottles.isEmpty
                ? words.gptkToastNeedsBottle
                : words.gptkToastChecking;
            AppToast.success(
              context,
              '${words.gptkInstalledToast(done)} $next',
            );
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            version == null
                ? l10n.gptkChooseVersion
                : l10n.gptkInstalledVersion(version),
            style: styles.body,
          ),
          for (final release in state.releases) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Game Porting Toolkit ${release.version}',
                    style: styles.body,
                  ),
                ),
                StatusChip(
                  label: release.tested ? l10n.gptkTested : l10n.gptkUntested,
                  color: release.tested
                      ? AppColor.statusTested
                      : AppColor.statusFlaky,
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: blocked
                      ? null
                      : () => bloc.add(BackendsEvent.installGptk(release)),
                  child: Text(
                    version?.startsWith(release.version) ?? false
                        ? l10n.gptkReinstall
                        : l10n.commonInstall,
                  ),
                ),
              ],
            ),
          ],
          if (waiting != null) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              liveRegion: true,
              child: Text(l10n.gptkWaiting(waiting), style: styles.caption),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (waiting != null || state.gptkStep != null)
                OutlinedButton(
                  onPressed: () => bloc.add(const BackendsEvent.cancelGptk()),
                  child: Text(l10n.commonCancel),
                ),
              TextButton(
                onPressed: state.busy != null ? null : () => _pickDmg(context),
                child: Text(l10n.gptkPickDmg),
              ),
            ],
          ),
          Text(l10n.gptkLicenseNote, style: styles.caption),
        ],
      ),
    );
  }
}
