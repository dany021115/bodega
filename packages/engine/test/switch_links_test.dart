// The link guard (SN10): no `://` and no `www.` in Switch's code and text, nor
// where the docs talk about Switch or an emulator, but for the one link the
// rules allow: Ryubing's official download page, as the `page` of its row in
// the emulator table of `switch.dart`. It only reads files, so it imports
// nothing of the engine and runs on Linux CI too.
import 'dart:io';

import 'package:test/test.dart';

/// The repo's root, from `packages/engine`, where `dart test` runs.
const root = '../..';

/// The file that holds the emulator table.
const tableFile = 'packages/engine/lib/switch.dart';

/// The one link allowed: the `page` line of Ryubing's row in the emulator
/// table, which the app opens in the user's browser. Bodega never downloads
/// the emulator itself.
const pageLine = "page: 'https://ryujinx.app/download',";

/// The files the guard names (design §9, §11): each must be there, so a
/// rename cannot skip it.
const named = [
  tableFile,
  'packages/engine/bin/bodega.dart',
  'apps/bodega/lib/domain/entities/switch_game.dart',
  'apps/bodega/lib/domain/entities/switch_status.dart',
  'apps/bodega/lib/domain/repository/switch_repository.dart',
  'apps/bodega/lib/data/repository/switch_repository_impl.dart',
  'apps/bodega/lib/app/bloc/switch/switch_bloc.dart',
  'apps/bodega/lib/app/presentation/switch/switch_page.dart',
  'apps/bodega/lib/app/shared/text/switch_text.dart',
  'apps/bodega/lib/l10n/app_en.arb',
  'apps/bodega/lib/l10n/app_es.arb',
  'README.md',
  'AGENTS.md',
  '.claude/CLAUDE.md',
  '.claude/rules/architecture.md',
];

/// A link: a scheme's `://`, or a bare `www.`.
final link = RegExp(r'://|www\.');

/// What makes a block of the docs talk about Switch: one of these whole
/// words, in any case.
final topic = RegExp(
  r'\b(switch|nintendo|ryubing|ryujinx|eden|nxnative|emulators?)\b',
  caseSensitive: false,
);

/// A list item's first line: its indent, then `-`, `*`, `+`, `1.` or `1)`.
final itemStart = RegExp(r'^(\s*)([-*+]|\d{1,9}[.)])(\s|$)');

final heading = RegExp(r'^#{1,6}(\s|$)');

/// What the app generates, which git ignores (`.claude/CLAUDE.md`).
final generated = RegExp(r'\.(g|freezed|config)\.dart$');

/// What the guard reads, repo-relative: the engine's Switch part and the CLI;
/// every Dart file of the app's `lib/` in a `switch` folder or named
/// `switch_*.dart`, but the generated ones; both ARBs; and the docs, whose
/// Markdown it reads by block.
List<String> checked() => [
  tableFile,
  'packages/engine/bin/bodega.dart',
  ...files('apps/bodega/lib', recursive: true).where(isSwitchDart),
  'apps/bodega/lib/l10n/app_en.arb',
  'apps/bodega/lib/l10n/app_es.arb',
  'README.md',
  'AGENTS.md',
  '.claude/CLAUDE.md',
  ...files('.claude/rules').where((path) => path.endsWith('.md')),
];

/// The files in [dir], repo-relative and sorted, following no link; none when
/// [dir] is missing.
List<String> files(String dir, {bool recursive = false}) {
  final folder = Directory('$root/$dir');
  if (!folder.existsSync()) return [];
  return [
    for (final entity in folder.listSync(
      recursive: recursive,
      followLinks: false,
    ))
      if (entity is File) entity.path.substring(root.length + 1),
  ]..sort();
}

bool isSwitchDart(String path) {
  final folders = path.split('/');
  final name = folders.removeLast();
  return name.endsWith('.dart') &&
      !generated.hasMatch(name) &&
      (name.startsWith('switch_') || folders.contains('switch'));
}

