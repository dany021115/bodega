// The compiler never compares the two ARBs: a message added to one file only,
// a placeholder a translation dropped or a message pasted untranslated all
// build, and then show English in the Spanish app or lose a number. These
// checks read lib/l10n/ as data and name the key (N9, L1, L12; design §9).
//
// Each check is a function from ARB maps to the problems it finds. The first
// groups feed it small maps with one fault each, so its failing path stays
// tested; the last one feeds it the real files and expects no problem.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An ARB file as JSON: messages, their `@key` metadata, `@@` attributes.
typedef _Arb = Map<String, Object?>;

const _enFile = 'app_en.arb';
const _esFile = 'app_es.arb';

/// Words a Spanish message may keep from its English one (check 4), matched
/// whole and ignoring case, a name of several words as a whole.
const _sameInBothLanguages = {
  // Brand and product names the app shows.
  'Apple',
  'AreWeAntiCheatYet',
  'AVX',
  'Bodega',
  'D3D10',
  'D3D11',
  'D3D12',
  'D3DMetal',
  'DirectX',
  'DLSS',
  'DXMT',
  'DXVK',
  'Easy Anti-Cheat',
  'esync',
  'Game Porting Toolkit',
  'GameMode',
  'Highball',
  'Linux',
  'Mac',
  'macOS',
  'Metal',
  'MoltenVK',
  'msync',
  'Nintendo',
  'Program Files',
  'Rosetta',
  'Ryubing',
  'Ryujinx',
  'Steam',
  'Switch',
  'vkd3d',
  'Vulkan',
  'Windows',
  'Wine',
  'wined3d',
  // Words the Spanish UI uses unchanged.
  'anti-cheat',
  'app',
  'apps',
  'backend',
  'backends',
  'bits',
  'commit',
  'Firmware',
  'GPU',
  'HUD',
  'log',
  'logs',
  'MB',
  'OK',
  'sync',
  'tarball',
  'Terminal',
};

/// Check 1: both files hold the same messages, and app_es.arb nothing else
/// but `@@locale`: the metadata lives in the template.
List<String> _keyProblems(_Arb en, _Arb es) => [
  for (final key in _messageKeys(en).difference(_messageKeys(es)))
    '$key: in $_enFile, missing from $_esFile',
  for (final key in _messageKeys(es).difference(_messageKeys(en)))
    '$key: in $_esFile, missing from $_enFile',
  for (final key in es.keys)
    if (key.startsWith('@') && key != '@@locale')
      '$key: metadata goes in $_enFile; $_esFile holds messages and @@locale',
];

/// Check 2: every message of app_en.arb has its `@key` with a description,
/// each placeholder declared there a type and an example (L12), and no `@key`
/// outlives its message.
List<String> _metadataProblems(_Arb en) {
  final problems = <String>[];
  for (final key in _messageKeys(en)) {
    final metadata = en['@$key'];
    if (metadata is! Map) {
      problems.add('$key: no @$key in $_enFile');
      continue;
    }
    if (!_isText(metadata['description'])) {
      problems.add('$key: @$key has no description');
    }
    final placeholders = metadata['placeholders'];
    if (placeholders is! Map) continue;
    for (final MapEntry(key: name, :value) in placeholders.entries) {
      for (final field in const ['type', 'example']) {
        if (value is! Map || !_isText(value[field])) {
          problems.add('$key: {$name} has no $field in @$key');
        }
      }
    }
  }
  for (final key in en.keys) {
    if (!key.startsWith('@') || key.startsWith('@@')) continue;
    final message = key.substring(1);
    if (!en.containsKey(message)) {
      problems.add('$message: @$message describes no message');
    }
  }
  return problems;
}

