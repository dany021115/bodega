import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/presentation/setup/widgets/tarball_row.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RuntimeCard extends StatelessWidget {
  final SetupState state;

  const RuntimeCard({super.key, required this.state});

  Future<String?> _pick(BuildContext context) async {
    final tarballs = XTypeGroup(
      label: context.l10n.commonTarballFileType,
      extensions: const ['gz', 'GZ'],
    );
    final file = await openFile(acceptedTypeGroups: [tarballs]);
    return file?.path;
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final l10n = context.l10n;
    final bloc = context.read<SetupBloc>();
    final busy = state.isInstalling;
    final canInstall = !busy && state.engine != null && state.hostlibs != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.setupEngineMissing, style: styles.subsectionTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.setupEngineFiles, style: styles.bodySecondary),
            const SizedBox(height: AppSpacing.lg),
            TarballRow(
              label: l10n.setupEngine,
              path: state.engine,
              onPick: busy
                  ? null
                  : () async {
                      final path = await _pick(context);
                      if (path != null) {
                        bloc.add(SetupEvent.engineChosen(path));
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.md),
            TarballRow(
              label: l10n.setupLibraries,
              path: state.hostlibs,
              onPick: busy
                  ? null
                  : () async {
                      final path = await _pick(context);
                      if (path != null) {
                        bloc.add(SetupEvent.hostlibsChosen(path));
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: canInstall
                  ? () => bloc.add(const SetupEvent.install())
                  : null,
              child: busy
                  ? const CustomLoading(size: 18)
                  : Text(l10n.commonInstall),
            ),
          ],
        ),
      ),
    );
  }
}
