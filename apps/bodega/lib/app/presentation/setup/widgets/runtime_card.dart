import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/presentation/setup/widgets/tarball_row.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RuntimeCard extends StatelessWidget {
  final SetupState state;

  const RuntimeCard({super.key, required this.state});

  Future<String?> _pick() async {
    const tarballs = XTypeGroup(label: 'Tarball', extensions: ['gz', 'GZ']);
    final file = await openFile(acceptedTypeGroups: const [tarballs]);
    return file?.path;
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final bloc = context.read<SetupBloc>();
    final busy = state.isInstalling;
    final canInstall = !busy && state.engine != null && state.hostlibs != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Falta el motor', style: styles.subsectionTitle),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Elige los dos archivos del motor. Cada uno debe tener su '
              '.sha256 al lado.',
              style: styles.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            TarballRow(
              label: 'Motor',
              path: state.engine,
              onPick: busy
                  ? null
                  : () async {
                      final path = await _pick();
                      if (path != null) {
                        bloc.add(SetupEvent.engineChosen(path));
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.md),
            TarballRow(
              label: 'Librerías',
              path: state.hostlibs,
              onPick: busy
                  ? null
                  : () async {
                      final path = await _pick();
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
                  : const Text('Instalar'),
            ),
          ],
        ),
      ),
    );
  }
}
