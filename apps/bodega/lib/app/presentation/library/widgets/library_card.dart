import 'package:bodega/app/bloc/library/library_bloc.dart';
import 'package:bodega/app/shared/widgets/app_icon.dart';
import 'package:bodega/app/shared/widgets/confirm_dialog.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LibraryCard extends StatelessWidget {
  final LibraryApp app;

  /// Open is said of the bottle, as a game inside Steam can't be told apart.
  final bool isOpen;
  final List<String> hints;

  const LibraryCard({
    super.key,
    required this.app,
    required this.isOpen,
    required this.hints,
  });

  Future<void> _stop(BuildContext context) async {
    final bloc = context.read<LibraryBloc>();
    final confirmed = await confirm(
      context,
      title: 'Parar la botella ${app.bottle}',
      message:
          'Se cerrará todo lo que esté abierto en la botella ${app.bottle}. '
          'Lo que no hayas guardado se perderá.',
      action: 'Parar',
    );
    if (confirmed) bloc.add(LibraryEvent.stop(app.bottle));
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppIcon(id: app.id, title: app.title, iconPath: app.iconPath),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.cardTitle,
                      ),
                      Text(
                        'Botella ${app.bottle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.caption,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (isOpen)
                        const StatusChip(
                          label: 'Botella abierta',
                          color: AppColor.statusTested,
                        )
                      else
                        const StatusChip(
                          label: 'Cerrada',
                          color: AppColor.statusUntested,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                if (isOpen) ...[
                  OutlinedButton(
                    onPressed: () => _stop(context),
                    child: const Text('Parar botella'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                FilledButton(
                  onPressed: () => context.read<LibraryBloc>().add(
                    LibraryEvent.open(app.bottle, app.key),
                  ),
                  child: const Text('Abrir'),
                ),
              ],
            ),
            for (final hint in hints) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: colors.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(hint, style: styles.bodySecondary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
