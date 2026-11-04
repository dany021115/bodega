import 'dart:io';

import 'package:bodega/data/repository/runtime_repository_impl.dart';
import 'package:bodega/domain/entities/app_error.dart';
import 'package:flutter_test/flutter_test.dart';

import '_home.dart';

void main() {
  test('an engine error arrives as Left(EngineError) with its text', () async {
    final home = Directory.systemTemp.createTempSync('bodega-repo');
    addTearDown(() => home.deleteSync(recursive: true));
    final repository = RuntimeRepositoryImpl(TestHome(home.path));

    final result = await repository.install(
      engine: '${home.path}/no-existe-engine.tar.xz',
      hostlibs: '${home.path}/no-existe-hostlibs.tar.xz',
    );

    final error = result.getLeft().toNullable();
    expect(error, isA<EngineError>());
    expect(error!.message, isNotEmpty);
  });
}
