import 'package:bodega/app/bloc/bottles/bottles_bloc.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/widgets/confirm_dialog.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/bottle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BottleCard extends StatelessWidget {
  final Bottle bottle;
  final bool isOpen;

  const BottleCard({super.key, required this.bottle, required this.isOpen});

  Future<void> _delete(BuildContext context) async {
    final bloc = context.read<BottlesBloc>();
    final confirmed = await confirm(
      context,
      title: 'Borrar la botella ${bottle.name}',
      message: 'Se borrará su carpeta. No se puede deshacer.',
      action: 'Borrar',
    );
    if (confirmed) bloc.add(BottlesEvent.delete(bottle.name));
  }

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final (label, color) = isOpen
        ? ('Abierta', AppColor.statusTested)
        : bottle.ready
        ? ('Lista', AppColor.statusUntested)
        : ('Incompleta', AppColor.statusFlaky);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: AppRadius.mdBorder,
        onTap: () => RouterManager.go(
          AppRoute.bottleDetail,
          params: {'name': bottle.name},
          context: context,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bottle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: styles.cardTitle,
                    ),
                    Text(
                      bottle.app?.title ?? 'Sin aplicación',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: styles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              StatusChip(label: label, color: color),
              if (!bottle.ready) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () => _delete(context),
                  child: const Text('Borrar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
