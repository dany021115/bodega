import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/presentation/backends/widgets/d3dmetal_instructions.dart';
import 'package:bodega/app/presentation/backends/widgets/probe_dialog.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BackendCard extends StatelessWidget {
  final BackendInfo backend;
  final BackendsState state;

  const BackendCard({super.key, required this.backend, required this.state});

  static const _descriptions = {
    'wine': 'wined3d y vkd3d. Viene con el motor.',
    'dxmt': 'D3D10 y D3D11 sobre Metal. El que usan los launchers.',
    'dxvk': 'D3D10 y D3D11 sobre Vulkan, con MoltenVK.',
    'd3dmetal': 'D3D11 y D3D12 sobre Metal, de Apple. Lo importas tú.',
  };

  Future<void> _pickFile(BuildContext context) async {
    final bloc = context.read<BackendsBloc>();
    const tarballs = XTypeGroup(label: 'Tarball', extensions: ['gz', 'GZ']);
    final file = await openFile(acceptedTypeGroups: const [tarballs]);
    if (file != null) {
      bloc.add(BackendsEvent.installFile(backend.name, file.path));
    }
  }

  Future<void> _pickFolder(BuildContext context) async {
    final bloc = context.read<BackendsBloc>();
    final folder = await getDirectoryPath(confirmButtonText: 'Elegir');
    if (folder != null) bloc.add(BackendsEvent.importD3DMetal(folder));
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

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final bloc = context.read<BackendsBloc>();
    final name = backend.name;
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
                  const StatusChip(
                    label: 'Instalado',
                    color: AppColor.statusTested,
                  )
                else
                  const StatusChip(
                    label: 'No instalado',
                    color: AppColor.statusUntested,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(_descriptions[name] ?? '', style: styles.bodySecondary),
            if (name == 'd3dmetal') ...[
              const SizedBox(height: AppSpacing.md),
              const D3DMetalInstructions(),
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
                  isChecking
                      ? 'Comprobando; cada caso puede tardar hasta 90 s'
                      : state.isDownloading && state.fraction != 1
                      ? 'Descargando'
                      : 'Instalando',
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
                    child: const Text('Cancelar'),
                  ),
                if (!backend.installed && backend.downloadable) ...[
                  FilledButton(
                    onPressed: blocked
                        ? null
                        : () => bloc.add(BackendsEvent.download(name)),
                    child: const Text('Instalar'),
                  ),
                  OutlinedButton(
                    onPressed: blocked ? null : () => _pickFile(context),
                    child: const Text('Elegir archivo…'),
                  ),
                ],
                if (!backend.installed && name == 'd3dmetal')
                  FilledButton(
                    onPressed: blocked ? null : () => _pickFolder(context),
                    child: const Text('Elegir carpeta…'),
                  ),
                if (backend.installed)
                  OutlinedButton(
                    onPressed: blocked ? null : () => _check(context),
                    child: const Text('Comprobar'),
                  ),
              ],
            ),
            for (final result in results) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (result.ok)
                    const StatusChip(label: 'OK', color: AppColor.statusTested)
                  else
                    const StatusChip(
                      label: 'Falla',
                      color: AppColor.statusBlocked,
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${result.bits} bits, D3D${result.d3d}',
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