/// The lines, 0-based and sorted, of the Markdown blocks in [lines] that name
/// [topic]: each paragraph and each list item, wrapped lines included. A list
/// item also holds what is indented under it, its nested items and what
/// follows a blank line too; a heading, a table row and a fenced code block
/// are blocks of their own.
List<int> talking(List<String> lines) {
  final blocks = <List<int>>[];
  final items = <({int indent, List<int> block})>[];
  List<int>? paragraph;
  List<int>? fence;
  var fenceMark = '';
  var afterBlank = false;
  for (var i = 0; i < lines.length; i++) {
    final text = lines[i].trimLeft();
    if (fence != null) {
      fence.add(i);
      for (final item in items) {
        item.block.add(i);
      }
      if (text.startsWith(fenceMark)) fence = null;
      continue;
    }
    if (text.isEmpty) {
      paragraph = null;
      afterBlank = true;
      continue;
    }
    final indent = lines[i].length - text.length;
    final isItem = itemStart.hasMatch(lines[i]);
    final isHeading = heading.hasMatch(text);
    // A heading ends every list item; a new item, or any line after a blank
    // line, ends those at its indent or deeper.
    while (items.isNotEmpty &&
        (isHeading || (isItem || afterBlank) && indent <= items.last.indent)) {
      items.removeLast();
    }
    afterBlank = false;
    for (final item in items) {
      item.block.add(i);
    }
    if (text.startsWith('```') || text.startsWith('~~~')) {
      fenceMark = text.substring(0, 3);
      fence = [i];
      blocks.add(fence);
      paragraph = null;
    } else if (isHeading || text.startsWith('|')) {
      blocks.add([i]);
      paragraph = null;
    } else if (isItem) {
      final block = [i];
      blocks.add(block);
      items.add((indent: indent, block: block));
      paragraph = null;
    } else if (items.isEmpty) {
      if (paragraph == null) {
        paragraph = [];
        blocks.add(paragraph);
      }
      paragraph.add(i);
    }
  }
  return {
    for (final block in blocks)
      if (block.any((i) => topic.hasMatch(lines[i]))) ...block,
  }.toList()..sort();
}

/// The line, 0-based, of [pageLine] in the emulator table of [lines], from
/// `const switchEmulators` to the `];` that closes it, or null: its first
/// such line only.
int? pageAt(List<String> lines) {
  final start = lines.indexWhere((l) => l.startsWith('const switchEmulators'));
  final end = start < 0 ? -1 : lines.indexOf('];', start);
  for (var i = start + 1; i < end; i++) {
    if (lines[i].trim() == pageLine) return i;
  }
  return null;
}

/// The lines of [path] that hold a link, as `path:line: text`: in Markdown,
/// only where it talks about Switch ([talking]); in [tableFile], every line
/// but the table's page ([pageAt]).
List<String> links(String path, List<String> lines) {
  final read = path.endsWith('.md')
      ? talking(lines)
      : [for (var i = 0; i < lines.length; i++) i];
  final page = path == tableFile ? pageAt(lines) : null;
  return [
    for (final i in read)
      if (link.hasMatch(lines[i]) && i != page)
        '$path:${i + 1}: ${lines[i].trim()}',
  ];
}

void main() {
  test('reads the Switch code, both ARBs and the docs, each of them there '
      '(SN10)', () {
    final missing = [
      for (final path in named)
        if (!File('$root/$path').existsSync()) path,
    ];
    if (missing.isNotEmpty) fail('missing: ${missing.join(', ')}');
    expect(checked(), containsAll(named));
  });

  group('the one link allowed is the page of the emulator table (SN10)', () {
    const table = [
      'const switchEmulators = <Emulator>[',
      '  (',
      "    name: 'Ryubing',",
      '    $pageLine',
      '  ),',
      '];',
    ];

    /// The table with [line] after its page.
    List<String> withLine(String line) => [
      ...table.take(4),
      '    $line',
      ...table.skip(4),
    ];

    test('in the table of switch.dart, it passes', () {
      expect(links(tableFile, table), isEmpty);
    });

    test('anywhere else, it fails naming the file and the line', () {
      expect(links(tableFile, ['// $pageLine', ...table]), [
        '$tableFile:1: // $pageLine',
      ]);
      expect(links(tableFile, [...table, '// $pageLine']), [
        '$tableFile:7: // $pageLine',
      ]);
      // A second page in the table.
      expect(links(tableFile, withLine(pageLine)), ['$tableFile:5: $pageLine']);
      expect(links(named[1], table), ['${named[1]}:4: $pageLine']);
    });

    test('any other link in the table fails', () {
      // Put together here, so the change adds no link but the page (SN11).
      const host = 'example.org';
      for (final line in [
        pageLine.replaceFirst("download'", "download/latest'"),
        pageLine.replaceFirst(RegExp('//[^/]+'), '//$host'),
        '$pageLine // www.$host',
      ]) {
        expect(links(tableFile, withLine(line)), ['$tableFile:5: $line']);
      }
    });
  });

  for (final path in checked()) {
    test(
      switch (path) {
        tableFile =>
          'no :// or www. in $path but the page of its emulator '
              'table (SN10)',
        _ when path.endsWith('.md') =>
          'no :// or www. where $path talks about Switch (SN10)',
        _ => 'no :// or www. in $path (SN10)',
      },
      () {
        final file = File('$root/$path');
        if (!file.existsSync()) fail('missing: $path');
        final found = links(path, file.readAsLinesSync());
        if (found.isNotEmpty) fail(found.join('\n'));
      },
    );
  }
}
