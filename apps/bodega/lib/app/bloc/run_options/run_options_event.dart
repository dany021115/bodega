part of 'run_options_bloc.dart';

@freezed
sealed class RunOptionsEvent with _$RunOptionsEvent {
  const factory RunOptionsEvent.start({
    required String bottle,
    @Default('') String program,
    @Default('') String args,
    @Default('') String title,
  }) = RunOptionsStartEvent;

  /// The form as the user leaves it.
  const factory RunOptionsEvent.changed(RunOptionsState state) =
      RunOptionsChangedEvent;
  const factory RunOptionsEvent.submit() = RunOptionsSubmitEvent;
}
