import 'dart:io';

import 'package:bodega/data/repository/runtime_repository_impl.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:bodega/domain/entities/path_problem.dart';
import 'package:flutter_test/flutter_test.dart';

import '_home.dart';

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
}
