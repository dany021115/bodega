import 'package:bloc/bloc.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'theme_event.dart';
part 'theme_state.dart';
part 'theme_bloc.freezed.dart';

@injectable
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final Preferences preferences;

  ThemeBloc(this.preferences)
    : super(ThemeState(isDark: preferences.getDarkTheme() ?? true)) {
    on<ToggleThemeEvent>((event, emit) async {
      final value = !state.isDark;
      await preferences.saveDarkTheme(value);
      emit(state.copyWith(isDark: value));
    });
  }
}
