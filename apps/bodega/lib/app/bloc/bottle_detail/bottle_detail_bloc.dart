import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/bottle_detail.dart';
import 'package:bodega/domain/entities/native_move_step.dart';
import 'package:bodega/domain/entities/retina_mode.dart';
import 'package:bodega/domain/entities/user_name_problem.dart';
import 'package:bodega/domain/repository/bottle_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'bottle_detail_event.dart';
part 'bottle_detail_state.dart';
part 'bottle_detail_bloc.freezed.dart';

@injectable
class BottleDetailBloc extends Bloc<BottleDetailEvent, BottleDetailState> {
  final BottleRepository _repository;

  BottleDetailBloc(this._repository) : super(const BottleDetailState()) {
    on<BottleDetailLoadEvent>((event, emit) => _load(event.name, emit));
    on<BottleDetailSetBackendEvent>(
      (event, emit) =>
          _change(emit, (name) => _repository.setBackend(name, event.backend)),
    );
    on<BottleDetailSetSyncEvent>(
      (event, emit) =>
          _change(emit, (name) => _repository.setSync(name, event.sync)),
    );
    on<BottleDetailSetRetinaEvent>(
      (event, emit) =>
          _change(emit, (name) => _repository.setRetina(name, event.mode)),
    );
    on<BottleDetailSetHighResEvent>(
      (event, emit) =>
          _change(emit, (name) => _repository.setHighRes(name, event.value)),
    );
    on<BottleDetailSetWindowsEvent>(
      (event, emit) => _change(
        emit,
        (name) => _repository.setWindowsVersion(name, event.version),
      ),
    );
    on<BottleDetailSetDlssEvent>(
      (event, emit) => _change(
        emit,
        (name) => _repository.setOptions(name, dlss: event.value),
      ),
    );
    on<BottleDetailSetMetal4Event>(
      (event, emit) => _change(
        emit,
        (name) => _repository.setOptions(name, metal4: event.value),
      ),
    );
    on<BottleDetailSetAvxEvent>(
      (event, emit) => _change(
        emit,
        (name) => _repository.setOptions(name, avx: event.value),
      ),
    );
    on<BottleDetailSetDxvkAsyncEvent>(
      (event, emit) => _change(
        emit,
        (name) => _repository.setOptions(name, dxvkAsync: event.value),
      ),
    );
    on<BottleDetailSetUserEvent>(
      (event, emit) =>
          _change(emit, (name) => _repository.setUser(name, event.user)),
    );
    on<BottleDetailSetGpuEvent>(
      (event, emit) =>
          _change(emit, (name) => _repository.setOptions(name, gpu: event.gpu)),
    );
    on<BottleDetailSetGamemodeEvent>(
      (event, emit) => _change(
        emit,
        (name) => _repository.setOptions(name, gamemode: event.value),
      ),
    );
    on<BottleDetailRemoveExceptionEvent>(
      (event, emit) => _change(
        emit,
        (name) => _repository.setBackend(name, 'auto', exe: event.exe),
      ),
    );
    on<BottleDetailHideAppEvent>(
      (event, emit) =>
          _change(emit, (name) => _repository.hideApp(name, event.key)),
    );
    on<BottleDetailDeleteEvent>((event, emit) async {
      final name = state.detail?.name;
      if (name == null) return;
      emit(state.copyWith(isBusy: true, error: null));
      final result = await _repository.delete(name);
      result.match(
        (error) => emit(state.copyWith(isBusy: false, error: error)),
        (_) => emit(state.copyWith(isBusy: false, deleted: true)),
      );
    });
    on<BottleDetailRenameEvent>((event, emit) async {
      final name = state.detail?.name;
      if (name == null) return;
      emit(state.copyWith(isBusy: true, error: null));
      final result = await _repository.renameBottle(name, event.newName);
      await result.match(
        (error) async => emit(state.copyWith(isBusy: false, error: error)),
        (_) async {
          await _load(event.newName, emit);
          emit(state.copyWith(isBusy: false, renamedTo: event.newName));
        },
      );
    });
    on<BottleDetailSetInLibraryEvent>(
      (event, emit) => _change(
        emit,
        (name) => _repository.setInLibrary(name, event.key, event.value),
      ),
    );
    on<BottleDetailSetHudEvent>(
      (event, emit) => _change(
        emit,
        (name) => _repository.setHud(name, event.key, event.value),
      ),
    );
    on<BottleDetailInstallMonoEvent>((event, emit) async {
      if (state.installingMono) return;
      emit(state.copyWith(installingMono: true));
      await _change(emit, _repository.installMono);
      emit(state.copyWith(installingMono: false));
    });
    on<BottleDetailMoveToNativeEvent>((event, emit) async {
      final name = state.detail?.name;
      if (name == null || state.moveStep != null) return;
      emit(state.copyWith(moveStep: NativeMoveStep.creating, error: null));
      final result = await _repository.moveToNative(
        name,
        (step) => emit(state.copyWith(moveStep: step)),
      );
      emit(state.copyWith(moveStep: null));
      final failed = result.getLeft().toNullable();
      if (failed != null) return emit(state.copyWith(error: failed));
      emit(
        state.copyWith(
          moves: state.moves + 1,
          reinstall: result.getRight().toNullable()!,
        ),
      );
      await _load(name, emit);
    });
    on<BottleDetailOpenLogEvent>((event, emit) async {
      emit(state.copyWith(logPath: event.path, logLines: const []));
      final result = await _repository.logLines(event.path);
      result.match(
        (error) => emit(state.copyWith(error: error)),
        (lines) => emit(state.copyWith(logLines: lines, error: null)),
      );
    });
  }

  Future<void> _load(String name, Emitter<BottleDetailState> emit) async {
    final result = await _repository.detail(name);
    result.match(
      (error) => emit(state.copyWith(isLoading: false, error: error)),
      (detail) =>
          emit(state.copyWith(isLoading: false, detail: detail, error: null)),
    );
  }

  /// U3, for the dialog to check the name while it is typed.
  UserNameProblem? userProblem(String user) => _repository.userProblem(user);

  Future<void> _change(
    Emitter<BottleDetailState> emit,
    Future<Either<AppError, Unit>> Function(String name) change,
  ) async {
    final name = state.detail?.name;
    if (name == null) return;
    emit(state.copyWith(isBusy: true, error: null));
    final result = await change(name);
    await result.match(
      (error) async => emit(state.copyWith(isBusy: false, error: error)),
      (_) async {
        await _load(name, emit);
        emit(state.copyWith(isBusy: false));
      },
    );
  }
}
