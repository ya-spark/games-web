// A deep link into a web build: the part after # in the address, split into segments.
//   /games/ember/#/game/sudoku              -> ['game', 'sudoku']
//   /games/scout/#/learn/maths/3/money      -> ['learn', 'maths', '3', 'money']   (Learn; `quiz` is the old name)
//   /games/scout/#/play/memory_match/maths/3/money -> ['play', 'memory_match', 'maths', '3', 'money']
// The catalog page builds these links; a build with no link (or one it does not know) shows its own list.
class WebLink {
  const WebLink(this.segments);
  final List<String> segments;

  static WebLink fromUri(Uri uri) {
    final f = uri.fragment;
    final parts = f.split('?').first.split('/').where((s) => s.isNotEmpty).toList();
    final segs = [for (final p in parts) Uri.decodeComponent(p)];
    if (segs.isNotEmpty && segs.first == 'quiz') segs[0] = 'learn'; // old links keep working
    // renamed game (owner, 2026-11-22): the old link opens the game under its new id
    if (segs.length > 1 && segs.first == 'play' && segs[1] == 'equation_builder') segs[1] = 'bridge_builder';
    return WebLink(segs);
  }

  bool get isEmpty => segments.isEmpty;
  String? get kind => segments.isEmpty ? null : segments.first;
  String? at(int i) => i < segments.length ? segments[i] : null;
}
