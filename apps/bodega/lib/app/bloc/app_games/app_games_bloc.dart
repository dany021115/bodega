import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/domain/repository/game_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'app_games_event.dart';
part 'app_games_state.dart';
part 'app_games_bloc.freezed.dart';

/// A bottle's Games section (A4): what each app gets at launch, its switch,
/// and its report.
@injectable
class AppGamesBloc extends Bloc<AppGamesEvent, AppGamesState> {
  final GameRepository _games;

  AppGamesBloc(this._games) : super(const AppGamesState()) {
    on<AppGamesLoadEvent>((event, emit) async {
      emit(state.copyWith(bottle: event.bottle));
      final result = await _games.appGames(event.bottle);
      result.match(
        (error) => emit(state.copyWith(isLoading: false, error: error)),
        (apps) =>
            emit(state.copyWith(isLoading: false, apps: apps, error: null)),
      );
    });
    on<AppGamesSetOnEvent>((event, emit) async {
      final result = await _games.setOn(state.bottle, event.key, event.on);
      result.match(
        (error) => emit(state.copyWith(error: error)),
        (_) => add(AppGamesEvent.load(state.bottle)),
      );
    });
    on<AppGamesReportEvent>((event, emit) async {
      final saved = await _games.setVerdict(
        state.bottle,
        event.game.key,
        event.verdict,
      );
      if (saved.isLeft()) {
        emit(state.copyWith(error: saved.getLeft().toNullable()));
        return;
      }
      final url = await _games.reportUrl(event.game, event.verdict, event.note);
      url.match(
        (error) => emit(state.copyWith(error: error)),
        (url) =>
            emit(state.copyWith(report: url, reportId: state.reportId + 1)),
      );
      add(AppGamesEvent.load(state.bottle));
    });
  }
}
