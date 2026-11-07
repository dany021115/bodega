part of 'add_app_bloc.dart';

@freezed
sealed class AddAppEvent with _$AddAppEvent {
  /// The bottle the dialog was opened from.
  const factory AddAppEvent.load(String bottle) = AddAppLoadEvent;
  const factory AddAppEvent.exeChosen(String path) = AddAppExeChosenEvent;
  const factory AddAppEvent.titleChanged(String title) =
      AddAppTitleChangedEvent;
  const factory AddAppEvent.installerToggled(bool value) =
      AddAppInstallerToggledEvent;
  const factory AddAppEvent.addToLibraryToggled(bool value) =
      AddAppAddToLibraryToggledEvent;
  const factory AddAppEvent.submit() = AddAppSubmitEvent;

  /// The user says the installer is done, even if the bottle never empties.
  const factory AddAppEvent.installerDone() = AddAppInstallerDoneEvent;
  const factory AddAppEvent.installedChosen(String path) =
      AddAppInstalledChosenEvent;
}
