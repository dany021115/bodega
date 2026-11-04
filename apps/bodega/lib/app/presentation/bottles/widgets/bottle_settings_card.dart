import 'package:bodega/app/bloc/bottle_detail/bottle_detail_bloc.dart';
import 'package:bodega/app/shared/widgets/confirm_dialog.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BottleSettingsCard extends StatelessWidget {
  final BottleDetail detail;
  final bool isBusy;

  const BottleSettingsCard({
    super.key,
    required this.detail,
    required this.isBusy,
  });

  Future<void> _setSync(BuildContext context, bool msync) async {
    final bloc = context.read<BottleDetailBloc>();
    final confirmed = await confirm(
      context,
      title: msync ? 'Activar msync' : 'Desactivar msync',
      message:
          'Se cerrará todo lo que esté abierto en la botella ${detail.name}. '
          'Lo que no hayas guardado se perderá.',
      action: 'Cambiar',
    );
    if (confirmed) {
      bloc.add(BottleDetailEvent.setSync(msync ? 'msync' : 'none'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final bloc = context.read<BottleDetailBloc>();
    // The current one too: it may have been uninstalled by hand.
    final backends = {'auto', ...detail.installedBackends, detail.backend};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: ValueKey(detail.backend),
              initialValue: detail.backend,
              decoration: const InputDecoration(labelText: 'Backend'),
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
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('msync', style: styles.cardTitle),
              subtitle: Text(
                'Cambiarlo cierra lo que esté abierto en la botella.',
                style: styles.caption,
              ),
              value: detail.sync == 'msync',
              onChanged: isBusy ? null : (value) => _setSync(context, value),
            ),
            if (detail.exceptions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Excepciones por programa', style: styles.cardTitle),
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
            ],
          ],
        ),
      ),
    );
  }
}
