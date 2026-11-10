import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/l10n/l10n.dart';

/// The status of a catalog app, in the same words wherever it shows: the
/// catalog, the app's page and the add-app dialog (L15).
String catalogStatusText(AppL10n l10n, CatalogStatus status) =>
    switch (status) {
      CatalogStatus.tested => l10n.catalogStatusTested,
      CatalogStatus.reported => l10n.catalogStatusReported,
      CatalogStatus.untested => l10n.catalogStatusUntested,
      CatalogStatus.blocked => l10n.catalogStatusBlocked,
    };

/// The label of a field of a catalog app's source (`CatalogApp.source`). The
/// keys come from the catalog data, so one this does not know shows as it is.
String catalogSourceText(AppL10n l10n, String key) => switch (key) {
  'repo' => l10n.catalogSourceRepo,
  'commit' => l10n.catalogSourceCommit,
  'path' => l10n.catalogSourcePath,
  'license' => l10n.catalogSourceLicense,
  'verified' => l10n.catalogSourceVerified,
  _ => key,
};
