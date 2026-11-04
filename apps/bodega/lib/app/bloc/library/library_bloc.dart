import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/repository/library_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'library_event.dart';
part 'library_state.dart';
part 'library_bloc.freezed.dart';

@lazySingleton
class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final LibraryRepository _repository;
  final Map<String, ({DateTime since, String? log})> _runs = {};
  final Set<String> _watching = {};
  final Set<String> _opening = {};
  Timer? _hintTimer;

  LibraryBloc(this._repository) : super(const LibraryState()) {
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
      if (state.open.contains(bottle) || !_opening.add(bottle)) return;
      final since = DateTime.now();
      final result = await _repository.open(bottle);
      _opening.remove(bottle);
      result.match((error) => emit(state.copyWith(error: error)), (log) {
        _begin(bottle, since, log);
        emit(
          state.copyWith(
            open: {...state.open, bottle},
            hints: {...state.hints}..remove(bottle),
            error: null,
          ),
        );
        _follow(bottle, log);
      });
    });

    on<LibraryRunEvent>((event, emit) async {
      final bottle = event.bottle;
      final since = _runs[bottle]?.since ?? DateTime.now();
      final result = await _repository.run(bottle, event.program);
      result.match((error) => emit(state.copyWith(error: error)), (log) {
        _begin(bottle, since, log);
        emit(state.copyWith(open: {...state.open, bottle}, error: null));
        _follow(bottle, log);
      });
    });

    on<LibraryStopEvent>((event, emit) async {
      final result = await _repository.stop(event.bottle);
      result.match((error) => emit(state.copyWith(error: error)), (_) {});
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

  /// Each hint once per run: on the card, and one toast.
  void _addHints(
    String bottle,
    List<String> found,
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
