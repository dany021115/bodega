import 'package:bodega/app/presentation/setup/widgets/requirement_card.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the title, the detail and the command of the issue', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getDarkTheme(),
        home: const Scaffold(
          body: RequirementCard(
            issue: HostIssue(
              title: 'Falta Rosetta',
              detail: 'Hace falta para correr Wine x86_64.',
              command: 'softwareupdate --install-rosetta',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Falta Rosetta'), findsOneWidget);
    expect(find.text('Hace falta para correr Wine x86_64.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SelectableText &&
            widget.data == 'softwareupdate --install-rosetta',
      ),
      findsOneWidget,
    );
    expect(find.text('Copiar comando'), findsOneWidget);
  });
}
