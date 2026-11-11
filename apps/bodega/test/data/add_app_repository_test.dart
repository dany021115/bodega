import 'dart:convert';
import 'dart:io';

import 'package:bodega/data/repository/add_app_repository_impl.dart';
import 'package:bodega/domain/entities/path_problem.dart';
import 'package:flutter_test/flutter_test.dart';

import '_home.dart';

void main() {
  group('the repository', () {
    late Directory home;
    late AddAppRepositoryImpl repository;
    late String drive;

    setUp(() {
      home = Directory.systemTemp.createTempSync('bodega-addapp');
      addTearDown(() => home.deleteSync(recursive: true));
      repository = AddAppRepositoryImpl(TestHome(home.path));
      drive = repository.driveC('blur');
      Directory(drive).createSync(recursive: true);
    });

    Map<String, dynamic> app() =>
        ((jsonDecode(
                      File('${home.path}/bottles/blur/apps.json')
                          .readAsStringSync(),
                    ) as Map<String, dynamic>)['apps']
                    as List)
                .single
            as Map<String, dynamic>;

    test('a program inside the bottle is kept relative to drive_c', () async {
      File('$drive/Blur/Blur.exe').createSync(recursive: true);

      final result = await repository.addApp(
        'blur',
        'Blur',
        '$drive/Blur/Blur.exe',
      );

      expect(result.isRight(), isTrue);
      expect(app()['exe'], 'Blur/Blur.exe');
      // The key the library uses, the one setInLibrary takes.
      expect(result.getOrElse((_) => ''), 'blur/blur.exe');
    });

    test('a program outside it is kept absolute', () async {
      final exe = File('${home.path}/Blur.exe')..createSync();

      await repository.addApp('blur', 'Blur', exe.path);

      expect(app()['exe'], exe.path);
    });

    test('a bottle that already has an application takes another', () async {
      File('$drive/A/a.exe').createSync(recursive: true);
      File('$drive/B/b.exe').createSync(recursive: true);

      await repository.addApp('blur', 'A', '$drive/A/a.exe');
      final second = await repository.addApp('blur', 'B', '$drive/B/b.exe');

      expect(second.isRight(), isTrue);
    });

    test('pathProblem catches what Wine would not open (E11)', () {
      final good = File('${home.path}/a.exe')..createSync();
      final bad = File('${home.path}/odd:/a.exe')..createSync(recursive: true);

      expect(repository.pathProblem(good.path), isNull);
      expect(
        repository.pathProblem(bad.path),
        PathProblem.windowsName(part: 'odd:', path: bad.path),
      );
      expect(
        repository.pathProblem('${home.path}/no.exe'),
        PathProblem.missing('${home.path}/no.exe'),
      );
    });
  });
}
