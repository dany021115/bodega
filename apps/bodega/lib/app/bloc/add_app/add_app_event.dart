part of 'add_app_bloc.dart';

@freezed
sealed class AddAppEvent with _$AddAppEvent {
  const factory AddAppEvent.load() = AddAppLoadEvent;
  const factory AddAppEvent.exeChosen(String path) = AddAppExeChosenEvent;
  const factory AddAppEvent.titleChanged(String title) =
      AddAppTitleChangedEvent;

  /// Null means a new bottle.
  const factory AddAppEvent.bottleChosen(String? bottle) =
      AddAppBottleChosenEvent;
  const factory AddAppEvent.installerToggled(bool value) =
      AddAppInstallerToggledEvent;
  const factory AddAppEvent.submit() = AddAppSubmitEvent;

  /// The user says the installer is done, even if the bottle never empties.
  const factory AddAppEvent.installerDone() = AddAppInstallerDoneEvent;
  const factory AddAppEvent.installedChosen(String path) =
      AddAppInstalledChosenEvent;
}
