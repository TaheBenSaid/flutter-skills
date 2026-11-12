import 'dart:io';

const _usage = '''
Usage: dart rtl_audit.dart [path] [--fix]

  path   folder to scan (default: lib)
  --fix  apply the safe fixes in place
''';

const _skipSuffixes = ['.g.dart', '.freezed.dart', '.gr.dart', '.config.dart', '.mocks.dart'];

const _alignments = {
  'topLeft': 'topStart',
  'centerLeft': 'centerStart',
  'bottomLeft': 'bottomStart',
  'topRight': 'topEnd',
  'centerRight': 'centerEnd',
  'bottomRight': 'bottomEnd',
};

const _sideKeys = {'left': 'start', 'right': 'end'};

const _cornerKeys = {
  'topLeft': 'topStart',
  'topRight': 'topEnd',
  'bottomLeft': 'bottomStart',
  'bottomRight': 'bottomEnd',
};

const _directionalTokens = {'arrow', 'chevron', 'back', 'forward', 'next', 'prev', 'previous', 'caret'};
const _verticalTokens = {'up', 'down', 'top', 'bottom'};

class Edit {
  Edit(this.start, this.end, this.text);
  final int start;
  final int end;
  final String text;
}

class Finding {
  Finding(this.file, this.line, this.message, {this.fixable = false});
  final String file;
  final int line;
  final String message;
  final bool fixable;
}

class Source {
  Source(this.path, this.text) : code = _mask(text);

  final String path;
  final String text;
  final String code;
  final edits = <int, Edit>{};
  final findings = <Finding>[];

  int lineOf(int offset) => '\n'.allMatches(text.substring(0, offset)).length + 1;

  void fix(int offset, String message, List<Edit> changes) {
    findings.add(Finding(path, lineOf(offset), message, fixable: true));
    for (final e in changes) {
      edits.putIfAbsent(e.start, () => e);
    }
  }

  void review(int offset, String message) => findings.add(Finding(path, lineOf(offset), message));

  String applied() {
    final sorted = edits.values.toList()..sort((a, b) => b.start.compareTo(a.start));
    var out = text;
    for (final e in sorted) {
      out = out.replaceRange(e.start, e.end, e.text);
    }
    return out;
  }
}

String _mask(String s) {
  final b = StringBuffer();
  var i = 0;
  while (i < s.length) {
    if (s.startsWith('//', i)) {
      final end = s.indexOf('\n', i);
      final stop = end == -1 ? s.length : end;
      b.write(' ' * (stop - i));
      i = stop;
    } else if (s.startsWith('/*', i)) {
      final end = s.indexOf('*/', i + 2);
      final stop = end == -1 ? s.length : end + 2;
      b.write(s.substring(i, stop).replaceAll(RegExp(r'[^\n]'), ' '));
      i = stop;
    } else if (s[i] == "'" || s[i] == '"') {
      final q = s.startsWith("'''", i) || s.startsWith('"""', i) ? s.substring(i, i + 3) : s[i];
      var j = i + q.length;
      while (j < s.length && !s.startsWith(q, j)) {
        if (s[j] == '\\') {
          j++;
        } else if (q.length == 1 && s[j] == '\n') {
          break;
        }
        j++;
      }
      final inner = j.clamp(0, s.length);
      b.write(q);
      b.write(s.substring(i + q.length, inner).replaceAll(RegExp(r'[^\n]'), ' '));
      if (inner < s.length && s.startsWith(q, inner)) {
        b.write(q);
        i = inner + q.length;
      } else {
        i = inner;
      }
    } else {
      b.write(s[i]);
      i++;
    }
  }
  return b.toString();
}

int _close(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return code.length - 1;
}

