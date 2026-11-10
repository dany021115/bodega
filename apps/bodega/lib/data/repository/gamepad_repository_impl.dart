import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/gamepad.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:bodega/domain/repository/gamepad_repository.dart';
import 'package:engine/engine.dart' show checkGamepads;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: GamepadRepository)
class GamepadRepositoryImpl implements GamepadRepository {
  @override
  Future<Either<AppError, GamepadReport?>> report() => repositoryCall(() async {
    final report = await checkGamepads();
    if (report == null) return null;
    return GamepadReport(
      pads: [
        for (final pad in report.pads)
          Gamepad(
            name: pad.name,
            vid: pad.vid,
            pid: pad.pid,
            readable: pad.readable,
          ),
      ],
      sdl: report.sdl,
      issues: [
        for (final issue in report.issues)
          HostIssue(
            id: issue.id,
            args: issue.args,
            title: issue.title,
            detail: issue.detail,
            command: issue.command,
          ),
      ],
    );
  });
}
