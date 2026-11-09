part of 'graphics_bloc.dart';

@freezed
sealed class GraphicsEvent with _$GraphicsEvent {
  /// Reads the [exes] (as the apps have them) of [bottle] not read yet.
  const factory GraphicsEvent.load(String bottle, List<String> exes) =
      GraphicsLoadEvent;
}
