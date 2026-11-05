import 'dart:io';

import 'package:bodega/app/presentation/bottles/widgets/app_tile.dart';
import 'package:bodega/app/shared/widgets/app_icon.dart';
import 'package:bodega/domain/entities/library_app.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _app = LibraryApp(
  bottle: 'games',
  key: 'blur.exe',
  id: 'custom',
  title: 'Blur',
);

void main() {
  group('AppTile', () {
    late int opened;
    late int options;
    late int hidden;

    Future<void> pumpTile(WidgetTester tester) async {
      opened = 0;
      options = 0;
      hidden = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 130,
                height: 124,
                child: AppTile(
                  app: _app,
                  onOpen: () => opened++,
                  onOptions: () => options++,
                  onHide: () => hidden++,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Finder tile() => find.text('Blur');

    testWidgets('a click does not open it', (tester) async {
      await pumpTile(tester);
      await tester.tap(tile());
      await tester.pump(const Duration(seconds: 1));
      expect(opened, 0);
    });

    testWidgets('a double click opens it', (tester) async {
      await pumpTile(tester);
      await tester.tap(tile());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(tile());
      await tester.pump(const Duration(seconds: 1));
      expect(opened, 1);
    });

    testWidgets('Enter opens the selected one', (tester) async {
      await pumpTile(tester);
      await tester.tap(tile());
      await tester.pump(const Duration(seconds: 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('the menu button offers both', (tester) async {
      await pumpTile(tester);
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Abrir'), findsOneWidget);
      await tester.tap(find.text('Ocultar'));
      await tester.pumpAndSettle();
      expect(hidden, 1);
      expect(opened, 0);
    });

    testWidgets('the menu also runs it with options', (tester) async {
      await pumpTile(tester);
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ejecutar con opciones…'));
      await tester.pumpAndSettle();
      expect(options, 1);
      expect(opened, 0);
    });

    testWidgets('a right click offers both too', (tester) async {
      await pumpTile(tester);
      await tester.tap(tile(), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(opened, 1);
    });
  });

  group('AppIcon', () {
    Future<void> pumpIcon(
      WidgetTester tester, {
      String id = 'custom',
      String? iconPath,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppIcon(id: id, title: 'Blur', iconPath: iconPath),
        ),
      ),
    );

    testWidgets('its own picture goes first', (tester) async {
      final dir = Directory.systemTemp.createTempSync('bodega-icon');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/a.png')..writeAsBytesSync(_pixel);
      await pumpIcon(tester, id: 'steam', iconPath: file.path);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('without a picture, the logo of the catalog', (tester) async {
      await pumpIcon(tester, id: 'steam');
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('without a logo, the initial', (tester) async {
      await pumpIcon(tester);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('a picture that cannot be read falls to the next', (
      tester,
    ) async {
      await pumpIcon(tester, iconPath: '/no/existe.ico');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      expect(find.text('B'), findsOneWidget);
    });
  });
}

/// A PNG of one pixel.
final Uint8List _pixel = Uint8List.fromList(const [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0,
  0,
  0,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0,
  0,
  0,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0,
  0,
  3,
  1,
  1,
  0,
  0x18,
  0xDD,
  0x8D,
  0xB0,
  0,
  0,
  0,
  0,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
