import 'package:bodega/data/repository/library_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a launcher is kept as the engine keeps applications', () {
    const bottle = '/h/bottles/b';
    expect(
      launcherExe(bottle, r'C:\Program Files\A\a.exe'),
      'Program Files/A/a.exe',
    );
    expect(launcherExe(bottle, '$bottle/prefix/drive_c/A/a.exe'), 'A/a.exe');
    expect(launcherExe(bottle, '/Users/q/Games/a.exe'), '/Users/q/Games/a.exe');
  });
}
