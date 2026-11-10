import 'package:bodega/app/presentation/setup/widgets/requirement_card.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';

void main() {
  testWidgets('shows the title, the detail and the command of the issue', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapApp(
        const Scaffold(
          body: RequirementCard(
            issue: HostIssue(
              title: 'Rosetta is missing',
              detail: 'Wine x86_64 needs it.',
              command: 'softwareupdate --install-rosetta',
            ),
          ),
        ),
        theme: AppTheme.getDarkTheme(),
      ),
    );

    expect(find.text('Rosetta is missing'), findsOneWidget);
    expect(find.text('Wine x86_64 needs it.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data == 'softwareupdate --install-rosetta',
      ),
      findsOneWidget,
    );
    expect(find.text('Copy command'), findsOneWidget);
  });
}
