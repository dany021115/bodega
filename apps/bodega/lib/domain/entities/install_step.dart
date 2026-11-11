import 'package:freezed_annotation/freezed_annotation.dart';

part 'install_step.freezed.dart';

/// What a catalog install is doing (I1): the engine's `InstallStep`, which
/// `data/` maps here. The state keeps it as a code and the install panel words
/// it, so a language switch rewords it (L6).
@freezed
sealed class InstallStep with _$InstallStep {
  /// The catalog pins no checksum for the installer, so its download relies
  /// on HTTPS and on [host], the server it comes from.
  const factory InstallStep.unpinnedDownload(String host) =
      InstallUnpinnedDownloadStep;

  /// Downloads the installer.
  const factory InstallStep.downloading() = InstallDownloadingStep;

  /// Installs into an existing bottle whose sync, [bottleSync], is not the
  /// one the app asks for: the bottle keeps its own (M12).
  const factory InstallStep.syncMismatch(String bottleSync) =
      InstallSyncMismatchStep;

  /// Creates the app's own [bottle].
  const factory InstallStep.creatingBottle(String bottle) =
      InstallCreatingBottleStep;

  /// Writes [value], one of the registry values the app needs.
  const factory InstallStep.registry(String value) = InstallRegistryStep;

  /// Runs the installer.
  const factory InstallStep.runningInstaller() = InstallRunningInstallerStep;

  /// The installer exited: waits for what it left running to end (I6).
  const factory InstallStep.waiting() = InstallWaitingStep;
}
