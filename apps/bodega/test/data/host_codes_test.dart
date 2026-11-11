import 'dart:io';

import 'package:bodega/data/repository/backend_repository_impl.dart';
import 'package:bodega/data/service/code_mapper.dart';
import 'package:bodega/data/service/downloader.dart';
import 'package:bodega/domain/entities/backend_role.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:engine/engine.dart' as engine;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '_home.dart';

class _MockDownloader extends Mock implements Downloader {}

// Host issues and backend roles cross data/ as codes, never as text (E3,
// E11): each engine value maps to the domain value of the same name.
void main() {
  test('a host issue keeps its kind, the pad it names and its command', () {
    for (final kind in engine.HostIssueKind.values) {
      expect(
        hostIssueOf((kind: kind, subject: 'Xbox pad', command: 'cmd')),
        HostIssue(
          kind: HostIssueKind.values.byName(kind.name),
          subject: 'Xbox pad',
          command: 'cmd',
        ),
      );
    }
    expect(
      hostIssueOf((
        kind: engine.HostIssueKind.unsupportedCpu,
        subject: null,
        command: null,
      )),
      const HostIssue(kind: HostIssueKind.unsupportedCpu),
    );
  });

  test('each backend role maps to the one of the same name', () {
    for (final role in engine.BackendRole.values) {
      expect(backendRoleOf(role), BackendRole.values.byName(role.name));
    }
  });

  test('the backend list says what each backend of the host is for', () async {
    final home = Directory.systemTemp.createTempSync('bodega-roles');
    addTearDown(() => home.deleteSync(recursive: true));

    final backends = (await BackendRepositoryImpl(
      TestHome(home.path),
      _MockDownloader(),
    ).list()).getOrElse((error) => fail('$error'));

    expect(
      {for (final backend in backends) backend.name: backend.role},
      Platform.isMacOS
          ? {
              'wine': BackendRole.everythingElse,
              'dxmt': BackendRole.dx10to11,
              'dxvk': BackendRole.dx10to11,
              'd3dmetal': BackendRole.dx11to12x64,
            }
          : {'wine': BackendRole.everythingSlower, 'dxvk': BackendRole.dx8to12},
    );
  });
}
