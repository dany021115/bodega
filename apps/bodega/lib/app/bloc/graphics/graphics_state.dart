part of 'graphics_bloc.dart';

@freezed
abstract class GraphicsState with _$GraphicsState {
  const GraphicsState._();

  /// Null for an exe already read that is not a PE, so it is not read again.
  const factory GraphicsState({@Default({}) Map<String, ExeGraphics?> byKey}) =
      _GraphicsState;

  static String keyOf(String bottle, String exe) => '$bottle\n$exe';

  ExeGraphics? of(String bottle, String exe) => byKey[keyOf(bottle, exe)];
}
