part of 'library_bloc.dart';

@freezed
sealed class LibraryEvent with _$LibraryEvent {
  const factory LibraryEvent.load() = LibraryLoadEvent;
  const factory LibraryEvent.open(String bottle) = LibraryOpenEvent;
  const factory LibraryEvent.run(String bottle, String program) =
      LibraryRunEvent;
  const factory LibraryEvent.stop(String bottle) = LibraryStopEvent;
  const factory LibraryEvent.detected(String bottle) = LibraryDetectedEvent;
  const factory LibraryEvent.closed(String bottle) = LibraryClosedEvent;
  const factory LibraryEvent.checkHints() = LibraryCheckHintsEvent;
}
