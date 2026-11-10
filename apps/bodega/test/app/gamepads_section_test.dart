import 'package:bloc_test/bloc_test.dart';
import 'package:bodega/app/bloc/gamepads/gamepads_bloc.dart';
import 'package:bodega/app/bloc/sections/sections_bloc.dart';
import 'package:bodega/app/presentation/bottles/widgets/gamepads_section.dart';
import 'package:bodega/domain/entities/gamepad.dart';
import 'package:bodega/domain/entities/host_issue.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/pump.dart';

class _MockGamepads extends MockBloc<GamepadsEvent, GamepadsState>
    implements GamepadsBloc {}

class _MockSections extends MockBloc<SectionsEvent, SectionsState>
    implements SectionsBloc {}

const _ready = Gamepad(
  name: '8BitDo Ultimate 2 Wireless Controller',
  vid: '2dc8',
  pid: '310b',
  readable: true,
);
const _locked = Gamepad(
  name: 'Microsoft X-Box 360 pad',
  vid: '045e',
  pid: '028e',
  readable: false,
);

void main() {
  final en = lookupAppL10n(const Locale('en'));
  late _MockGamepads gamepads;
  late _MockSections sections;

  setUp(() {
    gamepads = _MockGamepads();
    sections = _MockSections();
    when(() => sections.state).thenReturn(const SectionsState());
  });

  Future<void> pump(WidgetTester tester, GamepadsState state) async {
    when(() => gamepads.state).thenReturn(state);
    // The width of the bottle's panel, the narrowest place it goes.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapApp(
        MultiBlocProvider(
          providers: [
            BlocProvider<GamepadsBloc>.value(value: gamepads),
            BlocProvider<SectionsBloc>.value(value: sections),
          ],
          child: const Scaffold(
            body: SingleChildScrollView(child: GamepadsSection()),
          ),
        ),
      ),
    );
  }

  testWidgets('with nothing to check it takes no room', (tester) async {
    await pump(tester, const GamepadsState(isLoading: false));
    expect(find.text(en.gamepadsTitle), findsNothing);
  });

  testWidgets('without gamepads it says so', (tester) async {
    await pump(
      tester,
      const GamepadsState(
        isLoading: false,
        report: GamepadReport(pads: [], sdl: true, issues: []),
      ),
    );
    expect(find.text('No controllers connected.'), findsOneWidget);
  });

  testWidgets('a pad Wine cannot open says so, and shows the fix', (
    tester,
  ) async {
    await pump(
      tester,
      const GamepadsState(
        isLoading: false,
        report: GamepadReport(
          pads: [_ready, _locked],
          sdl: true,
          issues: [
            HostIssue(
              title: 'No access to the controller Microsoft X-Box 360 pad',
              detail: 'Bodega cannot open /dev/input/event26.',
              command: 'sudo pacman -S steam-devices',
            ),
          ],
        ),
      ),
    );
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('No access'), findsOneWidget);
    expect(find.text('sudo pacman -S steam-devices'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  const empty = GamepadReport(pads: [], sdl: true, issues: []);

  testWidgets('looking again asks the bloc', (tester) async {
    await pump(tester, const GamepadsState(isLoading: false, report: empty));
    await tester.tap(find.text('Check again'));
    verify(() => gamepads.add(const GamepadsEvent.load())).called(1);
  });

  testWidgets('it cannot look again while it is looking', (tester) async {
    await pump(tester, const GamepadsState(isLoading: true, report: empty));
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Check again'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
