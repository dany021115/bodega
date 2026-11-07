part of 'add_app_bloc.dart';

enum AddAppStep { form, installing, pickInstalled, done }

@freezed
abstract class AddAppState with _$AddAppState {
  const AddAppState._();

  const factory AddAppState({
    @Default(AddAppStep.form) AddAppStep step,
    @Default('') String bottle,
    String? exe,
    @Default('') String title,
    @Default(false) bool isInstaller,

    /// Off leaves the app in its bottle, out of the library.
    @Default(true) bool addToLibrary,
    String? driveC,
    AppError? error,
  }) = _AddAppState;

  bool get canSubmit =>
      step == AddAppStep.form && exe != null && title.trim().isNotEmpty;
}
