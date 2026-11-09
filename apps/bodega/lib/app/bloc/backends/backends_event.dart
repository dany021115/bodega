part of 'backends_bloc.dart';

@freezed
sealed class BackendsEvent with _$BackendsEvent {
  const factory BackendsEvent.load() = BackendsLoadEvent;
  const factory BackendsEvent.download(String name) = BackendsDownloadEvent;
  const factory BackendsEvent.cancel() = BackendsCancelEvent;
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
  const factory BackendsEvent.check(String bottle, String backend) =
      BackendsCheckEvent;
}
