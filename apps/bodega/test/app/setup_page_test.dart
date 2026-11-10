import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/setup/setup_bloc.dart';
import 'package:bodega/app/presentation/setup/setup_page.dart';
import 'package:bodega/device/theme/theme.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/pump.dart';

class _MockSetup extends MockBloc<SetupEvent, SetupState>
    implements SetupBloc {}

void main() {
  final en = lookupAppL10n(const Locale('en'));
  final es = lookupAppL10n(const Locale('es'));
  late _MockSetup setup;

  setUp(() {
    // A missing requirement, and no engine: every card of the page.
    setup = _MockSetup();
    whenListen(
      setup,
      const Stream<SetupState>.empty(),
      initialState: const SetupState(
        isChecking: false,
        issues: [
          HostIssue(
            title: 'Rosetta is missing',
            detail: 'Wine x86_64 needs it.',
            command: 'softwareupdate --install-rosetta',
          ),
        ],
      ),
    );
  });

  Future<void> pumpSetup(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1150, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      BlocProvider<SetupBloc>.value(
        value: setup,
        child: wrapApp(
          const SetupPage(),
          locale: locale,
          theme: AppTheme.getDarkTheme(),
        ),
      ),
    );
  }

  testWidgets('says what is missing and asks for the engine', (tester) async {
    await pumpSetup(tester);
    expect(find.text('Set up Bodega'), findsOneWidget);
    expect(find.text('Copy command'), findsOneWidget);
    expect(find.text('The engine is missing'), findsOneWidget);
    expect(find.text('Engine'), findsOneWidget);
    expect(find.text('Libraries'), findsOneWidget);
    expect(find.text('No file chosen'), findsNWidgets(2));
    expect(find.text('Choose file…'), findsNWidgets(2));
    expect(find.text('Install'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
  });

  testWidgets('in Spanish, its words are Spanish (L1)', (tester) async {
    await pumpSetup(tester, locale: const Locale('es'));
    for (final text in <String Function(AppL10n)>[
      (l10n) => l10n.setupTitle,
      (l10n) => l10n.setupCopyCommand,
      (l10n) => l10n.setupEngineMissing,
      (l10n) => l10n.setupEngineFiles,
      (l10n) => l10n.setupEngine,
      (l10n) => l10n.setupLibraries,
      (l10n) => l10n.setupNoFile,
      (l10n) => l10n.commonChooseFile,
      (l10n) => l10n.commonInstall,
      (l10n) => l10n.commonCheckAgain,
    ]) {
      expect(find.text(text(es)), findsWidgets);
      expect(find.text(text(en)), findsNothing);
    }
  });

  testWidgets('copies the command and says so', (tester) async {
    final copied = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text']);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpSetup(tester);
    await tester.tap(find.text('Copy command'));
    // The toast comes after the copy, and slides in.
    await tester.pumpAndSettle();

    expect(copied, ['softwareupdate --install-rosetta']);
    expect(find.text('Command copied'), findsOneWidget);
    // The toast closes by itself.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
