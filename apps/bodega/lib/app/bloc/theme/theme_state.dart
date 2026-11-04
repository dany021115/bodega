part of 'theme_bloc.dart';

@freezed
abstract class ThemeState with _$ThemeState {
  const factory ThemeState({@Default(true) bool isDark}) = _ThemeState;
}