/// Check 3: each message, in both files, uses the placeholders its `@key`
/// declares, no more and no fewer. Every argument counts, at any depth: the
/// second plural of a sentence with two counts too.
List<String> _placeholderProblems(
  _Arb en,
  _Arb es, {
  bool useEscaping = false,
}) {
  final problems = <String>[];
  for (final key in _messageKeys(en)) {
    final metadata = en['@$key'];
    final placeholders = metadata is Map ? metadata['placeholders'] : null;
    final declared = {
      if (placeholders is Map) ...placeholders.keys.cast<String>(),
    };
    for (final (file, arb) in [(_enFile, en), (_esFile, es)]) {
      final message = arb[key];
      if (message == null) continue; // Check 1 names it.
      if (message is! String) {
        problems.add('$key: $file holds no text');
        continue;
      }
      final Set<String> used;
      try {
        used = _scan(message, useEscaping: useEscaping).arguments;
      } on FormatException catch (e) {
        problems.add(
          '$key: $file does not parse (${e.message}, at ${e.offset})',
        );
        continue;
      }
      for (final name in declared.difference(used)) {
        problems.add('$key: {$name} is declared in @$key, missing from $file');
      }
      for (final name in used.difference(declared)) {
        problems.add('$key: $file uses {$name}, which @$key does not declare');
      }
    }
  }
  return problems;
}

/// Check 4: a Spanish message equal to its English one is a copy, unless
/// nothing is left of it without ICU syntax, placeholders, digits,
/// punctuation and [_sameInBothLanguages].
List<String> _copyProblems(_Arb en, _Arb es, {bool useEscaping = false}) {
  final problems = <String>[];
  for (final key in _messageKeys(en)) {
    final message = en[key];
    if (message is! String || es[key] != message) continue;
    try {
      final left = _wordsToTranslate(message, useEscaping: useEscaping);
      if (left.isNotEmpty) {
        problems.add(
          '$key: $_esFile copies $_enFile; translate it, or allowlist '
          '${left.join(', ')}',
        );
      }
    } on FormatException catch (e) {
      problems.add('$key: does not parse (${e.message}, at ${e.offset})');
    }
  }
  return problems;
}

/// Check 5: gen-l10n found every message translated. [report] is
/// lib/l10n/untranslated.json, null when it is missing: gen-l10n always
/// writes it, `{}` when nothing is left untranslated.
List<String> _untranslatedProblems(String? report) {
  if (report == null) {
    return ['untranslated.json is missing: run flutter gen-l10n'];
  }
  final Object? parsed;
  try {
    parsed = jsonDecode(report);
  } on FormatException {
    return ['untranslated.json is not JSON: $report'];
  }
  if (parsed is! Map) return ['untranslated.json holds $report, not {}'];
  return [
    for (final MapEntry(key: locale, :value) in parsed.entries)
      if (value is List && value.isNotEmpty)
        for (final key in value) '$key: gen-l10n found no $locale translation'
      else
        '$locale: untranslated.json lists $value',
  ];
}

/// Message keys: everything but `@key` metadata and `@@` attributes.
Set<String> _messageKeys(_Arb arb) => {
  for (final key in arb.keys)
    if (!key.startsWith('@')) key,
};

bool _isText(Object? value) => value is String && value.trim().isNotEmpty;

final _wordPattern = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true);
final _letter = RegExp(r'\p{L}', unicode: true);

List<String> _wordsOf(String text) => [
  for (final match in _wordPattern.allMatches(text)) match[0]!,
];

/// [_sameInBothLanguages], each as its lowercase words, longest first: "Easy
/// Anti-Cheat" goes before "anti-cheat".
final _allowed = [
  for (final entry in _sameInBothLanguages) _wordsOf(entry.toLowerCase()),
]..sort((a, b) => b.length.compareTo(a.length));

/// The words of [message] a translation has to change: what is left of its
/// text without ICU syntax, placeholders, allowlisted words, digits and
/// punctuation.
List<String> _wordsToTranslate(String message, {bool useEscaping = false}) {
  final words = _wordsOf(
    _scan(message, useEscaping: useEscaping).text.join(' '),
  );
  final left = <String>[];
  for (var i = 0; i < words.length;) {
    final allowed = _allowedAt(words, i);
    if (allowed > 0) {
      i += allowed;
      continue;
    }
    if (words[i].contains(_letter)) left.add(words[i]);
    i++;
  }
  return left;
}

