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

/// What the catalog says about an app besides its data (design §7): the note
/// on its status, why it is unstable (null when it is not), its notes, and its
/// known issues as (symptom, fix).
typedef CatalogProse = ({
  String statusNote,
  String? flaky,
  List<String> notes,
  List<(String, String)> issues,
});

/// The prose of the catalog app [id], in the words of [l10n], from its keys
/// per entry and field (L16). The English is the engine's text
/// (`catalog_data.dart`), which `catalog_text_test.dart` keeps equal; null for
/// an id the ARBs do not have.
CatalogProse? catalogProse(String id, AppL10n l10n) => switch (id) {
  'steam' => (
    statusNote: l10n.catalogSteamStatusNote,
    flaky: null,
    notes: [
      l10n.catalogSteamNote1,
      l10n.catalogSteamNote2,
      l10n.catalogSteamNote3,
      l10n.catalogSteamNote4,
    ],
    issues: [
      (l10n.catalogSteamIssue1Symptom, l10n.catalogSteamIssue1Fix),
      (l10n.catalogSteamIssue2Symptom, l10n.catalogSteamIssue2Fix),
      (l10n.catalogSteamIssue3Symptom, l10n.catalogSteamIssue3Fix),
      (l10n.catalogSteamIssue4Symptom, l10n.catalogSteamIssue4Fix),
      (l10n.catalogSteamIssue5Symptom, l10n.catalogSteamIssue5Fix),
      (l10n.catalogSteamIssue6Symptom, l10n.catalogSteamIssue6Fix),
      (l10n.catalogSteamIssue7Symptom, l10n.catalogSteamIssue7Fix),
    ],
  ),
  'rockstar' => (
    statusNote: l10n.catalogRockstarStatusNote,
    flaky: null,
    notes: [l10n.catalogRockstarNote1, l10n.catalogRockstarNote2],
    issues: [
      (l10n.catalogRockstarIssue1Symptom, l10n.catalogRockstarIssue1Fix),
      (l10n.catalogRockstarIssue2Symptom, l10n.catalogRockstarIssue2Fix),
      (l10n.catalogRockstarIssue3Symptom, l10n.catalogRockstarIssue3Fix),
    ],
  ),
  'ea-app' => (
    statusNote: l10n.catalogEaAppStatusNote,
    flaky: l10n.catalogEaAppFlaky,
    notes: [l10n.catalogEaAppNote1, l10n.catalogEaAppNote2],
    issues: [
      (l10n.catalogEaAppIssue1Symptom, l10n.catalogEaAppIssue1Fix),
      (l10n.catalogEaAppIssue2Symptom, l10n.catalogEaAppIssue2Fix),
    ],
  ),
  'ubisoft-connect' => (
    statusNote: l10n.catalogUbisoftConnectStatusNote,
    flaky: null,
    notes: [l10n.catalogUbisoftConnectNote1, l10n.catalogUbisoftConnectNote2],
    issues: [
      (
        l10n.catalogUbisoftConnectIssue1Symptom,
        l10n.catalogUbisoftConnectIssue1Fix,
      ),
    ],
  ),
  'battle-net' => (
    statusNote: l10n.catalogBattleNetStatusNote,
    flaky: l10n.catalogBattleNetFlaky,
    notes: [l10n.catalogBattleNetNote1, l10n.catalogBattleNetNote2],
    issues: [
      (l10n.catalogBattleNetIssue1Symptom, l10n.catalogBattleNetIssue1Fix),
      (l10n.catalogBattleNetIssue2Symptom, l10n.catalogBattleNetIssue2Fix),
    ],
  ),
  'epic-games' => (
    statusNote: l10n.catalogEpicGamesStatusNote,
    flaky: null,
    notes: [l10n.catalogEpicGamesNote1],
    issues: [
      (l10n.catalogEpicGamesIssue1Symptom, l10n.catalogEpicGamesIssue1Fix),
    ],
  ),
  'gog-galaxy' => (
    statusNote: l10n.catalogGogGalaxyStatusNote,
    flaky: null,
    notes: [],
    issues: [
      (l10n.catalogGogGalaxyIssue1Symptom, l10n.catalogGogGalaxyIssue1Fix),
    ],
  ),
  _ => null,
};
