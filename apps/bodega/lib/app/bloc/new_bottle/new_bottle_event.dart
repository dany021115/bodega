part of 'new_bottle_bloc.dart';

@freezed
sealed class NewBottleEvent with _$NewBottleEvent {
  const factory NewBottleEvent.load() = NewBottleLoadEvent;
  const factory NewBottleEvent.nameChanged(String name) =
      NewBottleNameChangedEvent;
  const factory NewBottleEvent.windowsChanged(String windows) =
      NewBottleWindowsChangedEvent;
  const factory NewBottleEvent.backendChanged(String backend) =
      NewBottleBackendChangedEvent;
  const factory NewBottleEvent.submit() = NewBottleSubmitEvent;

  /// V13: a bottle from an exported `.tar.gz`.
  const factory NewBottleEvent.import(String file) = NewBottleImportEvent;
}
