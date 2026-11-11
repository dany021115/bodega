import 'package:bloc/bloc.dart';
import 'package:bodega/data/service/preference.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'locale_event.dart';
part 'locale_state.dart';
part 'locale_bloc.freezed.dart';

/// The language chosen in Settings, or none to follow the system's. Kept
/// between runs, and read here, so the first frame is already in it (L5).
@lazySingleton
class LocaleBloc extends Bloc<LocaleEvent, LocaleState> {
  final Preferences _preferences;

  LocaleBloc(this._preferences)
    : super(LocaleState(code: _supported(_preferences.getLanguage()))) {
    on<LocaleSetEvent>((event, emit) async {
      final code = _supported(event.code);
      // It applies at once; the save only keeps it for the next start.
      emit(state.copyWith(code: code));
      await _preferences.saveLanguage(code);
    });
  }

  /// [code] if the app supports it, or null: a language the app doesn't have
  /// (saved by hand, or by a later version) follows the system's.
  static String? _supported(String? code) =>
      AppL10n.supportedLocales.any((locale) => locale.languageCode == code)
      ? code
      : null;
}
