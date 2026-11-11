part of 'switch_bloc.dart';

@freezed
sealed class SwitchEvent with _$SwitchEvent {
  /// Reads the status, the games and the runs, and follows each run.
  const factory SwitchEvent.load() = SwitchLoadEvent;

  /// Adds game files and native games picked on the page.
  const factory SwitchEvent.addFiles(List<String> paths) = SwitchAddFilesEvent;

  /// Adds the games a folder holds.
  const factory SwitchEvent.addFolder(String folder) = SwitchAddFolderEvent;

  /// Takes a game out of the list. Its file stays where it is.
  const factory SwitchEvent.remove(String path) = SwitchRemoveEvent;

  /// Keeps [app] as the emulator while the Applications folders hold none.
  const factory SwitchEvent.chooseEmulator(String app) =
      SwitchChooseEmulatorEvent;

  /// Whether games open full screen, from their next launch.
  const factory SwitchEvent.setFullscreen(bool value) =
      SwitchSetFullscreenEvent;

  const factory SwitchEvent.open(String path) = SwitchOpenEvent;
  const factory SwitchEvent.stop(String path) = SwitchStopEvent;

  /// A followed run of [path] ended with [code], or null when that cannot be
  /// told. The bloc adds it itself.
  const factory SwitchEvent.ended(String path, int? code) = SwitchEndedEvent;
}
