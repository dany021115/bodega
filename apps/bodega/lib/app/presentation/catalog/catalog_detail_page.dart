import 'package:bodega/app/bloc/catalog/catalog_bloc.dart';
import 'package:bodega/app/presentation/catalog/widgets/catalog_chips.dart';
import 'package:bodega/app/presentation/catalog/widgets/detail_action.dart';
import 'package:bodega/app/presentation/catalog/widgets/detail_section.dart';
import 'package:bodega/app/router.dart';
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
    final styles = AppTextStyle(context);
    final l10n = context.l10n;
    String sourceLabel(String key) => switch (key) {
      'repo' => l10n.catalogSourceRepo,
      'commit' => l10n.catalogSourceCommit,
      'path' => l10n.catalogSourcePath,
      'license' => l10n.catalogSourceLicense,
      'verified' => l10n.catalogSourceVerified,
      _ => key,
    };

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
              actionLabel: l10n.catalogBack,
              onAction: () =>
                  RouterManager.go(AppRoute.catalog, context: context),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      RouterManager.go(AppRoute.catalog, context: context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(l10n.catalogBackShort),
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
              const SizedBox(height: AppSpacing.lg),
              Text(app.statusNote, style: styles.body),
              if (app.flaky case final flaky?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(flaky, style: styles.bodySecondary),
              ],
              const SizedBox(height: AppSpacing.lg),
              DetailAction(app: app),
              DetailSection(
                title: l10n.catalogSettings,
                children: [
                  Text(l10n.catalogBackend(app.backend), style: styles.body),
                  Text(l10n.catalogSync(app.sync), style: styles.body),
                ],
              ),
              if (app.notes.isNotEmpty)
                DetailSection(
                  title: l10n.catalogNotes,
                  children: [
                    for (final note in app.notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(note, style: styles.body),
                      ),
                  ],
                ),
              if (app.knownIssues.isNotEmpty)
                DetailSection(
                  title: l10n.catalogKnownIssues,
                  children: [
                    for (final issue in app.knownIssues)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(issue.symptom, style: styles.cardTitle),
                            Text(issue.fix, style: styles.bodySecondary),
                          ],
                        ),
                      ),
                  ],
                ),
              DetailSection(
                title: l10n.catalogSource,
                children: [
                  for (final MapEntry(:key, :value) in app.source.entries)
                    SelectableText(
                      '${sourceLabel(key)}: $value',
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