/// How many of [words], from [at] on, an allowlisted name covers: 0 if none.
int _allowedAt(List<String> words, int at) {
  for (final name in _allowed) {
    if (at + name.length > words.length) continue;
    var matched = 0;
    while (matched < name.length &&
        words[at + matched].toLowerCase() == name[matched]) {
      matched++;
    }
    if (matched == name.length) return matched;
  }
  return 0;
}

/// A message as gen-l10n reads it: every argument, at any depth, and the runs
/// of literal text around the ICU syntax.
typedef _Icu = ({Set<String> arguments, List<String> text});

/// Reads [message] as gen-l10n's parser does (flutter_tools'
/// `message_parser.dart`), and throws a [FormatException] where that parser
/// reports a syntax error. It also throws at a `}` that closes nothing, where
/// gen-l10n reports nothing and drops the rest of the message.
///
/// A brace in text opens an argument: `{name}`, `{name, plural, …}`,
/// `{name, select, …}` or `{name, date, ::yMd}`. Inside a plural or a select,
/// `=1{…}`, `one{…}` and `other{…}` are branches: their braces hold a message,
/// with its own text and arguments, and are no argument. An apostrophe is
/// text, as gen-l10n reads it by default; with its `use-escaping` on, `'…'` is
/// quoted text, braces included, and `''` an apostrophe.
_Icu _scan(String message, {bool useEscaping = false}) =>
    _IcuScanner(message, useEscaping).read();

class _IcuScanner {
  _IcuScanner(this._source, this._useEscaping);

  final String _source;
  final bool _useEscaping;
  final _arguments = <String>{};
  final _text = <String>[];
  var _at = 0;

  static final _spaces = RegExp(r'\s*');
  static final _name = RegExp(r'[A-Za-z_]\w*');
  static final _number = RegExp(r'\d+');
  static final _word = RegExp(r'\w+');

  _Icu read() {
    _message(inBranch: false);
    return (arguments: _arguments, text: _text);
  }

  /// Text and arguments, up to the `}` that closes a branch, or the end.
  void _message({required bool inBranch}) {
    final text = StringBuffer();
    void endText() {
      if (text.isNotEmpty) _text.add(text.toString());
      text.clear();
    }

    while (_at < _source.length && _source[_at] != '}') {
      final char = _source[_at];
      if (char == '{') {
        endText();
        _argument();
      } else if (char == "'" && _useEscaping) {
        final end = _source.indexOf("'", _at + 1);
        if (end < 0) throw _error('an apostrophe that closes the quote');
        text.write(end == _at + 1 ? "'" : _source.substring(_at + 1, end));
        _at = end + 1;
      } else {
        text.write(char);
        _at++;
      }
    }
    endText();
    if (inBranch && _at == _source.length) {
      throw _error('expected the } that closes the branch');
    }
    if (!inBranch && _at < _source.length) {
      throw _error('a } that closes nothing');
    }
  }

  /// `{name}`, `{name, plural|select, branches}` or
  /// `{name, date|time, ::skeleton}`, from its `{`.
  void _argument() {
    _at++;
    _arguments.add(_read(_name, 'an argument name'));
    if (_eat('}')) return;
    _expect(',');
    final kind = _read(_name, 'plural, select, date or time');
    _expect(',');
    switch (kind) {
      case 'plural' || 'select':
        while (!_eat('}')) {
          if (_eat('=')) {
            _read(_number, 'a number after =');
          } else {
            _read(_word, 'a branch such as other{…}, or }');
          }
          _expect('{');
          _message(inBranch: true);
          _expect('}');
        }
      case 'date' || 'time':
        _expect(':');
        _expect(':');
        _read(_word, 'a date or time skeleton');
        _expect('}');
      default:
        throw _error('expected plural, select, date or time, not $kind');
    }
  }

