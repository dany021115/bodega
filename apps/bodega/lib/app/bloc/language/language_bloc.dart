import 'package:bloc/bloc.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'language_event.dart';
part 'language_state.dart';
part 'language_bloc.freezed.dart';

/// The language the user picked; none follows the system.
@injectable
class LanguageBloc extends Bloc<LanguageEvent, LanguageState> {
  final Preferences preferences;

  LanguageBloc(this.preferences)
    : super(LanguageState(code: preferences.getLanguage())) {
    on<SetLanguageEvent>((event, emit) async {
      await preferences.saveLanguage(event.code);
      emit(state.copyWith(code: event.code));
    });
  }
}
