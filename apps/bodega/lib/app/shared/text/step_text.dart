import 'package:bodega/domain/entities/catalog_app.dart';
import 'package:bodega/domain/entities/gptk_step.dart';
import 'package:bodega/domain/entities/install_step.dart';
import 'package:bodega/l10n/l10n.dart';

// The steps of an install in the user's language (design §6). The states keep
// them as codes, so a language switch rewords a step already on screen (L6).
// One case per step and no default: a step added to the domain fails the
// build here until it has its words (L8).

/// What the install of [app] is doing, as the install panel's headline. A
/// sync mismatch names [app] and the sync it asks for.
String installStepText(AppL10n l10n, InstallStep step, CatalogApp app) =>
    switch (step) {
      // The download note's own words: the same meaning (L15).
      InstallUnpinnedDownloadStep(:final host) => l10n.installNoChecksum(host),
      InstallDownloadingStep() => l10n.stepDownloading,
      InstallSyncMismatchStep(:final bottleSync) => l10n.stepSyncMismatch(
        bottleSync,
        app.title,
        app.sync,
      ),
      InstallCreatingBottleStep(:final bottle) => l10n.stepCreatingBottle(
        bottle,
      ),
      InstallRegistryStep(:final value) => l10n.stepRegistry(value),
      InstallRunningInstallerStep() => l10n.stepRunningInstaller,
      InstallWaitingStep() => l10n.stepWaiting,
    };

/// What the D3DMetal install from a Game Porting Toolkit dmg is doing, under
/// the progress bar of D3DMetal's card.
String gptkStepText(AppL10n l10n, GptkStep step) => switch (step) {
  GptkStep.opening => l10n.stepGptkOpening,
  GptkStep.acceptLicense => l10n.stepGptkAcceptLicense,
  GptkStep.importing => l10n.stepGptkImporting,
};
