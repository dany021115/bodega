part of 'bottle_detail_bloc.dart';

@freezed
abstract class BottleDetailState with _$BottleDetailState {
  const factory BottleDetailState({
    @Default(true) bool isLoading,
    @Default(false) bool isBusy,
    @Default(false) bool deleted,

    /// The new name, once a rename has succeeded.
    String? renamedTo,

    /// The long job running on the bottle, together with [isBusy].
    BottleWork? working,

    /// The copy's name, once a duplicate has succeeded.
    String? duplicatedTo,

    /// The file written, once an export has succeeded.
    String? exportedTo,
    BottleDetail? detail,
    String? logPath,
    @Default([]) List<String> logLines,
    AppError? error,
  }) = _BottleDetailState;
}

/// V14: the long jobs on a bottle that the page shows while they run.
enum BottleWork { duplicating, exporting }
