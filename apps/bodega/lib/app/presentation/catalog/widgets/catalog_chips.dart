import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

class CatalogChips extends StatelessWidget {
  final CatalogApp app;

  const CatalogChips({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, color) = switch (app.status) {
      CatalogStatus.tested => (l10n.catalogTested, AppColor.statusTested),
      CatalogStatus.reported => (l10n.catalogReported, AppColor.statusReported),
      CatalogStatus.untested => (l10n.catalogUntested, AppColor.statusUntested),
      CatalogStatus.blocked => (l10n.catalogBlocked, AppColor.statusBlocked),
    };

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        StatusChip(label: label, color: color),
        if (app.flaky != null)
          StatusChip(label: l10n.catalogFlaky, color: AppColor.statusFlaky),
        if (app.isInstalled)
          StatusChip(
            label: l10n.catalogInstalled,
            color: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }
}
