import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/domain/entities/exe_graphics.dart';
import 'package:bodega/domain/entities/gptk_step.dart';
import 'package:bodega/domain/entities/mach9_step.dart';
import 'package:bodega/domain/entities/runtime_info.dart';
import 'package:bodega/domain/entities/runtime_kind.dart';
import 'package:fpdart/fpdart.dart';

abstract class BackendRepository {
  Future<Either<AppError, List<BackendInfo>>> list();

  /// MR3: each runtime kind on this host: bodega only on Linux, bodega and
  /// mach9 on the Mac.
  Future<Either<AppError, List<RuntimeInfo>>> runtimes();

  /// MR4: installs [kind] from [file] (a `.dmg` or a `Mach9.app`), else from
  /// the Mach9.app found at the pinned version, else from the pinned
  /// download. False if it was cancelled with [cancelDownload].
  Future<Either<AppError, bool>> installRuntime(
    RuntimeKind kind, {
    String? file,
    required void Function(int received, int? total) onProgress,
    required void Function(Mach9Step step) onStep,
  });

  /// The ready Rosetta bottles, which can run a check.
  Future<Either<AppError, List<String>>> readyBottles();

  /// Downloads and installs [name], checking its pinned SHA-256. False if it
  /// was cancelled with [cancelDownload].
  Future<Either<AppError, bool>> download(
    String name,
    void Function(int received, int? total) onProgress,
  );

  void cancelDownload();

  Future<Either<AppError, Unit>> installFile(String name, String tarball);

  /// I1: the Game Porting Toolkit versions offered.
  List<GptkRelease> get gptkReleases;

  /// I2: the newest dmg of that [version] in Downloads, or null.
  Future<Either<AppError, String?>> findGptkDmg(String version);

  /// I3: installs D3DMetal from a Game Porting Toolkit [dmg], replacing the
  /// one there was. Returns the version installed, or null when its framework
  /// does not say (E3).
  Future<Either<AppError, String?>> installD3DMetalDmg(
    String dmg, {
    required void Function(GptkStep step) onStep,
    required bool Function() cancelled,
  });

  /// G1: what each of [exes] (as an app has it) in [bottle] draws with. The
  /// ones that are not PEs on x86 are left out.
  Future<Either<AppError, Map<String, ExeGraphics>>> graphics(
    String bottle,
    List<String> exes,
  );

  /// Closes what is open in [bottle], and runs the probe with [backend].
  Future<Either<AppError, List<ProbeResult>>> check(
    String bottle,
    String backend,
  );
}