int _open(String code, int close) {
  var depth = 0;
  for (var i = close; i >= 0; i--) {
    final c = code[i];
    if (c == ')' || c == ']' || c == '}') depth++;
    if (c == '(' || c == '[' || c == '{') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return 0;
}

List<(String, int)> _topLevelKeys(String code, int open, int close) {
  final keys = <(String, int)>[];
  var depth = 0;
  final key = RegExp(r'([A-Za-z_]\w*)\s*:(?!:)');
  for (var i = open + 1; i < close; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') depth--;
    if (depth == 0 && RegExp(r'[A-Za-z_]').hasMatch(c) && (i == 0 || !RegExp(r'[\w.]').hasMatch(code[i - 1]))) {
      final m = key.matchAsPrefix(code, i);
      if (m != null) keys.add((m.group(1)!, i));
    }
  }
  return keys;
}

void _renameCall(Source src, String pattern, String newName, Map<String, String> keyMap) {
  for (final m in RegExp(pattern).allMatches(src.code)) {
    final open = m.end - 1;
    final close = _close(src.code, open);
    final hits = _topLevelKeys(src.code, open, close).where((k) => keyMap.containsKey(k.$1)).toList();
    if (hits.isEmpty) continue;
    final oldName = src.code.substring(m.start, open).trim();
    final before = hits.map((k) => '${k.$1}:').join(' ');
    final after = hits.map((k) => '${keyMap[k.$1]}:').join(' ');
    src.fix(m.start, '$oldName($before)  ->  $newName($after)', [
      Edit(m.start, open, newName),
      for (final k in hits) Edit(k.$2, k.$2 + k.$1.length, keyMap[k.$1]!),
    ]);
  }
}

void _layout(Source src) {
  _renameCall(src, r'\bEdgeInsets\.only\s*\(', 'EdgeInsetsDirectional.only', _sideKeys);
  _renameCall(src, r'(?<![\w.])Positioned\s*\(', 'PositionedDirectional', _sideKeys);
  _renameCall(src, r'(?<![\w.])AnimatedPositioned\s*\(', 'AnimatedPositionedDirectional', _sideKeys);
  _renameCall(src, r'\bBorderRadius\.only\s*\(', 'BorderRadiusDirectional.only', _cornerKeys);
  _renameCall(src, r'\bBorderRadius\.horizontal\s*\(', 'BorderRadiusDirectional.horizontal', _sideKeys);
  _renameCall(src, r'(?<![\w.])Border\s*\(', 'BorderDirectional', _sideKeys);

  for (final m in RegExp(r'\bEdgeInsets\.fromLTRB\b').allMatches(src.code)) {
    src.fix(m.start, 'EdgeInsets.fromLTRB  ->  EdgeInsetsDirectional.fromSTEB', [
      Edit(m.start, m.end, 'EdgeInsetsDirectional.fromSTEB'),
    ]);
  }

  for (final m in RegExp(
    r'\bAlignment\.(topLeft|centerLeft|bottomLeft|topRight|centerRight|bottomRight)\b',
  ).allMatches(src.code)) {
    final before = src.code.substring((m.start - 14).clamp(0, m.start), m.start);
    final to = 'AlignmentDirectional.${_alignments[m.group(1)]}';
    if (RegExp(r'\b(begin|end)\s*:\s*$').hasMatch(before)) {
      src.review(m.start, 'Gradient uses Alignment.${m.group(1)}. Use $to only if the gradient should mirror in RTL');
    } else {
      src.fix(m.start, 'Alignment.${m.group(1)}  ->  $to', [Edit(m.start, m.end, to)]);
    }
  }

  for (final m in RegExp(r'\bTextAlign\.(left|right)\b').allMatches(src.code)) {
    final to = m.group(1) == 'left' ? 'start' : 'end';
    src.fix(m.start, 'TextAlign.${m.group(1)}  ->  TextAlign.$to', [Edit(m.start, m.end, 'TextAlign.$to')]);
  }
}

void _icons(Source src) {
  for (final m in RegExp(r'\b(Image|SvgPicture)\.asset\s*\(').allMatches(src.code)) {
    final close = _close(src.code, m.end - 1);
    final args = src.text.substring(m.end, close);
    final name = RegExp(r'''['"]([^'"]+)['"]''').firstMatch(args)?.group(1);
    if (name == null || args.contains('matchTextDirection')) continue;
    final tokens = name.toLowerCase().split(RegExp(r'[^a-z]+')).toSet();
    if (tokens.intersection(_directionalTokens).isEmpty || tokens.intersection(_verticalTokens).isNotEmpty) continue;
    src.review(m.start, "Directional asset '$name' won't flip in RTL. Add matchTextDirection: true");
  }
}

void _text(Source src) {
  final plural = RegExp(r'''(['"])[^'"\n]*\$\{?[\w.]+\}?\s+[A-Za-z]+s\b[^'"\n]*\1''');
  for (final m in plural.allMatches(src.text)) {
    if (src.code.substring(m.start, m.start + 1).trim().isEmpty) continue;
    src.review(
      m.start,
      'Count glued to an English plural (${m.group(0)}). Arabic has 6 plural forms, move it to an ARB plural',
    );
  }
  for (final m in RegExp(r'''==\s*1\s*\?\s*['"]''').allMatches(src.code)) {
    src.review(m.start, 'Hand-made singular/plural switch. Use an ARB plural instead');
  }
  for (final m in RegExp(r'\b(TextField|TextFormField)\s*\(').allMatches(src.code)) {
    final close = _close(src.code, m.end - 1);
    final args = src.code.substring(m.end, close);
    if (args.contains('TextInputType.phone') && !args.contains('textDirection')) {
      src.review(
        m.start,
        'Phone field without textDirection. Add textDirection: TextDirection.ltr so digits stay in order',
      );
    }
  }
  for (final m in RegExp(r'''\bDateFormat\s*\(\s*['"][^'"]*['"]\s*\)''').allMatches(src.text)) {
    if (src.code[m.start].trim().isEmpty) continue;
    src.review(m.start, 'DateFormat without a locale. Pass the current locale so Arabic users get Arabic dates');
  }
  for (final m in RegExp(r'\]\s*\.reversed\b').allMatches(src.code)) {
    final open = _open(src.code, m.start);
    if (RegExp(r'children\s*:\s*$').hasMatch(src.code.substring((open - 20).clamp(0, open), open))) {
      src.review(
        open,
        'Children reversed by hand. Row and ListView already follow Directionality, this may flip it back',
      );
    }
  }
}

Iterable<File> _dartFiles(String root) sync* {
  final entity = FileSystemEntity.typeSync(root);
  if (entity == FileSystemEntityType.file) {
    yield File(root);
    return;
  }
  final files =
      Directory(root).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final name = f.path.split(Platform.pathSeparator).last;
    if (_skipSuffixes.any(name.endsWith) || name.startsWith('app_localizations')) continue;
    yield f;
  }
}

