import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ready = SetupState(isChecking: false, rosetta: true, runtime: true);

  test('without the runtime or Rosetta, always to /setup', () {
    for (final state in [
      ready.copyWith(runtime: false),
      ready.copyWith(rosetta: false),
    ]) {
      expect(setupRedirect(state, '/library'), '/setup');
      expect(setupRedirect(state, '/'), '/setup');
      expect(setupRedirect(state, '/setup'), isNull);
    }
  });

  test('with them, /setup leads to /library', () {
    expect(setupRedirect(ready, '/setup'), '/library');
    expect(setupRedirect(ready, '/'), '/library');
    expect(setupRedirect(ready, '/catalog'), isNull);
  });

  test('during the check it stays on the splash or in /setup', () {
    const checking = SetupState();
    expect(setupRedirect(checking, '/'), isNull);
    expect(setupRedirect(checking, '/setup'), isNull);
    expect(setupRedirect(checking, '/library'), '/');
  });
}
