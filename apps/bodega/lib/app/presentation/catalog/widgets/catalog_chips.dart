import 'package:bodega/app/shared/text/catalog_text.dart';
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
    final color = switch (app.status) {
      CatalogStatus.tested => AppColor.statusTested,
      CatalogStatus.reported => AppColor.statusReported,
      CatalogStatus.untested => AppColor.statusUntested,
      CatalogStatus.blocked => AppColor.statusBlocked,
    };

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        StatusChip(label: catalogStatusText(l10n, app.status), color: color),
        if (app.flaky)
          StatusChip(label: l10n.catalogFlaky, color: AppColor.statusFlaky),
        if (app.isInstalled)
          StatusChip(
            label: l10n.catalogAppInstalled,
            color: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }
}
