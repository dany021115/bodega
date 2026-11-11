import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/switch_game.dart';
import 'package:bodega/domain/entities/switch_status.dart';
import 'package:bodega/domain/repository/switch_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'switch_event.dart';
part 'switch_state.dart';
part 'switch_bloc.freezed.dart';

/// Switch games (switch-support design §9). App-wide, as a running game
/// outlives the page that opened it.
@lazySingleton
class SwitchBloc extends Bloc<SwitchEvent, SwitchState> {
  static const _launchPause = Duration(seconds: 2);

  /// The codes a native game's run ends with when the user quits it:
  /// nxnative's launcher gives 0, and its 70 and 134 are failures (design
  /// §4).
  static const _nativeNormal = {0};

  /// The codes a game file's run ends with when its window closes: 0 until a
  /// check on a real Mac tells what Ryubing gives (SA22).
  static const _gameFileNormal = {0};

  final SwitchRepository _repository;

  /// The logs of the runs followed, so that none is followed twice.
  final Set<String> _followed = {};

  /// Games opened in the last [_launchPause].
  final Set<String> _opening = {};

  /// Games a Stop from Bodega is ending: the code it causes says nothing.
  final Set<String> _stopping = {};

  SwitchBloc(this._repository) : super(const SwitchState()) {
    on<SwitchLoadEvent>((event, emit) async {
      _clearError(emit);
      final (status, games, runs) = await (
        _repository.status(),
        _repository.games(),
        _repository.running(),
      ).wait;
      emit(
        state.copyWith(
          isLoading: false,
          status: status.toNullable() ?? state.status,
          games: games.getOrElse((_) => state.games),
          running: {
            ...state.running,
            for (final run in runs) run.game: run.log,
          },
          error:
              status.getLeft().toNullable() ??
              games.getLeft().toNullable() ??
              state.error,
        ),
      );
      // Runs started before Bodega, or by another way in: found again here.
      for (final run in runs) {
        _follow(run.game, run.log);
      }
    });

    on<SwitchAddFilesEvent>(
      (event, emit) => _add(() => _repository.addFiles(event.paths), emit),
    );
    on<SwitchAddFolderEvent>(
      (event, emit) => _add(() => _repository.addFolder(event.folder), emit),
    );

    on<SwitchRemoveEvent>((event, emit) async {
      _clearError(emit);
      switch (await _repository.remove(event.path)) {
        case Left(value: final error):
          emit(state.copyWith(error: error));
        case Right():
          // A game that runs stays in running: its run's end still comes.
          final games = await _repository.games();
          emit(
            state.copyWith(
              games: games.getOrElse((_) => state.games),
              error: games.getLeft().toNullable() ?? state.error,
            ),
          );
      }
    });

    on<SwitchChooseEmulatorEvent>((event, emit) async {
      _clearError(emit);
      switch (await _repository.chooseEmulator(event.app)) {
        case Left(value: final error):
          emit(state.copyWith(error: error));
        case Right():
          final status = await _repository.status();
          emit(
            state.copyWith(
              status: status.toNullable() ?? state.status,
              error: status.getLeft().toNullable() ?? state.error,
            ),
          );
      }
    });

    on<SwitchSetFullscreenEvent>((event, emit) async {
      _clearError(emit);
      final result = await _repository.setFullscreen(event.value);
      result.match(
        (error) => emit(state.copyWith(error: error)),
        (_) => emit(
          state.copyWith(
            status: state.status?.copyWith(fullscreen: event.value),
          ),
        ),
      );
    });

    on<SwitchOpenEvent>((event, emit) async {
      final path = event.path;
      // A launch takes milliseconds, so a double click would get past the
      // check of a game already running: one open per pause.
      if (!_opening.add(path)) return;
      Timer(_launchPause, () => _opening.remove(path));
      _clearError(emit);
      final result = await _repository.open(path);
      result.match((error) => emit(state.copyWith(error: error)), (log) {
        emit(state.copyWith(running: {...state.running, path: log}));
        _follow(path, log);
      });
    });

    on<SwitchStopEvent>((event, emit) async {
      final path = event.path;
      _clearError(emit);
      // Marked before the call: the engine waits for the run to end, so its
      // end may come first.
      _stopping.add(path);
      final result = await _repository.stop(path);
      result.match(
        (error) {
          _stopping.remove(path);
          emit(state.copyWith(error: error));
        },
        // With no run to end here, no end takes the mark.
        (_) {
          if (!state.running.containsKey(path)) _stopping.remove(path);
        },
      );
    });

    on<SwitchEndedEvent>((event, emit) {
      final path = event.path;
      final stopped = _stopping.remove(path);
      final running = {...state.running}..remove(path);
      final code = event.code;
      // A game the list no longer holds counts as a game file.
      final game = state.games.where((game) => game.path == path).firstOrNull;
      final normal = (game?.native ?? false) ? _nativeNormal : _gameFileNormal;
      if (code == null || stopped || normal.contains(code)) {
        return emit(state.copyWith(running: running));
      }
      emit(
        state.copyWith(
          running: running,
          notice: SwitchNotice.exited(game?.title ?? _fileName(path), code),
          noticeId: state.noticeId + 1,
        ),
      );
    });
  }

  /// Each event that calls the repository starts here, so that the same
  /// failure twice is two errors (SA12).
  void _clearError(Emitter<SwitchState> emit) {
    if (state.error != null) emit(state.copyWith(error: null));
  }

  /// Runs [adding], one add at a time as the page offers it, then reads the
  /// list again and tells what the add found.
  Future<void> _add(
    Future<Either<AppError, ({int added, int known})>> Function() adding,
    Emitter<SwitchState> emit,
  ) async {
    if (state.isAdding) return;
    emit(state.copyWith(isAdding: true, error: null));
    switch (await adding()) {
      case Left(value: final error):
        emit(state.copyWith(isAdding: false, error: error));
      case Right(value: (:final added, :final known)):
        final games = await _repository.games();
        emit(
          state.copyWith(
            isAdding: false,
            games: games.getOrElse((_) => state.games),
            notice: SwitchNotice.added(added, known),
            noticeId: state.noticeId + 1,
            error: games.getLeft().toNullable() ?? state.error,
          ),
        );
    }
  }

  /// Waits for the run in [log] to end and tells its code, unless the bloc
  /// is closed by then.
  Future<void> _follow(String path, String log) async {
    if (!_followed.add(log)) return;
    final code = await _repository.waitRun(log);
    _followed.remove(log);
    if (!isClosed) add(SwitchEvent.ended(path, code));
  }
}

/// The last part of [path]: what names a game the list no longer holds.
String _fileName(String path) => path.substring(path.lastIndexOf('/') + 1);
