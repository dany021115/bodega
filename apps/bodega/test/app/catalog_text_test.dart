// The catalog's prose, worded by app id from the ARBs (design §7). In English
// it is the engine's own text, field by field, so a catalog update fails here
// until the ARBs follow; in Spanish it keeps that shape, with every string
// translated (N10, L16). Spanish comes only through lookupAppL10n.
//
// Each check is a function from the engine's text and catalogProse to the
// problems it finds, named by id and field. The last group feeds it one fault
// at a time, so its failing path stays tested.

import 'package:bodega/app/shared/text/catalog_text.dart';
import 'package:bodega/l10n/l10n.dart';
import 'package:engine/engine.dart' as engine;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The engine's text of [entry], in the shape of [catalogProse].
CatalogProse _proseOf(engine.CatalogEntry entry) => (
  statusNote: entry.statusNote,
  flaky: entry.flaky,
  notes: entry.notes,
  issues: [for (final issue in entry.knownIssues) (issue.symptom, issue.fix)],
);

/// [prose] by field, each named as in the engine's catalog data.
Map<String, String> _fields(CatalogProse prose) => {
  'statusNote': prose.statusNote,
  'flaky': ?prose.flaky,
  for (final (i, note) in prose.notes.indexed) 'notes[$i]': note,
  for (final (i, (symptom, fix)) in prose.issues.indexed) ...{
    'knownIssues[$i].symptom': symptom,
    'knownIssues[$i].fix': fix,
  },
};

/// Where [english], what the ARBs say in English about the app [id], differs
/// from [data], the engine's text: a field missing, added or worded otherwise.
List<String> _englishProblems(
  String id,
  CatalogProse data,
  CatalogProse? english,
) {
  if (english == null) {
    return [
      '$id: no prose in the ARBs; add its keys and its catalogProse case',
    ];
  }
  final want = _fields(data);
  final got = _fields(english);
  return [
    for (final MapEntry(key: field, value: text) in want.entries)
      if (!got.containsKey(field))
        '$id: $field is missing from app_en.arb'
      else if (got[field] != text)
        '$id: $field differs: catalog_data.dart has "$text", app_en.arb '
            '"${got[field]}"',
    for (final field in got.keys)
      if (!want.containsKey(field))
        '$id: $field is in app_en.arb, not in catalog_data.dart',
  ];
}

/// Where [spanish] has a field [english] lacks, or the other way round, or
/// keeps a string as it is in English or empty.
List<String> _spanishProblems(
  String id,
  CatalogProse english,
  CatalogProse? spanish,
) {
  if (spanish == null) return ['$id: no prose in Spanish'];
  final en = _fields(english);
  final es = _fields(spanish);
  return [
    for (final field in en.keys)
      if (!es.containsKey(field)) '$id: $field is missing in Spanish',
    for (final MapEntry(key: field, value: text) in es.entries)
      if (!en.containsKey(field))
        '$id: $field is in Spanish only'
      else if (text == en[field])
        '$id: $field is not translated: "$text"'
      else if (text.trim().isEmpty)
        '$id: $field is empty in Spanish',
  ];
}

void main() {
  final en = lookupAppL10n(const Locale('en'));
  final es = lookupAppL10n(const Locale('es'));
  final entries = engine.catalogEntries();

  test('in English, each app reads as the engine writes it (N10, L16)', () {
    expect(entries, isNotEmpty);
    expect([
      for (final entry in entries)
        ..._englishProblems(
          entry.id,
          _proseOf(entry),
          catalogProse(entry.id, en),
        ),
    ], isEmpty);
  });

  test('in Spanish, each app keeps that shape, every string translated '
      '(N10, L16)', () {
    expect([
      for (final entry in entries)
        ..._spanishProblems(
          entry.id,
          _proseOf(entry),
          catalogProse(entry.id, es),
        ),
    ], isEmpty);
  });

  test('an id the catalog does not have has no prose', () {
    expect(catalogProse('nope', en), isNull);
    expect(catalogProse('nope', es), isNull);
  });

  group('a fault is named by its id and field', () {
    final steam = _proseOf(engine.catalogEntry('steam'));

    test('an id with no keys', () {
      expect(_englishProblems('nope', steam, catalogProse('nope', en)), [
        'nope: no prose in the ARBs; add its keys and its catalogProse case',
      ]);
    });

    test('a note the ARBs have not followed', () {
      final CatalogProse changed = (
        statusNote: steam.statusNote,
        flaky: steam.flaky,
        notes: [...steam.notes]..[1] = 'A newer note.',
        issues: steam.issues,
      );
      expect(_englishProblems('steam', changed, catalogProse('steam', en)), [
        'steam: notes[1] differs: catalog_data.dart has "A newer note.", '
            'app_en.arb "${en.catalogSteamNote2}"',
      ]);
    });

    test('a flaky note or a known issue the data added, or a note it '
        'dropped', () {
      final CatalogProse changed = (
        statusNote: steam.statusNote,
        flaky: 'It is unstable.',
        notes: steam.notes.sublist(0, 3),
        issues: [...steam.issues, ('A new symptom', 'Its fix')],
      );
      expect(_englishProblems('steam', changed, catalogProse('steam', en)), [
        'steam: flaky is missing from app_en.arb',
        'steam: knownIssues[7].symptom is missing from app_en.arb',
        'steam: knownIssues[7].fix is missing from app_en.arb',
        'steam: notes[3] is in app_en.arb, not in catalog_data.dart',
      ]);
    });

    test('a Spanish text left in English or empty, or a field one language '
        'lacks', () {
      // Steam's Spanish with faults put in: no Spanish is written here.
      final spanish = catalogProse('steam', es)!;
      final CatalogProse faulty = (
        statusNote: steam.statusNote,
        flaky: 'A flaky note English does not have.',
        notes: [...spanish.notes.sublist(0, 2), ' '],
        issues: spanish.issues,
      );
      expect(_spanishProblems('steam', steam, faulty), [
        'steam: notes[3] is missing in Spanish',
        'steam: statusNote is not translated: "${steam.statusNote}"',
        'steam: flaky is in Spanish only',
        'steam: notes[2] is empty in Spanish',
      ]);
    });
  });
}
