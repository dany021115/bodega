import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/router.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ready = SetupState(isChecking: false, runtime: true);
  const issue = HostIssue(
    title: 'Falta Rosetta',
    detail: 'x',
    command: 'cmd',
  );

  test('without the runtime or with an issue, always to /setup', () {
    for (final state in [
      ready.copyWith(runtime: false),
      ready.copyWith(issues: const [issue]),
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
