import 'package:bloc/bloc.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/gamepad.dart';
import 'package:bodega/domain/repository/gamepad_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'gamepads_event.dart';
part 'gamepads_state.dart';
part 'gamepads_bloc.freezed.dart';

@injectable
class GamepadsBloc extends Bloc<GamepadsEvent, GamepadsState> {
  final GamepadRepository _repository;

  GamepadsBloc(this._repository) : super(const GamepadsState()) {
    on<GamepadsLoadEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: null));
      final result = await _repository.report();
      result.match(
        (error) => emit(state.copyWith(isLoading: false, error: error)),
        (report) =>
            emit(state.copyWith(isLoading: false, report: report, error: null)),
      );
    });
  }
}
