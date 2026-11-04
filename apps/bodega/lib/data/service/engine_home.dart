import 'dart:io';

import 'package:engine/engine.dart';
import 'package:injectable/injectable.dart';

/// The engine's data root, resolved once.
@lazySingleton
class EngineHome {
  late final String path = bodegaHome(Platform.environment);
}
