import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:bodega/domain/entities/log_hint.dart';
import 'package:bodega/domain/entities/native_option.dart';
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
  final Map<String, Map<String, String>> _appLogs = {};
  final Set<String> _watching = {};
  final Set<String> _opening = {};
  Timer? _hintTimer;
  bool _reaped = false;

  /// Each running app's CPU samples, by its log, the last minute (ER5).
  final Map<String, List<double>> _cpu = {};

  /// How often a relaunched app is looked for (ER4).
  @visibleForTesting
  static Duration relaunchPoll = const Duration(seconds: 5);

  LibraryBloc(this._repository, this._bottles) : super(const LibraryState()) {
    on<LibraryLoadEvent>((event, emit) async {
      // ER3: once per start, what deleted or stopped bottles left behind.
      if (!_reaped) {
        _reaped = true;
        final ended = await _repository.reapOrphans();
        if (ended > 0) {
          emit(
            state.copyWith(
              toast: RunHint.orphans(ended),
              toastId: state.toastId + 1,
            ),
          );
        }
      }
      final result = await _repository.apps();
      result.match(
        (error) => emit(state.copyWith(isLoading: false, error: error)),
        (apps) {
          emit(state.copyWith(isLoading: false, apps: apps, error: null));
        },
      );
      // Bottles without an app count too: the sidebar's BOTTLES list shows
      // them open.
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
        final key = event.key ?? _firstKey(bottle);
        if (key != null) {
          _appLogs.putIfAbsent(bottle, () => {})[key] = log;
          _followApp(bottle, key, log);
        }
        emit(
          state.copyWith(
            open: {...state.open, bottle},
            running: key == null ? state.running : _withRunning(bottle, key),
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
      final key = event.key;
      final log = key == null ? null : _appLogs[event.bottle]?[key];
      // An app with no live run has nothing to stop.
      if (key != null && log == null) return;
      final result = log == null
          ? await _repository.stop(event.bottle)
          : await _repository.stopApp(log);
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

    on<LibrarySetNativeOptionEvent>((event, emit) async {
      final result = await _bottles.setNativeOption(
        event.bottle,
        event.key,
        event.option,
        event.on,
      );
      result.match(
        (error) => emit(state.copyWith(error: error)),
        (_) => add(const LibraryEvent.load()),
      );
    });

    on<LibraryDetectedEvent>((event, emit) async {
      final bottle = event.bottle;
      if (_runs.containsKey(bottle)) return;
      _begin(bottle, DateTime.now(), null);
      final found = await _repository.runningApps(bottle);
      final apps = found.match(
        (_) => const <({String key, String log})>[],
        (apps) => apps,
      );
      for (final app in apps) {
        _appLogs.putIfAbsent(bottle, () => {})[app.key] = app.log;
        _followApp(bottle, app.key, app.log);
      }
      emit(
        state.copyWith(
          open: {...state.open, bottle},
          running: apps.isEmpty
              ? state.running
              : {
                  ...state.running,
                  bottle: {for (final app in apps) app.key},
                },
        ),
      );
    });

    on<LibraryClosedEvent>((event, emit) async {
      final bottle = event.bottle;
      _appLogs.remove(bottle);
      final run = _runs.remove(bottle);
      if (run == null) return;
      if (_runs.isEmpty) {
        _hintTimer?.cancel();
        _hintTimer = null;
      }
      emit(
        state.copyWith(
          open: {...state.open}..remove(bottle),
          running: {...state.running}..remove(bottle),
        ),
      );
      // What ran may have added apps (an installer's shortcuts, a Steam game).
      add(const LibraryEvent.load());

      final log = run.log;
      _addHints(bottle, [
        ..._repository.antiCheatHints(bottle, run.since),
        if (log != null) ...await _repository.hintsIn(log),
      ], emit);
    });

    on<LibraryAppClosedEvent>((event, emit) {
      _appLogs[event.bottle]?.remove(event.key);
      final running = {...state.running};
      final keys = {...?running[event.bottle]}..remove(event.key);
      if (keys.isEmpty) {
        running.remove(event.bottle);
      } else {
        running[event.bottle] = keys;
      }
      emit(state.copyWith(running: running));
    });

    on<LibraryCheckHintsEvent>((event, emit) async {
      for (final MapEntry(key: bottle, value: run) in _runs.entries) {
        _addHints(bottle, _repository.antiCheatHints(bottle, run.since), emit);
      }
      // ER5: each running app's CPU, kept a minute, against its log.
      for (final MapEntry(key: bottle, value: logs) in {..._appLogs}.entries) {
        for (final log in logs.values) {
          final cpu = await _repository.appCpu(bottle, log);
          if (cpu == null) continue;
          final samples = (_cpu[log] ??= [])..add(cpu);
          if (samples.length > 12) samples.removeAt(0);
          if (await _repository.runHung(log, samples)) {
            _addHints(bottle, const [RunHint.log(LogHint.stuckLock)], emit);
          }
        }
      }
    });

    on<LibraryOpenWithRosettaEvent>((event, emit) async {
      final title =
          state.apps
              .where((a) => a.bottle == event.bottle && a.key == event.key)
              .firstOrNull
              ?.title ??
          event.key;
      emit(
        state.copyWith(
          toast: RunHint.rosettaPreparing(title),
          toastId: state.toastId + 1,
        ),
      );
      final moved = await _repository.openWithRosetta(event.bottle, event.key);
      moved.match((error) => emit(state.copyWith(error: error)), (target) {
        emit(
          state.copyWith(
            toast: RunHint.rosettaReady(title, target.bottle),
            toastId: state.toastId + 1,
          ),
        );
        add(const LibraryEvent.load());
        add(LibraryEvent.open(target.bottle, target.key));
      });
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

  /// An app's own run ends when its first process exits. A run replaced by a
  /// newer launch of the same app no longer counts, so it reports nothing.
  Future<void> _followApp(String bottle, String key, String log) async {
    await _repository.firstExit(log);
    bool current() => !isClosed && _appLogs[bottle]?[key] == log;
    // ER4: a game that started a second copy of itself and exited runs on.
    while (current() && await _repository.appStillRunning(bottle, log)) {
      await Future<void>.delayed(relaunchPoll);
    }
    if (current()) add(LibraryEvent.appClosed(bottle, key));
  }

  /// The bottle's first app, as the engine opens it when no key is given.
  String? _firstKey(String bottle) =>
      state.apps.where((app) => app.bottle == bottle).firstOrNull?.key;

  Map<String, Set<String>> _withRunning(String bottle, String key) => {
    ...state.running,
    bottle: {...?state.running[bottle], key},
  };

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
