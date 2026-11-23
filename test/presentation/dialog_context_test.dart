import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Screens live in a nested navigator next to the desktop sidebar, while
/// dialogs open on the root navigator. A dialog whose builder ignores its own
/// context and pops with the screen's `context` closes the screen instead of the
/// dialog and leaves a blank pane — so every dialog must pop its own context.
void main() {
  test('no dialog builder pops the outer context', () {
    final offenders = <String>[];
    final call = RegExp(r'show(?:Dialog|ModalBottomSheet)\w*(?:<[^>]*>)?\(');
    final builder = RegExp(r'builder:\s*\((\w+)\)');
    final outerPop = RegExp(r'Navigator\.(?:pop\(context|of\(context\)\.pop)');

    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      for (final match in call.allMatches(source)) {
        final end = _closingParen(source, match.end - 1);
        if (end < 0) continue;
        final text = source.substring(match.start, end + 1);
        final b = builder.firstMatch(text);
        if (b == null || b.group(1) == 'context') continue;
        if (outerPop.hasMatch(text.substring(b.end))) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
          offenders.add('${file.path}:$line');
        }
      }
    }

    expect(offenders, isEmpty, reason: 'dialogs must pop their own builder context');
  });
}

int _closingParen(String s, int open) {
  var depth = 0;
  String? quote;
  for (var i = open; i < s.length; i++) {
    final c = s[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
    } else if (c == "'" || c == '"') {
      quote = c;
    } else if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}
