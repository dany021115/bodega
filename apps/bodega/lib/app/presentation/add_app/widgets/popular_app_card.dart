import 'package:bodega/app/shared/widgets/app_icon.dart';
import 'package:bodega/app/shared/widgets/gradient_button.dart';
import 'package:bodega/app/shared/widgets/status_chip.dart';
import 'package:bodega/device/theme/color.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// A catalog app in the add dialog. Blocked ones are dimmed and can't install.
class PopularAppCard extends StatelessWidget {
  final CatalogApp app;
  final VoidCallback onInstall;

  const PopularAppCard({super.key, required this.app, required this.onInstall});

  @override
  Widget build(BuildContext context) {
    final styles = AppTextStyle(context);
    final blocked = app.status == CatalogStatus.blocked;
    final l10n = context.l10n;
    final (label, color) = switch (app.status) {
      CatalogStatus.tested => (l10n.catalogTested, AppColor.statusTested),
      CatalogStatus.reported => (l10n.catalogReported, AppColor.statusReported),
      CatalogStatus.untested => (l10n.catalogUntested, AppColor.statusUntested),
      CatalogStatus.blocked => (l10n.addAppUnsupported, AppColor.statusBlocked),
    };

    return Opacity(
      opacity: blocked ? 0.5 : 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              AppIcon(id: app.id, title: app.title),
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
                    const SizedBox(height: AppSpacing.xs),
                    StatusChip(label: label, color: color),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      app.statusNote,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: styles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Capped, so the label gets an ellipsis before the row overflows.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 132),
                child: GradientButton(
                  label: blocked ? l10n.addAppUnavailable : l10n.catalogInstall,
                  onPressed: blocked ? null : onInstall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
