import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:flutter/material.dart';

class CatalogChips extends StatelessWidget {
  final CatalogApp app;

  const CatalogChips({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (app.status) {
      CatalogStatus.tested => ('Probado', AppColor.statusTested),
      CatalogStatus.reported => ('Reportado', AppColor.statusReported),
      CatalogStatus.untested => ('Sin probar', AppColor.statusUntested),
      CatalogStatus.blocked => ('Bloqueado', AppColor.statusBlocked),
    };

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        StatusChip(label: label, color: color),
        if (app.flaky != null)
          const StatusChip(label: 'Inestable', color: AppColor.statusFlaky),
        if (app.isInstalled)
          StatusChip(
            label: 'Instalada',
            color: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }
}
