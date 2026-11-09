import 'package:bodega/app/bloc/backends/backends_bloc.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/helpers/app_toast.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
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
    const dmgs = XTypeGroup(label: 'Imagen de disco', extensions: ['dmg']);
    final file = await openFile(acceptedTypeGroups: const [dmgs]);
    if (file != null) bloc.add(BackendsEvent.installGptkDmg(file.path));
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final bloc = context.read<BackendsBloc>();
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
          listener: (context, now) => AppToast.success(
            context,
            'D3DMetal ${now.gptkInstalled} instalado. '
            '${now.bottles.isEmpty ? 'Crea una botella para comprobarlo.' : 'Comprobando…'}',
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            installed == null
                ? 'Elige una versión del Game Porting Toolkit de Apple.'
                : 'Tienes D3DMetal $installed.',
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
                  label: release.tested ? 'Probada' : 'Beta, sin probar',
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
                    installed?.startsWith(release.version) ?? false
                        ? 'Reinstalar'
                        : 'Instalar',
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
              child: Text(
                'Inicia sesión en Apple en el navegador y descarga el Game '
                'Porting Toolkit $waiting. Bodega lo instala en cuanto '
                'aparezca en Descargas.',
                style: styles.caption,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (waiting != null || state.gptkStep != null)
                OutlinedButton(
                  onPressed: () => bloc.add(const BackendsEvent.cancelGptk()),
                  child: const Text('Cancelar'),
                ),
              TextButton(
                onPressed: state.busy != null ? null : () => _pickDmg(context),
                child: const Text('Ya lo tengo: elegir dmg…'),
              ),
            ],
          ),
          Text(
            'Bodega no descarga D3DMetal: lo baja tu navegador con tu cuenta '
            'de Apple, y su licencia la aceptas tú.',
            style: styles.caption,
          ),
        ],
      ),
    );
  }
}
