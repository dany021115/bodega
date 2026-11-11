import 'package:bodega/app/presentation/setup/widgets/requirement_card.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, HostIssue issue) =>
      tester.pumpWidget(
        wrapApp(
          Scaffold(body: RequirementCard(issue: issue)),
          theme: AppTheme.getDarkTheme(),
        ),
      );

  Finder command(String text) => find.byWidgetPredicate(
    (widget) => widget is SelectableText && widget.data == text,
  );

  testWidgets('words the issue by its kind, and shows its command', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const HostIssue(
        kind: HostIssueKind.noRosetta,
        command: 'softwareupdate --install-rosetta',
      ),
    );

    expect(find.text('Rosetta is missing'), findsOneWidget);
    expect(find.text('Windows games run on Rosetta 2.'), findsOneWidget);
    expect(command('softwareupdate --install-rosetta'), findsOneWidget);
    expect(find.text('Copy command'), findsOneWidget);
  });

  testWidgets('a pad it cannot open is named, with its install command', (
    tester,
  ) async {
    await pumpCard(
      tester,
      const HostIssue(
        kind: HostIssueKind.padNoAccess,
        subject: 'Microsoft X-Box 360 pad',
        command: 'sudo apt install steam-devices',
      ),
    );

    expect(
      find.text('No access to the controller Microsoft X-Box 360 pad'),
      findsOneWidget,
    );
    expect(command('sudo apt install steam-devices'), findsOneWidget);
    expect(find.text('Copy command'), findsOneWidget);
  });

  testWidgets('without a command, there is nothing to copy', (tester) async {
    await pumpCard(tester, const HostIssue(kind: HostIssueKind.unsupportedCpu));

    expect(find.text('Unsupported processor'), findsOneWidget);
    expect(find.text('Bodega needs an x86_64 processor.'), findsOneWidget);
    expect(find.byType(SelectableText), findsNothing);
    expect(find.text('Copy command'), findsNothing);
  });
}
