import 'package:bodega/domain/entities/native_option.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'library_app.freezed.dart';

@freezed
abstract class LibraryApp with _$LibraryApp {
  const factory LibraryApp({
    required String bottle,

    /// Its exe is a folder of the Mac outside Bodega's bottles, so the Rosetta
    /// engine can open it too (ER6).
    @Default(false) bool outsideBottle,

    /// What identifies it in its bottle.
    required String key,
    required String id,
    required String title,

    /// As Windows sees it (`C:\\…`), or an absolute path outside the bottle.
    @Default('') String exe,
    @Default([]) List<String> args,

    /// A picture of it on disk, if it has one.
    String? iconPath,

    /// Whether the library shows it. Off apps still belong to their bottle.
    @Default(true) bool inLibrary,

    /// Whether every launch of it shows the performance HUD.
    @Default(false) bool hud,

    /// Whether its bottle runs on the Native engine (PA2).
    @Default(false) bool nativeEngine,

    /// Whether its exe is an ARM64 Windows program, which only the Native
    /// engine runs (AA1).
    @Default(false) bool arm64,

    /// The Native engine options it has on (PA2).
    @Default({}) Set<NativeOption> nativeOptions,
  }) = _LibraryApp;
}
