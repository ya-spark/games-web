import 'package:flutter_web_plugins/url_strategy.dart';

/// Stops Flutter from rewriting the address bar (it would turn `#/game/sudoku` into `#/` after a dialog closes, so a
/// reload would lose the link). Call once at the start of main(), before the link is read.
void keepAddressAsIs() => setUrlStrategy(null);

// A deep link into a web build: the part after # in the address, split into segments.
//   /games/ember/#/game/sudoku              -> ['game', 'sudoku']
//   /games/scout/#/quiz/maths/3/money       -> ['quiz', 'maths', '3', 'money']
// The catalog page builds these links; a build with no link (or one it does not know) shows its own list.
class WebLink {
  const WebLink(this.segments);
  final List<String> segments;

  static WebLink fromUri(Uri uri) {
    final f = uri.fragment;
    final parts = f.split('?').first.split('/').where((s) => s.isNotEmpty).toList();
    return WebLink([for (final p in parts) Uri.decodeComponent(p)]);
  }

  bool get isEmpty => segments.isEmpty;
  String? get kind => segments.isEmpty ? null : segments.first;
  String? at(int i) => i < segments.length ? segments[i] : null;
}
