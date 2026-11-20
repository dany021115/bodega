import 'dart:io';

import 'package:bodega/data/service/engine_home.dart';
import 'package:bodega/data/service/repository_call.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/exe_graphics.dart';
import 'package:bodega/domain/entities/game.dart';
import 'package:bodega/domain/repository/game_repository.dart';
import 'package:engine/engine.dart' as engine;
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The issue form that takes reports (G8).
const reportForm = 'https://github.com/dany021115/bodega/issues/new';

@LazySingleton(as: GameRepository)
class GameRepositoryImpl implements GameRepository {
  final EngineHome _home;

  GameRepositoryImpl(this._home);

  @override
  Future<Either<AppError, List<GameConfig>>> games() => repositoryCall(
    () => [for (final fix in engine.gameFixes()) _config(fix)],
  );

  @override
  Future<Either<AppError, GameConfig>> game(String id) =>
      repositoryCall(() => _config(engine.gameFix(id)));

  @override
  Future<Either<AppError, List<AppGame>>> appGames(String bottle) =>
      repositoryCall(() async {
        final home = _home.path;
        return [
          for (final app in engine.bottleApps(home, bottle))
            _appGame(await engine.gamePlan(home, bottle, app.key)),
        ];
      });

  @override
  Future<Either<AppError, Unit>> setOn(String bottle, String key, bool on) =>
      repositoryCall(() async {
        await engine.setGameConfig(_home.path, bottle, key, on: on);
        return unit;
      });

  @override
  Future<Either<AppError, Unit>> setVerdict(
    String bottle,
    String key,
    GameVerdict? verdict,
  ) => repositoryCall(() {
    engine.setGameVerdict(_home.path, bottle, key, verdict?.name);
    return unit;
  });

  @override
  Future<Either<AppError, Uri>> reportUrl(
    AppGame game,
    GameVerdict verdict,
    String note,
  ) => repositoryCall(() async {
    final config = game.config;
    final title = config?.title ?? game.title;
    return Uri.parse(reportForm).replace(
      queryParameters: {
        'template': 'game-report.yml',
        'title': '$title: ${verdict.name}',
        'game': title,
        if (config?.steam case final steam?) 'steam_appid': '$steam',
        'rating': verdict.name,
        'backend': '${game.backend} (${game.origin.name})',
        'bodega': (await PackageInfo.fromPlatform()).version,
        'os': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        'cpu': await _cpu(),
        if (note.trim().isNotEmpty) 'notes': note.trim(),
      },
    );
  });

  /// The chip or the processor, as the report form asks; empty if unknown.
  static Future<String> _cpu() async {
    try {
      if (Platform.isMacOS) {
        final run = await Process.run('sysctl', [
          '-n',
          'machdep.cpu.brand_string',
        ]);
        return '${run.stdout}'.trim();
      }
      final info = await File('/proc/cpuinfo').readAsLines();
      return info
              .where((line) => line.startsWith('model name'))
              .map((line) => line.split(':').last.trim())
              .firstOrNull ??
          '';
    } on Object {
      return '';
    }
  }

  static GameConfig _config(engine.GameFix fix) => GameConfig(
    id: fix.id,
    title: fix.title,
    steam: fix.steam,
    status: GameStatus.values.byName(fix.status),
    rating: switch (fix.rating) {
      null => null,
      final rating => GameRating.values.byName(rating),
    },
    backend: fix.backend,
    antiCheat: fix.antiCheat?.names ?? const [],
    antiCheatVerdict: switch (fix.antiCheat?.verdict) {
      null => null,
      final verdict => AntiCheatVerdict.values.byName(verdict),
    },
    reports: fix.reports?.count ?? 0,
    lastReport: fix.reports?.last,
    nativeMac: fix.nativeMac,
    // What a launch applies, and the settings-file steps the user applies:
    // nothing an opt-in fix only offers (G7).
    steps: [
      for (final step in [
        ...fix.active,
        ...fix.steps.where((step) => step.type == 'ini' && step.applies),
      ])
        ?_step(step),
    ],
    requires: fix.requires,
    notes: fix.notes,
    knownIssues: [
      for (final issue in fix.knownIssues)
        GameIssue(symptom: issue.symptom, cause: issue.cause, fix: issue.fix),
    ],
    sourceUrl: fix.source == 'bodega'
        ? null
        : 'https://github.com/gauthierpiarrette/highball-db/blob/'
              '${engine.fixesSourceCommit}/${fix.source}',
  );

  static GameStep? _step(engine.FixStep step) => switch (step.type) {
    'env' => GameStep(
      kind: GameStepKind.variable,
      name: step.name!,
      value: engine.fixValue(step.value!) ?? step.value!,
    ),
    'dlloverride' => GameStep(kind: GameStepKind.override, value: step.value!),
    'registry' => GameStep(
      kind: GameStepKind.registry,
      name: step.name!,
      value: step.data!,
      where: step.key!,
    ),
    'ini' => GameStep(
      kind: GameStepKind.settingsFile,
      name: '[${step.section}] ${step.name}',
      value: step.data!,
      where: step.file!,
    ),
    _ => null,
  };

  static AppGame _appGame(engine.GamePlan plan) {
    final match = plan.match;
    return AppGame(
      key: plan.app.key,
      title: plan.app.title,
      config: match == null ? null : _config(match.fix),
      by: match == null ? null : GameMatchKind.values.byName(match.by.name),
      on: plan.on,
      backend: plan.backend.name,
      origin: BackendOrigin.values.byName(plan.backend.origin),
      graphics: switch (plan.graphics) {
        null => null,
        final graphics => ExeGraphics(
          bits: graphics.bits,
          directx: graphics.directx,
        ),
      },
      steps: [
        for (final MapEntry(:key, :value) in plan.env.entries)
          GameStep(kind: GameStepKind.variable, name: key, value: value),
        for (final value in plan.overrides)
          GameStep(kind: GameStepKind.override, value: value),
        for (final step in [...plan.registry, ...plan.ini]) ?_step(step),
      ],
      requires: plan.requires,
      verdict: switch (plan.verdict) {
        null => null,
        final verdict => GameVerdict.values.byName(verdict),
      },
    );
  }
}
