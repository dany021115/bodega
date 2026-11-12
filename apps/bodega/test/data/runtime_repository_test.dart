import 'dart:io';

import 'package:bodega/data/repository/runtime_repository_impl.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/host_capabilities.dart';
import 'package:bodega/domain/entities/path_problem.dart';
import 'package:engine/engine.dart' as engine;
import 'package:flutter_test/flutter_test.dart';

import '_home.dart';

/// A Mac with no host issue, whose capabilities say [switchGames] (SA8).
class _Host extends engine.MacPlatform {
  const _Host({required this.switchGames});

  final bool switchGames;

  @override
  Future<List<engine.HostIssue>> checkHost() async => const [];

  @override
  engine.HostCapabilities get capabilities {
    final mac = super.capabilities;
    return (
      highRes: mac.highRes,
      avx: mac.avx,
      dlss: mac.dlss,
      d3dmetal: mac.d3dmetal,
      sdl: mac.sdl,
      gpu: mac.gpu,
      gameMode: mac.gameMode,
      syncModes: mac.syncModes,
      switchGames: switchGames,
    );
  }
}

void main() {
  test('an engine failure arrives as Left with its code, and its English text '
      'as detail', () async {
    final home = Directory.systemTemp.createTempSync('bodega-repo');
    addTearDown(() => home.deleteSync(recursive: true));
    final repository = RuntimeRepositoryImpl(TestHome(home.path));

    final result = await repository.install(
      engine: '${home.path}/missing-engine.tar.xz',
      hostlibs: '${home.path}/missing-hostlibs.tar.xz',
    );

    // Its .sha256 is the first thing the engine looks for.
    final error = result.getLeft().toNullable();
    expect(
      error,
      isA<BadPathError>().having(
        (e) => e.problem,
        'problem',
        PathProblem.missing('${home.path}/missing-engine.tar.xz.sha256'),
      ),
    );
    expect(error!.detail, contains('missing-engine.tar.xz.sha256 is missing'));
  });

  test('Switch games follow what the engine says the host offers, and are '
      'offered by default (SA8)', () async {
    final home = Directory.systemTemp.createTempSync('bodega-repo');
    final host = engine.hostPlatform;
    addTearDown(() {
      engine.hostPlatform = host;
      home.deleteSync(recursive: true);
    });
    final repository = RuntimeRepositoryImpl(TestHome(home.path));

    for (final switchGames in [false, true]) {
      engine.hostPlatform = _Host(switchGames: switchGames);
      final status = (await repository.status()).getOrElse(
        (error) => fail('$error'),
      );
      expect(status.issues, isEmpty);
      expect(status.capabilities.switchGames, switchGames);
    }
    expect(const HostCapabilities().switchGames, isTrue);
  });
}
