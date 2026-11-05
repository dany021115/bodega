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
  const factory LibraryEvent.stop(String bottle) = LibraryStopEvent;
  const factory LibraryEvent.detected(String bottle) = LibraryDetectedEvent;
  const factory LibraryEvent.closed(String bottle) = LibraryClosedEvent;
  const factory LibraryEvent.checkHints() = LibraryCheckHintsEvent;
}
