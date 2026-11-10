import 'package:bodega/l10n/app_localizations.dart';
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.getDarkTheme(),
        home: const Scaffold(
          body: RequirementCard(
            issue: HostIssue(
              id: 'other',
              title: 'Rosetta is missing',
              detail: 'Wine x86_64 needs it.',
              command: 'softwareupdate --install-rosetta',
            ),
          ),
        ),
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
