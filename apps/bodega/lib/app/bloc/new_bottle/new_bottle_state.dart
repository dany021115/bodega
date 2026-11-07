part of 'new_bottle_bloc.dart';

@freezed
abstract class NewBottleState with _$NewBottleState {
  const NewBottleState._();

  const factory NewBottleState({
    @Default('') String name,
    @Default('win11') String windows,
    @Default('auto') String backend,

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
