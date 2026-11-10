import 'dart:io';

import 'package:bodega/data/repository/library_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '_home.dart';

void main() {
  test('the applications of every bottle, and not the empty ones', () async {
    final home = Directory.systemTemp.createTempSync('bodega-library');
    addTearDown(() => home.deleteSync(recursive: true));
    for (final name in ['b', 'a']) {
      final drive = '${home.path}/bottles/$name/prefix/drive_c';
      File('$drive/P/$name.exe').createSync(recursive: true);
      File('${home.path}/bottles/$name/apps.json').writeAsStringSync(
        '{"apps": [{"id": "custom", "title": "$name", '
        '"exe": "P/$name.exe", "args": []}]}',
      );
    }
    Directory('${home.path}/bottles/vacia').createSync();

    final apps = (await LibraryRepositoryImpl(
      TestHome(home.path),
    ).apps()).getOrElse((error) => fail('$error'));

    expect(apps.map((app) => app.bottle), ['a', 'b']);
    expect(apps.first.key, 'p/a.exe');
  });
}
