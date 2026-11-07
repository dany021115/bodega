import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/repository/bottle_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'new_bottle_event.dart';
part 'new_bottle_state.dart';
part 'new_bottle_bloc.freezed.dart';

/// The same rule the engine applies to a bottle's directory name.
final _validName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$');

@injectable
class NewBottleBloc extends Bloc<NewBottleEvent, NewBottleState> {
  final BottleRepository _repository;

  NewBottleBloc(this._repository) : super(const NewBottleState()) {
    on<NewBottleLoadEvent>((event, emit) async {
      final result = await _repository.list();
      result.match(
        (error) => emit(state.copyWith(error: error)),
        (bottles) => emit(
          state.copyWith(taken: [for (final bottle in bottles) bottle.name]),
        ),
      );
    });
    on<NewBottleNameChangedEvent>(
      (event, emit) => emit(state.copyWith(name: event.name)),
    );
    on<NewBottleWindowsChangedEvent>(
      (event, emit) => emit(state.copyWith(windows: event.windows)),
    );
    on<NewBottleBackendChangedEvent>(
      (event, emit) => emit(state.copyWith(backend: event.backend)),
    );
    on<NewBottleSubmitEvent>((event, emit) async {
      if (!state.canSubmit) return;
      final name = state.name;
      emit(state.copyWith(isCreating: true, error: null));
      final result = await _repository.create(
        name,
        windows: state.windows,
        backend: state.backend,
      );
      result.match(
        (error) => emit(state.copyWith(isCreating: false, error: error)),
        (_) => emit(state.copyWith(isCreating: false, createdName: name)),
      );
    });

    add(const NewBottleEvent.load());
  }
}
