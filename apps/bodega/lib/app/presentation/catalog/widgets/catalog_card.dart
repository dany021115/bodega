import 'package:bodega/app/presentation/catalog/widgets/catalog_chips.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/widgets/app_icon.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/radius.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:flutter/material.dart';

class CatalogCard extends StatelessWidget {
  final CatalogApp app;

  const CatalogCard({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: AppRadius.mdBorder,
        onTap: () => RouterManager.go(
          AppRoute.catalogDetail,
          params: {'id': app.id},
          context: context,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              AppIcon(id: app.id, title: app.title),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle(context).cardTitle,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    CatalogChips(app: app),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
