import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/progress_step.dart';
import 'package:bodega/domain/entities/backend_info.dart';
import 'package:bodega/domain/entities/exe_graphics.dart';
import 'package:fpdart/fpdart.dart';

abstract class BackendRepository {
  Future<Either<AppError, List<BackendInfo>>> list();

  /// The bottles that can run a check.
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
  /// one there was. Returns the version installed.
  Future<Either<AppError, String>> installD3DMetalDmg(
    String dmg, {
    required void Function(ProgressStep step) onStep,
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
