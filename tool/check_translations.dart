// Reports how many `S(...)` call sites are still missing a French or
// Spanish form.
//
// `S`'s `fr`/`es` are optional and fall back to English, which is what let
// the four-language migration happen incrementally without breaking the
// build. The cost of that choice is that a missing translation is silent —
// it just renders English. This script is the counterweight: it makes
// "everything is translated" a number you can check instead of a claim.
//
// Usage:
//   dart tool/check_translations.dart            # summary per package
//   dart tool/check_translations.dart --list     # every incomplete site
//
// Exits non-zero when anything is missing, so it can gate a release.

import 'dart:io';

/// Packages scanned, in report order.
const _packages = <String>[
  'packages/school_shared',
  'apps/school_admin',
  'apps/school_parent',
  'apps/school_driver',
  'apps/school_super_admin',
];

void main(List<String> args) {
  final listAll = args.contains('--list');
  final root = Directory.current;

  var totalSites = 0;
  var totalComplete = 0;
  final incompleteByPackage = <String, List<_Site>>{};

  for (final package in _packages) {
    final libDir = Directory('${root.path}/$package/lib');
    if (!libDir.existsSync()) continue;

    final sites = <_Site>[];
    for (final file in libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      sites.addAll(_sitesIn(file, package));
    }

    final incomplete = sites.where((s) => !s.isComplete).toList();
    totalSites += sites.length;
    totalComplete += sites.length - incomplete.length;
    incompleteByPackage[package] = incomplete;

    final done = sites.length - incomplete.length;
    final status = incomplete.isEmpty ? 'OK' : '${incomplete.length} missing';
    stdout.writeln(
      '${package.padRight(28)} $done/${sites.length} translated  ($status)',
    );
  }

  if (listAll) {
    for (final entry in incompleteByPackage.entries) {
      if (entry.value.isEmpty) continue;
      stdout.writeln('\n${entry.key}:');
      for (final site in entry.value) {
        final missing = [
          if (site.fr == null) 'fr',
          if (site.es == null) 'es',
        ].join('+');
        stdout.writeln('  ${site.file}:${site.line}  missing $missing  '
            '— ${_preview(site.en)}');
      }
    }
  }

  final missing = totalSites - totalComplete;
  stdout.writeln(
    '\n$totalComplete/$totalSites complete'
    '${missing == 0 ? '' : ' — $missing missing fr and/or es'}',
  );
  if (missing > 0 && !listAll) {
    stdout.writeln('Run with --list to see them.');
  }
  exit(missing == 0 ? 0 : 1);
}

String _preview(String en) {
  final flat = en.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flat.length <= 48 ? flat : '${flat.substring(0, 45)}...';
}

class _Site {
  _Site({
    required this.file,
    required this.line,
    required this.en,
    required this.fr,
    required this.es,
  });

  final String file;
  final int line;
  final String en;
  final String? fr;
  final String? es;

  bool get isComplete => fr != null && es != null;
}

/// Finds each `S(` in [file] and reads its argument list.
///
/// Deliberately a brace-matching scan rather than a regex: roughly a third
/// of the call sites span multiple lines, and many contain nested
/// parentheses, adjacent string literals and `$interpolation`, all of which
/// defeat a line-based pattern.
List<_Site> _sitesIn(File file, String package) {
  final source = file.readAsStringSync();
  final relative = file.path
      .replaceAll('\\', '/')
      .replaceFirst('${Directory.current.path.replaceAll('\\', '/')}/', '');
  final sites = <_Site>[];

  // `S` is only ever a constructor call here; the pattern requires a
  // non-identifier char before it so `AppSettings(` / `_someS(` don't match.
  final pattern = RegExp(r'(^|[^A-Za-z0-9_$])S\(');
  for (final match in pattern.allMatches(source)) {
    final open = source.indexOf('(', match.start);
    final close = _matchingParen(source, open);
    if (close == -1) continue;

    final argsText = source.substring(open + 1, close);
    // The class itself, not a call site.
    if (argsText.contains('this.en')) continue;

    sites.add(
      _Site(
        file: relative,
        line: '\n'.allMatches(source.substring(0, match.start)).length + 1,
        en: _firstPositional(argsText),
        fr: _named(argsText, 'fr'),
        es: _named(argsText, 'es'),
      ),
    );
  }
  return sites;
}

/// Index of the `)` closing the `(` at [open], skipping over strings,
/// comments and nested parens.
int _matchingParen(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (char == r'$' && i + 1 < source.length && source[i + 1] == '{') {
      // Skip an interpolation block wholesale — it can contain anything.
      final end = _matchingBrace(source, i + 1);
      if (end == -1) return -1;
      i = end;
      continue;
    }
    if (char == "'" || char == '"') {
      final end = _endOfString(source, i);
      if (end == -1) return -1;
      i = end;
      continue;
    }
    if (char == '/' && i + 1 < source.length && source[i + 1] == '/') {
      final nl = source.indexOf('\n', i);
      if (nl == -1) return -1;
      i = nl;
      continue;
    }
    if (char == '(') depth++;
    if (char == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

int _matchingBrace(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// Index of the closing quote of the string literal starting at [start],
/// handling escapes, raw strings and triple quotes.
int _endOfString(String source, int start) {
  final quote = source[start];
  final isRaw = start > 0 && source[start - 1] == 'r';
  final isTriple = source.startsWith(quote * 3, start);
  final delimiter = isTriple ? quote * 3 : quote;

  var i = start + delimiter.length;
  while (i < source.length) {
    if (!isRaw && source[i] == r'\') {
      i += 2;
      continue;
    }
    if (source.startsWith(delimiter, i)) return i + delimiter.length - 1;
    i++;
  }
  return -1;
}

/// The first positional argument's literal text (the English form).
String _firstPositional(String args) {
  final buffer = StringBuffer();
  var depth = 0;
  for (var i = 0; i < args.length; i++) {
    final char = args[i];
    if (char == '(' || char == '{' || char == '[') depth++;
    if (char == ')' || char == '}' || char == ']') depth--;
    if (char == ',' && depth == 0) break;
    if (char == "'" || char == '"') {
      final end = _endOfString(args, i);
      if (end == -1) break;
      buffer.write(args.substring(i, end + 1));
      i = end;
      continue;
    }
    buffer.write(char);
  }
  return buffer
      .toString()
      .replaceAll(RegExp("^\\s*r?['\"]|['\"]\\s*\$"), '')
      .trim();
}

/// The value of named argument [name], or null when it isn't supplied.
String? _named(String args, String name) {
  final match = RegExp('(^|[^A-Za-z0-9_])$name\\s*:').firstMatch(args);
  if (match == null) return null;
  final valueStart = args.indexOf(':', match.start) + 1;
  return args.substring(valueStart).trim().isEmpty
      ? null
      : args.substring(valueStart).trim();
}
