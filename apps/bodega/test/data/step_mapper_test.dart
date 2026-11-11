// The engine's install and D3DMetal steps as their domain twins
// (lib/data/service/code_mapper.dart): codes that keep what they name, never
// text (E11).

import 'package:bodega/data/service/code_mapper.dart';
import 'package:bodega/domain/entities/gptk_step.dart';
import 'package:bodega/domain/entities/install_step.dart';
import 'package:engine/engine.dart' as engine;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('installStepOf', () {
    InstallStep of(engine.InstallStepKind kind, [String? subject]) =>
        installStepOf((kind: kind, subject: subject));

    test('each kind becomes its step, with what it names', () {
      expect(
        of(engine.InstallStepKind.unpinnedDownload, 'example.com'),
        const InstallStep.unpinnedDownload('example.com'),
      );
      expect(
        of(engine.InstallStepKind.downloading),
        const InstallStep.downloading(),
      );
      expect(
        of(engine.InstallStepKind.syncMismatch, 'none'),
        const InstallStep.syncMismatch('none'),
      );
      expect(
        of(engine.InstallStepKind.creatingBottle, 'steam'),
        const InstallStep.creatingBottle('steam'),
      );
      expect(
        of(engine.InstallStepKind.registry, 'GlobalFlag'),
        const InstallStep.registry('GlobalFlag'),
      );
      expect(
        of(engine.InstallStepKind.runningInstaller),
        const InstallStep.runningInstaller(),
      );
      expect(of(engine.InstallStepKind.waiting), const InstallStep.waiting());
    });

    test('no two kinds of the engine become the same step', () {
      expect({
        for (final kind in engine.InstallStepKind.values)
          of(kind, 'x').runtimeType,
      }, hasLength(engine.InstallStepKind.values.length));
    });
  });

  test('gptkStepOf keeps each step', () {
    for (final step in engine.GptkStep.values) {
      expect(gptkStepOf(step).name, step.name);
    }
    expect({
      for (final step in engine.GptkStep.values) gptkStepOf(step),
    }, GptkStep.values.toSet());
  });
}
