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

  /// The user picked an engine: Graphics goes back to Automatic, as the
  /// names differ by engine (MA6).
  const factory NewBottleEvent.runtimeChanged(RuntimeKind runtime) =
      NewBottleRuntimeChangedEvent;

  /// Whether the native engine can make bottles here. Until the user picks an
  /// engine, it preselects Native when it can, Rosetta otherwise (D26).
  const factory NewBottleEvent.nativeAvailable(bool available) =
      NewBottleNativeAvailableEvent;
}
