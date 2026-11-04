import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/bottle.dart';
import 'package:bodega/domain/repository/bottle_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'bottles_event.dart';
part 'bottles_state.dart';
part 'bottles_bloc.freezed.dart';

/// The bottles of the sidebar.
@lazySingleton
class BottlesBloc extends Bloc<BottlesEvent, BottlesState> {
  final BottleRepository _repository;

  BottlesBloc(this._repository) : super(const BottlesState()) {
    on<BottlesLoadEvent>((event, emit) async {
      final result = await _repository.list();
      result.match(
        (error) => emit(state.copyWith(isLoading: false, error: error)),
        (bottles) => emit(
          state.copyWith(isLoading: false, bottles: bottles, error: null),
        ),
      );
    });
  }
}
