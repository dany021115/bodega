part of 'update_bloc.dart';

@freezed
sealed class UpdateEvent with _$UpdateEvent {
  /// A1: asks for a newer version; at start, in a release build.
  const factory UpdateEvent.check() = UpdateCheckEvent;

  /// "Not now": closes the dialog for this session and saves nothing, so the
  /// next start shows the version again (issue #19).
  const factory UpdateEvent.dismiss() = UpdateDismissEvent;

  /// A4: downloads, checks and installs it, then closes the app.
  const factory UpdateEvent.install() = UpdateInstallEvent;

  const factory UpdateEvent.cancel() = UpdateCancelEvent;
}
