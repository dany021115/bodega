import 'package:bodega/app/bloc/graphics/graphics_bloc.dart';
import 'package:bodega/domain/entities/exe_graphics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What [exe] of [bottle] draws with (G1), or null until it is read. Asks for
/// it from a build: the bloc reads each exe only once, so asking again is free.
ExeGraphics? graphicsOf(BuildContext context, String bottle, String exe) {
  if (exe.isEmpty) return null;
  context.read<GraphicsBloc>().add(GraphicsEvent.load(bottle, [exe]));
  return context.select((GraphicsBloc bloc) => bloc.state.of(bottle, exe));
}
