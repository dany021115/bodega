import 'package:bodega/domain/entities/progress_step.dart';
import 'package:engine/engine.dart' as engine;

/// The engine's [step] as the app's.
ProgressStep progressStep(engine.Progress step) =>
    ProgressStep(id: step.id, args: step.args, text: step.text);
