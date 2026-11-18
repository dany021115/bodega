import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/dependency.dart';
import 'package:bodega/domain/repository/dependency_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

part 'dependencies_event.dart';
part 'dependencies_state.dart';
part 'dependencies_bloc.freezed.dart';

/// The runtimes and game settings of the bottles, and the one job that
/// installs or applies them. A lazy singleton, provided in `main.dart`: an
/// install outlives the page that started it.
@lazySingleton
class DependenciesBloc extends Bloc<DependenciesEvent, DependenciesState> {
  final DependencyRepository _repository;

  DependenciesBloc(this._repository) : super(const DependenciesState()) {
    on<DependenciesLoadEvent>((event, emit) => _load(event.bottle, emit));
    on<DependenciesInstallEvent>(
      (event, emit) => _run(event.bottle, event.items, emit),
    );
    on<DependenciesInstallFileEvent>(
      (event, emit) => _run(event.bottle, [event.item], emit, file: event.file),
    );
    on<DependenciesOfferEvent>(
      (event, emit) => _offer(event.bottle, event.key, emit),
    );
    on<DependenciesOfferCatalogAppEvent>((event, emit) async {
      final key = await _repository.catalogKey(event.catalogId);
      if (key case Right(:final value)) {
        await _offer(event.bottle, value, emit);
      }
    });
    on<DependenciesOfferShownEvent>(
      (event, emit) => emit(state.copyWith(offer: null, offerBottle: null)),
    );
    on<DependenciesCancelEvent>((event, emit) {
      if (state.phase == DependencyPhase.downloading) {
        _repository.cancelDownload();
      }
    });
  }

  Future<void> _load(String bottle, Emitter<DependenciesState> emit) async {
    final result = await _repository.bottle(bottle);
    result.match(
      (error) => emit(state.copyWith(error: error)),
      (data) => emit(state.copyWith(bottles: {...state.bottles, bottle: data})),
    );
  }

  /// A proposal is only worth a dialog when the user can do something
  /// recommended now; a failure to read it stays quiet: it is a suggestion.
  Future<void> _offer(
    String bottle,
    String key,
    Emitter<DependenciesState> emit,
  ) async {
    final needs = await _repository.needs(bottle, key);
    if (needs case Right(:final value) when value.hasRecommended) {
      emit(state.copyWith(offer: value, offerBottle: bottle));
    }
  }

  Future<void> _run(
    String bottle,
    List<NeedItem> items,
    Emitter<DependenciesState> emit, {
    String? file,
  }) async {
    if (state.isBusy || items.isEmpty) return;
    emit(
      state.copyWith(
        bottle: bottle,
        error: null,
        failed: null,
        failedBottle: null,
      ),
    );
    // Runtimes first: a game's settings never wait on them, but a failed
    // download should not leave a setting half the queue away.
    final queue = [
      ...items.whereType<RuntimeItem>(),
      ...items.whereType<SettingsItem>(),
    ];
    for (final item in queue) {
      final AppError? error = switch (item) {
        RuntimeItem() => await _runtime(bottle, item, emit, file),
        SettingsItem(:final fix) => await () async {
          emit(state.copyWith(phase: DependencyPhase.applying, item: item));
          return (await _repository.applySettings(
            bottle,
            fix,
          )).getLeft().toNullable();
        }(),
      };
      if (error != null) {
        emit(
          state.copyWith(
            phase: DependencyPhase.idle,
            item: null,
            error: error,
            failed: item,
            failedBottle: bottle,
          ),
        );
        return _load(bottle, emit);
      }
      if (state.phase == DependencyPhase.idle) return _load(bottle, emit);
    }
    emit(
      state.copyWith(
        phase: DependencyPhase.idle,
        item: null,
        received: 0,
        total: null,
      ),
    );
    await _load(bottle, emit);
  }

  /// Downloads [item]'s installer, unless [file] stands for it, and installs
  /// it. A cancelled download ends the job with no error.
  Future<AppError?> _runtime(
    String bottle,
    RuntimeItem item,
    Emitter<DependenciesState> emit,
    String? file,
  ) async {
    var path = file;
    if (path == null) {
      emit(
        state.copyWith(
          phase: DependencyPhase.downloading,
          item: item,
          received: 0,
          total: null,
        ),
      );
      // Progress arrives per chunk; one state per percent is enough.
      var shown = -1;
      final download = await _repository.download(item.id, item.arch, (
        received,
        total,
      ) {
        final mark = total == null ? received >> 20 : received * 100 ~/ total;
        if (mark == shown) return;
        shown = mark;
        emit(state.copyWith(received: received, total: total));
      });
      switch (download) {
        case Left(:final value):
          return value;
        case Right(value: null):
          emit(state.copyWith(phase: DependencyPhase.idle, item: null));
          return null;
        case Right(:final value?):
          path = value;
      }
    }
    emit(state.copyWith(phase: DependencyPhase.installing, item: item));
    return (await _repository.install(
      bottle,
      item.id,
      item.arch,
      path,
    )).getLeft().toNullable();
  }
}
