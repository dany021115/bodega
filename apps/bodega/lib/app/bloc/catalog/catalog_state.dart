part of 'catalog_bloc.dart';

@freezed
abstract class CatalogState with _$CatalogState {
  const CatalogState._();

  static const minAntiCheatQuery = 2;

  const factory CatalogState({
    @Default(true) bool isLoading,
    @Default([]) List<CatalogApp> apps,
    @Default('') String query,
    @Default([]) List<AntiCheatGame> antiCheat,
    AppError? antiCheatError,
    AppError? error,
  }) = _CatalogState;

  String get _text => query.trim().toLowerCase();

  List<CatalogApp> get visibleApps => apps
      .where(
        (app) =>
            app.id.contains(_text) || app.title.toLowerCase().contains(_text),
      )
      .toList();

  bool get showsAntiCheat => _text.length >= minAntiCheatQuery;

  List<AntiCheatGame> get antiCheatMatches => showsAntiCheat
      ? antiCheat
            .where((game) => game.title.toLowerCase().contains(_text))
            .take(5)
            .toList()
      : const [];
}
