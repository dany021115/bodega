part of 'bottle_detail_bloc.dart';

@freezed
sealed class BottleDetailEvent with _$BottleDetailEvent {
  const factory BottleDetailEvent.load(String name) = BottleDetailLoadEvent;
  const factory BottleDetailEvent.setBackend(String backend) =
      BottleDetailSetBackendEvent;
  const factory BottleDetailEvent.setSync(String sync) =
      BottleDetailSetSyncEvent;

  /// Moves the bottle to the Native engine (PA8).
  const factory BottleDetailEvent.moveToNative() =
      BottleDetailMoveToNativeEvent;

  /// A Native engine bottle's retina mode (PA1).
  const factory BottleDetailEvent.setRetina(RetinaMode mode) =
      BottleDetailSetRetinaEvent;
  const factory BottleDetailEvent.setHighRes(bool value) =
      BottleDetailSetHighResEvent;
  const factory BottleDetailEvent.setWindows(String version) =
      BottleDetailSetWindowsEvent;
  const factory BottleDetailEvent.setDlss(bool value) =
      BottleDetailSetDlssEvent;
  const factory BottleDetailEvent.setAvx(bool value) = BottleDetailSetAvxEvent;
  const factory BottleDetailEvent.setDxvkAsync(bool value) =
      BottleDetailSetDxvkAsyncEvent;

  /// U4: null goes back to the host's user name.
  const factory BottleDetailEvent.setUser(String? user) =
      BottleDetailSetUserEvent;
  const factory BottleDetailEvent.setGpu(String gpu) = BottleDetailSetGpuEvent;
  const factory BottleDetailEvent.setGamemode(bool value) =
      BottleDetailSetGamemodeEvent;
  const factory BottleDetailEvent.removeException(String exe) =
      BottleDetailRemoveExceptionEvent;
  const factory BottleDetailEvent.hideApp(String key) =
      BottleDetailHideAppEvent;
  const factory BottleDetailEvent.delete() = BottleDetailDeleteEvent;
  const factory BottleDetailEvent.rename(String newName) =
      BottleDetailRenameEvent;
  const factory BottleDetailEvent.setInLibrary(String key, bool value) =
      BottleDetailSetInLibraryEvent;
  const factory BottleDetailEvent.setHud(String key, bool value) =
      BottleDetailSetHudEvent;
  const factory BottleDetailEvent.openLog(String path) =
      BottleDetailOpenLogEvent;

  /// MB7: installs Wine Mono into the native bottle.
  const factory BottleDetailEvent.installMono() = BottleDetailInstallMonoEvent;
}
