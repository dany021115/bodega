part of 'update_bloc.dart';

@freezed
sealed class UpdateEvent with _$UpdateEvent {
  /// A1: asks for a newer version; at start, in a release build.
  const factory UpdateEvent.check() = UpdateCheckEvent;

  /// "Ahora no": no more notices of this version.
  const factory UpdateEvent.skip() = UpdateSkipEvent;

  /// A4: downloads, checks and installs it, then closes the app.
  const factory UpdateEvent.install() = UpdateInstallEvent;

  const factory UpdateEvent.cancel() = UpdateCancelEvent;
}
