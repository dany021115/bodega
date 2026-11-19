part of 'new_bottle_bloc.dart';

@freezed
abstract class NewBottleState with _$NewBottleState {
  const NewBottleState._();

  const factory NewBottleState({
    @Default('') String name,
    @Default('win11') String windows,
    @Default('auto') String backend,

    /// The engine of the new bottle, fixed once it is made (D1).
    @Default(RuntimeKind.bodega) RuntimeKind runtime,

    /// The user picked [runtime], so the default no longer moves it.
    @Default(false) bool runtimePicked,

    /// What making it is doing, as a code: the dialog words it.
    BottleStep? step,

    /// The bottle was made, but Wine Mono, its last step, failed: [error]
    /// says why, and the bottle's page offers it again.
    @Default(false) bool monoFailed,

    /// Names of the bottles already made, to refuse a repeated one.
    @Default([]) List<String> taken,
    @Default(false) bool isCreating,
    String? createdName,
    AppError? error,
  }) = _NewBottleState;

  bool get canSubmit =>
      !isCreating &&
      _validName.hasMatch(name) &&
      !taken.any((bottle) => bottle.toLowerCase() == name.toLowerCase());
}
