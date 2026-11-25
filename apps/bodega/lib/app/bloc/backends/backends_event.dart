part of 'backends_bloc.dart';

@freezed
sealed class BackendsEvent with _$BackendsEvent {
  const factory BackendsEvent.load() = BackendsLoadEvent;

  /// MA1: looks up Mach9's latest release (GitHub at most once a day), at
  /// start and then every hour; a newer one gives one notice per version.
  const factory BackendsEvent.checkMach9() = BackendsCheckMach9Event;
  const factory BackendsEvent.download(String name) = BackendsDownloadEvent;
  const factory BackendsEvent.cancel() = BackendsCancelEvent;

  /// MR4, MU4: installs the runtime [kind] from [file] (a `.dmg` or a
  /// `Mach9.app`); without one, the latest release, from the Mach9.app found
  /// when it is that version or newer. [BackendsEvent.cancel] stops it.
  const factory BackendsEvent.installRuntime(RuntimeKind kind, {String? file}) =
      BackendsInstallRuntimeEvent;

  /// Whether a chosen `.dmg` goes once installed from.
  const factory BackendsEvent.setDeleteDmg(bool on) = BackendsSetDeleteDmgEvent;
  const factory BackendsEvent.installFile(String name, String tarball) =
      BackendsInstallFileEvent;

  /// I2: installs D3DMetal from [release]'s dmg, waiting for it in Downloads
  /// if it is not there yet.
  const factory BackendsEvent.installGptk(GptkRelease release) =
      BackendsInstallGptkEvent;

  /// I2: the user picked the dmg by hand.
  const factory BackendsEvent.installGptkDmg(String dmg) =
      BackendsInstallGptkDmgEvent;

  /// Stops waiting for the dmg, or for Apple's license.
  const factory BackendsEvent.cancelGptk() = BackendsCancelGptkEvent;

  /// Looks in Downloads again while waiting.
  const factory BackendsEvent.pollGptk() = BackendsPollGptkEvent;

  /// The probe for each of Mach9's graphics in [bottle] (PA4).
  const factory BackendsEvent.checkEngine(String bottle) =
      BackendsCheckEngineEvent;
  const factory BackendsEvent.check(String bottle, String backend) =
      BackendsCheckEvent;
}
