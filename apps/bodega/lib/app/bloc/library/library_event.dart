part of 'library_bloc.dart';

@freezed
sealed class LibraryEvent with _$LibraryEvent {
  const factory LibraryEvent.load() = LibraryLoadEvent;
  const factory LibraryEvent.open(String bottle, [String? key]) =
      LibraryOpenEvent;
  const factory LibraryEvent.run(
    String bottle,
    String program, [
    @Default([]) List<String> args,
  ]) = LibraryRunEvent;

  /// Follows a launch made elsewhere, such as with options.
  const factory LibraryEvent.track(String bottle, String log) =
      LibraryTrackEvent;
  /// Stops the bottle, or with [key] only that app.
  const factory LibraryEvent.stop(String bottle, [String? key]) =
      LibraryStopEvent;
  const factory LibraryEvent.setInLibrary(
    String bottle,
    String key,
    bool value,
  ) = LibrarySetInLibraryEvent;
  const factory LibraryEvent.setHud(String bottle, String key, bool value) =
      LibrarySetHudEvent;
  const factory LibraryEvent.detected(String bottle) = LibraryDetectedEvent;
  const factory LibraryEvent.closed(String bottle) = LibraryClosedEvent;
  const factory LibraryEvent.appClosed(String bottle, String key) =
      LibraryAppClosedEvent;
  const factory LibraryEvent.checkHints() = LibraryCheckHintsEvent;
}
