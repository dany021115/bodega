import 'package:bodega/domain/entities/bottle_step.dart';
import 'package:bodega/domain/entities/mach9_step.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:bodega/l10n/l10n.dart';

// The runtimes' codes in the user's language (MA9): the engine dropdown, the
// bottle's engine fact and the native engine's steps. One case per code and
// no default: a code added to the domain fails the build here until it has
// its words.

/// An engine as an option of the new-bottle dialog's dropdown.
String runtimeKindText(AppL10n l10n, RuntimeKind kind) => switch (kind) {
  RuntimeKind.bodega => l10n.engineRosetta,
  RuntimeKind.mach9 => l10n.engineNative,
};

/// A bottle's engine as the value of its fact in the bottle's panel.
String runtimeChipText(AppL10n l10n, RuntimeKind kind) => switch (kind) {
  RuntimeKind.bodega => l10n.engineRosettaChip,
  RuntimeKind.mach9 => l10n.engineNativeChip,
};

/// What the native engine's install is doing, under its card's progress bar.
String mach9StepText(AppL10n l10n, Mach9Step step) => switch (step) {
  Mach9Step.downloadingMono => l10n.engineStepDownloadingMono,
  Mach9Step.downloading => l10n.engineStepDownloading,
  Mach9Step.mounting => l10n.engineStepMounting,
  Mach9Step.checkingSignature => l10n.engineStepCheckingSignature,
  Mach9Step.copying => l10n.engineStepCopying,
  Mach9Step.checking => l10n.engineStepChecking,
  Mach9Step.switching => l10n.engineStepSwitching,
};

/// What making a bottle is doing, beside the new-bottle dialog's spinner.
String bottleStepText(AppL10n l10n, BottleStep step) => switch (step) {
  BottleStep.prefix => l10n.newBottleCreating,
  BottleStep.mono => l10n.newBottleInstallingMono,
};
