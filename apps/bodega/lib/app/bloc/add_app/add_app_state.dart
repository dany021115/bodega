part of 'add_app_bloc.dart';

enum AddAppStep { form, creating, installing, pickInstalled, done }

@freezed
abstract class AddAppState with _$AddAppState {
  const AddAppState._();

  const factory AddAppState({
    @Default(AddAppStep.form) AddAppStep step,
    @Default([]) List<String> bottles,
    String? exe,
    @Default('') String title,

    /// Null means a new bottle.
    String? bottle,
    @Default(false) bool isInstaller,
    String? driveC,
    AppError? error,
  }) = _AddAppState;

  bool get canSubmit =>
      step == AddAppStep.form && exe != null && title.trim().isNotEmpty;
}
