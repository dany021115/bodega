import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/repository/add_app_repository.dart';
import 'package:bodega/domain/repository/bottle_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'add_app_event.dart';
part 'add_app_state.dart';
part 'add_app_bloc.freezed.dart';

@injectable
class AddAppBloc extends Bloc<AddAppEvent, AddAppState> {
  final AddAppRepository _repository;
  final BottleRepository _bottles;

  AddAppBloc(this._repository, this._bottles) : super(const AddAppState()) {
    on<AddAppLoadEvent>(
      (event, emit) => emit(state.copyWith(bottle: event.bottle)),
    );
    on<AddAppExeChosenEvent>((event, emit) {
      final name = event.path.split('/').last;
      emit(
        state.copyWith(
          exe: event.path,
          title: state.title.isEmpty
              ? name.replaceFirst(RegExp(r'\.exe$', caseSensitive: false), '')
              : state.title,
          error: null,
        ),
      );
    });
    on<AddAppTitleChangedEvent>(
      (event, emit) => emit(state.copyWith(title: event.title)),
    );
    on<AddAppInstallerToggledEvent>(
      (event, emit) => emit(state.copyWith(isInstaller: event.value)),
    );
    on<AddAppAddToLibraryToggledEvent>(
      (event, emit) => emit(state.copyWith(addToLibrary: event.value)),
    );
    on<AddAppSubmitEvent>(_submit);
    // An installer can leave a service behind, and then the bottle never
    // empties. Nothing is stopped: only the user knows it has finished.
    on<AddAppInstallerDoneEvent>((event, emit) {
      if (state.step == AddAppStep.installing) {
        emit(state.copyWith(step: AddAppStep.pickInstalled));
      }
    });
    on<AddAppInstalledChosenEvent>(
      (event, emit) =>
          _register(state.bottle, event.path, emit, onFailure: state.step),
    );
  }

  Future<void> _submit(
    AddAppSubmitEvent event,
    Emitter<AddAppState> emit,
  ) async {
    final exe = state.exe;
    if (!state.canSubmit || exe == null) return;

    // An unusable path fails here, before Wine or the library see it.
    if (_repository.pathProblem(exe) case final problem?) {
      return emit(state.copyWith(error: problem));
    }

    final bottle = state.bottle;
    if (!state.isInstaller) {
      return _register(bottle, exe, emit, onFailure: AddAppStep.form);
    }

    emit(
      state.copyWith(
        step: AddAppStep.installing,
        driveC: _repository.driveC(bottle),
        error: null,
      ),
    );
    final run = await _repository.runInstaller(bottle, exe);
    // The user may have gone on already: see AddAppInstallerDoneEvent.
    if (state.step != AddAppStep.installing) return;
    run.match(
      (error) => emit(state.copyWith(step: AddAppStep.form, error: error)),
      (_) => emit(state.copyWith(step: AddAppStep.pickInstalled)),
    );
  }

  Future<void> _register(
    String bottle,
    String exe,
    Emitter<AddAppState> emit, {
    required AddAppStep onFailure,
  }) async {
    switch (await _repository.addApp(bottle, state.title.trim(), exe)) {
      case Left(value: final error):
        return emit(state.copyWith(step: onFailure, error: error));
      case Right(value: final key):
        if (!state.addToLibrary) {
          switch (await _bottles.setInLibrary(bottle, key, false)) {
            case Left(value: final error):
              return emit(state.copyWith(step: onFailure, error: error));
            case Right():
              break;
          }
        }
    }
    emit(state.copyWith(step: AddAppStep.done, error: null));
  }
}
