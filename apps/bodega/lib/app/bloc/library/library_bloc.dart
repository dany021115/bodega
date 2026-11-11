import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/entities/run_hint.dart';
import 'package:bodega/domain/repository/bottle_repository.dart';
import 'package:bodega/domain/repository/library_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'library_event.dart';
part 'library_state.dart';
part 'library_bloc.freezed.dart';

@lazySingleton
class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  static const _launchPause = Duration(seconds: 2);

  final LibraryRepository _repository;
  final BottleRepository _bottles;
  final Map<String, ({DateTime since, String? log})> _runs = {};
  final Set<String> _watching = {};
  final Set<String> _opening = {};
  Timer? _hintTimer;

  LibraryBloc(this._repository, this._bottles) : super(const LibraryState()) {
    on<LibraryLoadEvent>((event, emit) async {
      final result = await _repository.apps();
      result.match(
        (error) => emit(state.copyWith(isLoading: false, error: error)),
        (apps) {
          emit(state.copyWith(isLoading: false, apps: apps, error: null));
        },
      );
      // Bottles without an app count too: Botellas shows them open.
      (await _repository.bottleNames()).forEach(_watch);
    });

    on<LibraryOpenEvent>((event, emit) async {
      final bottle = event.bottle;
      // Another of its applications may open; this one, not twice in a row: a
      // launch takes milliseconds, and so a double click would get past it.
      final launch = '$bottle ${event.key}';
      if (!_opening.add(launch)) return;
      Timer(_launchPause, () => _opening.remove(launch));
      final wasOpen = state.open.contains(bottle);
      final since = _runs[bottle]?.since ?? DateTime.now();
      final result = await _repository.open(bottle, key: event.key);
      result.match((error) => emit(state.copyWith(error: error)), (log) {
        _begin(bottle, since, log);
        emit(
          state.copyWith(
            open: {...state.open, bottle},
            hints: wasOpen ? state.hints : ({...state.hints}..remove(bottle)),
            error: null,
          ),
        );
        _follow(bottle, log);
      });
    });

    on<LibraryRunEvent>((event, emit) async {
      final bottle = event.bottle;
      final since = _runs[bottle]?.since ?? DateTime.now();
      final result = await _repository.run(
        bottle,
        event.program,
        args: event.args,
      );
      result.match(
        (error) => emit(state.copyWith(error: error)),
        (log) => _track(bottle, since, log, emit),
      );
    });

    on<LibraryTrackEvent>(
      (event, emit) => _track(
        event.bottle,
        _runs[event.bottle]?.since ?? DateTime.now(),
        event.log,
        emit,
      ),
    );

    on<LibraryStopEvent>((event, emit) async {
      final result = await _repository.stop(event.bottle);
      result.match((error) => emit(state.copyWith(error: error)), (_) {});
    });

    on<LibrarySetInLibraryEvent>((event, emit) async {
      final result = await _bottles.setInLibrary(
        event.bottle,
        event.key,
        event.value,
      );
      result.match(
        (error) => emit(state.copyWith(error: error)),
        (_) => add(const LibraryEvent.load()),
      );
    });

    on<LibrarySetHudEvent>((event, emit) async {
      final result = await _bottles.setHud(
        event.bottle,
        event.key,
        event.value,
      );
      result.match(
        (error) => emit(state.copyWith(error: error)),
        (_) => add(const LibraryEvent.load()),
      );
    });

    on<LibraryDetectedEvent>((event, emit) {
      if (_runs.containsKey(event.bottle)) return;
      _begin(event.bottle, DateTime.now(), null);
      emit(state.copyWith(open: {...state.open, event.bottle}));
    });

    on<LibraryClosedEvent>((event, emit) async {
      final bottle = event.bottle;
      final run = _runs.remove(bottle);
      if (run == null) return;
      if (_runs.isEmpty) {
        _hintTimer?.cancel();
        _hintTimer = null;
      }
      emit(state.copyWith(open: {...state.open}..remove(bottle)));
      // What ran may have added apps (an installer's shortcuts, a Steam game).
      add(const LibraryEvent.load());

      final log = run.log;
      _addHints(bottle, [
        ..._repository.antiCheatHints(bottle, run.since),
        if (log != null) ...await _repository.hintsIn(log),
      ], emit);
    });

    on<LibraryCheckHintsEvent>((event, emit) {
      for (final MapEntry(key: bottle, value: run) in _runs.entries) {
        _addHints(bottle, _repository.antiCheatHints(bottle, run.since), emit);
      }
    });
  }

  void _track(
    String bottle,
    DateTime since,
    String log,
    Emitter<LibraryState> emit,
  ) {
    _begin(bottle, since, log);
    emit(state.copyWith(open: {...state.open, bottle}, error: null));
    _follow(bottle, log);
  }

  void _begin(String bottle, DateTime since, String? log) {
    _runs[bottle] = (since: since, log: log);
    _hintTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => add(const LibraryEvent.checkHints()),
    );
  }

  /// A launched app stays open until its first process is gone and then the
  /// last one: Steam restarting itself exits with 42 while the bottle lives on.
  // ponytail: if the launch script dies by SIGKILL there is no exit file, and
  // it stays open until Bodega is reopened.
  Future<void> _follow(String bottle, String log) async {
    await _repository.firstExit(log);
    await _repository.waitBottle(bottle);
    if (!isClosed) add(LibraryEvent.closed(bottle));
  }

  /// Finds what is already running, as after reopening Bodega: with no server
  /// `waitBottle` returns at once (design §5).
  Future<void> _watch(String bottle) async {
    if (_runs.containsKey(bottle) || !_watching.add(bottle)) return;
    var ended = false;
    final wait = _repository
        .waitBottle(bottle)
        .whenComplete(() => ended = true);
    await Future.any<void>([
      wait,
      Future<void>.delayed(const Duration(seconds: 1)),
    ]);
    if (!ended && !isClosed) {
      add(LibraryEvent.detected(bottle));
      await wait;
      if (!isClosed) add(LibraryEvent.closed(bottle));
    }
    _watching.remove(bottle);
  }

  /// Each hint once per run: on the card, and one toast. Hints are values, so
  /// an equal one is already there (E14).
  void _addHints(
    String bottle,
    List<RunHint> found,
    Emitter<LibraryState> emit,
  ) {
    for (final hint in found) {
      final known = state.hints[bottle] ?? const [];
      if (known.contains(hint)) continue;
      emit(
        state.copyWith(
          hints: {
            ...state.hints,
            bottle: [...known, hint],
          },
          toast: hint,
          toastId: state.toastId + 1,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _hintTimer?.cancel();
    return super.close();
  }
}