  /// Skips spaces, as gen-l10n does between the parts of an argument.
  void _skipSpaces() => _at = _spaces.matchAsPrefix(_source, _at)!.end;

  bool _eat(String char) {
    _skipSpaces();
    if (!_source.startsWith(char, _at)) return false;
    _at += char.length;
    return true;
  }

  void _expect(String char) {
    if (!_eat(char)) throw _error('expected $char');
  }

  String _read(RegExp token, String what) {
    _skipSpaces();
    final match =
        token.matchAsPrefix(_source, _at) ?? (throw _error('expected $what'));
    _at = match.end;
    return match[0]!;
  }

  FormatException _error(String what) => FormatException(what, _source, _at);
}

_Arb _readArb(String file) =>
    jsonDecode(File('lib/l10n/$file').readAsStringSync()) as _Arb;

/// Whether l10n.yaml turns on gen-l10n's `use-escaping`, which changes what
/// an apostrophe means to [_scan].
bool _useEscaping(String l10nYaml) => RegExp(
  r'^use-escaping:\s*true\b',
  multiLine: true,
  caseSensitive: false,
).hasMatch(l10nYaml);

/// A problem that names [key] and, if given, [placeholder].
Matcher _names(String key, [String? placeholder]) => allOf(
  startsWith('$key: '),
  placeholder == null ? anything : contains('{$placeholder}'),
);