void main(List<String> args) {
  if (args.contains('-h') || args.contains('--help')) {
    stdout.write(_usage);
    return;
  }
  final fix = args.contains('--fix');
  final root = args.firstWhere((a) => !a.startsWith('--'), orElse: () => 'lib');
  if (FileSystemEntity.typeSync(root) == FileSystemEntityType.notFound) {
    stderr.writeln('No such path: $root');
    exitCode = 2;
    return;
  }

  final sources = <Source>[];
  for (final f in _dartFiles(root)) {
    final src = Source(f.path, f.readAsStringSync());
    _layout(src);
    _icons(src);
    _text(src);
    if (src.findings.isNotEmpty) sources.add(src);
  }

  final all = [for (final s in sources) ...s.findings]
    ..sort((a, b) => a.file == b.file ? a.line.compareTo(b.line) : a.file.compareTo(b.file));
  final fixable = all.where((f) => f.fixable).toList();
  final review = all.where((f) => !f.fixable).toList();

  stdout.writeln('Flutter RTL audit: $root');
  if (all.isEmpty) {
    stdout.writeln('No RTL problems found.');
    return;
  }
  stdout.writeln('${all.length} findings in ${sources.length} files, ${fixable.length} fixable automatically\n');

  void section(String title, List<Finding> items) {
    if (items.isEmpty) return;
    stdout.writeln(title);
    for (final f in items) {
      stdout.writeln('  ${f.file}:${f.line}  ${f.message}');
    }
    stdout.writeln();
  }

  section(fix ? 'Fixed' : 'Fixable with --fix', fixable);
  section('Needs a decision', review);

  if (fix) {
    for (final s in sources.where((s) => s.edits.isNotEmpty)) {
      File(s.path).writeAsStringSync(s.applied());
    }
    stdout.writeln(
      'Applied ${fixable.length} fixes. Run flutter analyze: a few APIs only accept EdgeInsets or BorderRadius, not the directional versions.',
    );
  } else {
    exitCode = 1;
  }
}
