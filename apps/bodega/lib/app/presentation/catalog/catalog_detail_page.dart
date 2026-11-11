import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/presentation/catalog/widgets/catalog_chips.dart';
import 'package:bodega/app/presentation/catalog/widgets/detail_action.dart';
import 'package:bodega/app/presentation/catalog/widgets/detail_section.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/app/shared/text/catalog_text.dart';
import 'package:bodega/app/shared/widgets/app_icon.dart';
import 'package:bodega/app/shared/widgets/custom_loading.dart';
import 'package:bodega/app/shared/widgets/empty_state.dart';
import 'package:bodega/device/router/manager.dart';
import 'package:bodega/device/theme/spacing.dart';
import 'package:bodega/device/theme/typography.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CatalogDetailPage extends StatelessWidget {
  final String id;

  const CatalogDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styles = AppTextStyle(context);

    return Scaffold(
      body: BlocBuilder<CatalogBloc, CatalogState>(
        builder: (context, state) {
          if (state.isLoading) return const CustomLoading();
          final app = state.apps.where((app) => app.id == id).firstOrNull;
          if (app == null) {
            return EmptyState(
              icon: Icons.search_off_rounded,
              title: l10n.catalogNotFound,
              message: id,
              actionLabel: l10n.catalogBackToCatalog,
              onAction: () =>
                  RouterManager.go(AppRoute.catalog, context: context),
            );
          }
          final prose = catalogProse(app.id, l10n);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      RouterManager.go(AppRoute.catalog, context: context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(l10n.catalogTitle),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  AppIcon(id: app.id, title: app.title, size: 64),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(app.title, style: styles.screenTitle),
                        const SizedBox(height: AppSpacing.xs),
                        CatalogChips(app: app),
                      ],
                    ),
                  ),
                ],
              ),
              if (prose != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(prose.statusNote, style: styles.body),
                if (prose.flaky case final flaky?) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(flaky, style: styles.bodySecondary),
                ],
              ],
              const SizedBox(height: AppSpacing.lg),
              DetailAction(app: app),
              DetailSection(
                title: l10n.catalogConfigSection,
                children: [
                  Text(l10n.catalogBackend(app.backend), style: styles.body),
                  Text(l10n.catalogSync(app.sync), style: styles.body),
                ],
              ),
              if (prose != null && prose.notes.isNotEmpty)
                DetailSection(
                  title: l10n.catalogNotesSection,
                  children: [
                    for (final note in prose.notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(note, style: styles.body),
                      ),
                  ],
                ),
              if (prose != null && prose.issues.isNotEmpty)
                DetailSection(
                  title: l10n.catalogKnownIssuesSection,
                  children: [
                    for (final (symptom, fix) in prose.issues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(symptom, style: styles.cardTitle),
                            Text(fix, style: styles.bodySecondary),
                          ],
                        ),
                      ),
                  ],
                ),
              DetailSection(
                title: l10n.catalogSourceSection,
                children: [
                  for (final MapEntry(:key, :value) in app.source.entries)
                    SelectableText(
                      l10n.catalogSourceLine(
                        catalogSourceText(l10n, key),
                        value ?? l10n.catalogSourceNoData,
                      ),
                      style: styles.caption,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