void main() {
  group('the ICU scanner', () {
    Set<String> arguments(String message, {bool useEscaping = false}) =>
        _scan(message, useEscaping: useEscaping).arguments;

    test('finds simple placeholders', () {
      expect(arguments('Stop the bottle {bottle}'), {'bottle'});
      expect(arguments('{ received } MB of {total} MB'), {'received', 'total'});
      expect(arguments('Close'), isEmpty);
    });

    test('tells argument braces from branch braces, at any depth', () {
      expect(
        arguments(
          '{count, plural, =1{1 app in {bottles, plural, =1{1 bottle} '
          'other{{bottles} bottles}}} other{{count} apps}}',
        ),
        {'count', 'bottles'},
      );
      expect(
        arguments('{n, plural, zero{none} one{one} few{a few} other{{n}}}'),
        {'n'},
      );
    });

    test('finds select, date and time arguments', () {
      expect(
        arguments('{state, select, open{Open in {bottle}} other{Closed}}'),
        {'state', 'bottle'},
      );
      expect(arguments('Checked {day, date, ::yMMMd} at {hour, time, ::Hm}'), {
        'day',
        'hour',
      });
    });

    test('reads an apostrophe as text, as gen-l10n does by default', () {
      expect(arguments("Anything you haven't saved in {bottle} is lost"), {
        'bottle',
      });
      expect(arguments("Can't open '{path}'"), {'path'});
    });

    test("with use-escaping, reads '…' as quoted text and '' as an "
        'apostrophe', () {
      expect(arguments("'{name}' as typed, in {bottle}", useEscaping: true), {
        'bottle',
      });
      expect(_scan("Bodega''s {thing}", useEscaping: true).text, ["Bodega's "]);
      expect(
        () => _scan("Bodega's {thing}", useEscaping: true),
        throwsFormatException,
      );
    });

    test('keeps the text without syntax or placeholders', () {
      expect(_scan('{count, plural, =1{1 app} other{{count} apps}}').text, [
        '1 app',
        ' apps',
      ]);
    });

    test('rejects a } that closes nothing, which gen-l10n drops silently', () {
      // gen-l10n turns it into 'Stop' and reports nothing.
      expect(() => _scan('Stop} the bottle {bottle}'), throwsFormatException);
    });

    test('rejects what gen-l10n reports as a syntax error', () {
      for (final message in [
        '{bottle',
        '{}',
        '{n, plural, other{x}',
        '{n, plural, {x}}',
        '{n, number}',
        '{n, ordinal, other{x}}',
      ]) {
        expect(() => _scan(message), throwsFormatException, reason: message);
      }
    });
  });

  group('each check, on small ARB maps', () {
    // Every check passes this pair, and each test breaks one thing in it. No
    // Spanish in test/ (L19): a "translation" here is the English text in
    // brackets, which differs from it as a real one does.
    _Arb goodEn() => {
      '@@locale': 'en',
      'commonStop': 'Stop',
      '@commonStop': {'description': 'Button that stops a bottle.'},
      'bottleStopTitle': 'Stop the bottle {bottle}',
      '@bottleStopTitle': {
        'description': 'Title of the dialog that confirms stopping a bottle.',
        'placeholders': {
          'bottle': {'type': 'String', 'example': 'Steam'},
        },
      },
      'libraryCount':
          '{count, plural, =1{1 app in {bottles, plural, =1{1 bottle} '
          'other{{bottles} bottles}}} other{{count} apps in {bottles, plural, '
          '=1{1 bottle} other{{bottles} bottles}}}}',
      '@libraryCount': {
        'description':
            'Under the library title: its apps, in how many bottles.',
        'placeholders': {
          'count': {'type': 'int', 'example': '3'},
          'bottles': {'type': 'int', 'example': '2'},
        },
      },
    };
    _Arb goodEs() {
      final en = goodEn();
      return {
        '@@locale': 'es',
        for (final key in _messageKeys(en)) key: '[${en[key]}]',
      };
    }

    test('pass a pair with nothing wrong', () {
      expect(_keyProblems(goodEn(), goodEs()), isEmpty);
      expect(_metadataProblems(goodEn()), isEmpty);
      expect(_placeholderProblems(goodEn(), goodEs()), isEmpty);
      expect(_copyProblems(goodEn(), goodEs()), isEmpty);
      expect(_untranslatedProblems('{}'), isEmpty);
    });

    test('1 names a message in one file only, and metadata in $_esFile', () {
      expect(_keyProblems(goodEn(), goodEs()..remove('commonStop')), [
        _names('commonStop'),
      ]);
      expect(_keyProblems(goodEn()..remove('commonStop'), goodEs()), [
        _names('commonStop'),
      ]);
      final es = goodEs()..['@commonStop'] = {'description': 'Stop.'};
      expect(_keyProblems(goodEn(), es), [_names('@commonStop')]);
    });

    test('2 names a message without its @key or a description', () {
      expect(_metadataProblems(goodEn()..remove('@commonStop')), [
        _names('commonStop'),
      ]);
      for (final metadata in <Map<String, Object?>>[
        {},
        {'description': ''},
        {'description': '  '},
        {'description': 1},
      ]) {
        expect(_metadataProblems(goodEn()..['@commonStop'] = metadata), [
          _names('commonStop'),
        ], reason: '$metadata');
      }
      final orphan = goodEn()..['@commonGone'] = {'description': 'Gone.'};
      expect(_metadataProblems(orphan), [_names('commonGone')]);
    });

    test('2 names a placeholder without its type or example', () {
      for (final placeholder in [
        {'type': 'String'},
        {'example': 'Steam'},
      ]) {
        final en = goodEn()
          ..['@bottleStopTitle'] = {
            'description': 'Title of the dialog that confirms stopping.',
            'placeholders': {'bottle': placeholder},
          };
        expect(_metadataProblems(en), [_names('bottleStopTitle', 'bottle')]);
      }
    });

    test('3 names a declared placeholder a message lacks', () {
      final es = goodEs()..['bottleStopTitle'] = '[Stop the bottle]';
      expect(_placeholderProblems(goodEn(), es), [
        _names('bottleStopTitle', 'bottle'),
      ]);
    });

    test('3 names a placeholder the @key does not declare', () {
      final es = goodEs()..['bottleStopTitle'] = '[Stop the bottle {name}]';
      expect(
        _placeholderProblems(goodEn(), es),
        unorderedMatches([
          _names('bottleStopTitle', 'bottle'),
          _names('bottleStopTitle', 'name'),
        ]),
      );
      final en = goodEn()..['commonStop'] = 'Stop {bottle}';
      expect(_placeholderProblems(en, goodEs()), [
        _names('commonStop', 'bottle'),
      ]);
    });

    test('3 names the second count of a two-plural message, dropped', () {
      final es = goodEs()
        ..['libraryCount'] = '[{count, plural, =1{1 app} other{{count} apps}}]';
      expect(_placeholderProblems(goodEn(), es), [
        _names('libraryCount', 'bottles'),
      ]);
    });

    test('3 names a renamed select argument, and a message that does not '
        'parse', () {
      final en = goodEn()
        ..['bottleState'] = '{state, select, open{Open} other{Closed}}'
        ..['@bottleState'] = {
          'description': 'Chip on a bottle row: whether it is open.',
          'placeholders': {
            'state': {'type': 'String', 'example': 'open'},
          },
        };
      final es = goodEs()
        ..['bottleState'] = '[{status, select, open{Open} other{Closed}}]';
      expect(
        _placeholderProblems(en, es),
        unorderedMatches([
          _names('bottleState', 'state'),
          _names('bottleState', 'status'),
        ]),
      );
      final broken = goodEs()..['bottleStopTitle'] = '[Stop {bottle]';
      expect(_placeholderProblems(goodEn(), broken), [
        _names('bottleStopTitle'),
      ]);
    });

    test('4 names a Spanish message equal to its English one', () {
      expect(_copyProblems(goodEn(), goodEs()..['commonStop'] = 'Stop'), [
        allOf(_names('commonStop'), contains('Stop')),
      ]);
      final select = {'bottleState': '{state, select, open{Open} other{Shut}}'};
      expect(_copyProblems(select, select), [_names('bottleState')]);
      // An allowlisted name counts as a whole word only.
      final word = {'wineList': 'Winery'};
      expect(_copyProblems(word, word), [_names('wineList')]);
    });

    test('4 lets syntax, placeholders, digits, punctuation and allowlisted '
        'words stay', () {
      final same = {
        'navBackends': 'Backends',
        'bottleAppCount': '{count, plural, =1{1 app} other{{count} apps}}',
        'gptkRelease': 'Game Porting Toolkit {version}',
        'antiCheatTitle': 'Easy Anti-Cheat · D3D11 · Windows 8.1',
        'pathOnly': '{path}',
      };
      expect(_copyProblems(same, same), isEmpty);
    });

    test('5 names what gen-l10n found untranslated, or its missing report', () {
      expect(_untranslatedProblems(null), [contains('untranslated.json')]);
      expect(
        _untranslatedProblems('{\n  "es": [\n    "commonStop"\n  ]\n}\n'),
        [_names('commonStop')],
      );
      expect(_untranslatedProblems('{"es": ['), [
        contains('untranslated.json'),
      ]);
    });
  });

  group('the real ARBs', () {
    late _Arb en;
    late _Arb es;
    late bool useEscaping;

    setUpAll(() {
      en = _readArb(_enFile);
      es = _readArb(_esFile);
      useEscaping = _useEscaping(File('l10n.yaml').readAsStringSync());
    });

    test('hold the same messages (N9, L1)', () {
      expect(_keyProblems(en, es), isEmpty);
    });

    test('describe every message and placeholder (N9, L1, L12)', () {
      expect(_metadataProblems(en), isEmpty);
    });

    test('use the placeholders they declare, in both files (N9, L12)', () {
      expect(_placeholderProblems(en, es, useEscaping: useEscaping), isEmpty);
    });

    test('translate every message (N9)', () {
      expect(_copyProblems(en, es, useEscaping: useEscaping), isEmpty);
    });

    test('leave gen-l10n nothing untranslated (N9, L1)', () {
      final report = File('lib/l10n/untranslated.json');
      expect(
        _untranslatedProblems(
          report.existsSync() ? report.readAsStringSync() : null,
        ),
        isEmpty,
      );
    });
  });
}
