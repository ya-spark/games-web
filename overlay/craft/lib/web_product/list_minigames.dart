// Prints the app's minigame registry as JSON (id, title, access, item types, modes, years) so the catalog can list
// exactly the free minigames each Craft app really has. Used only by overlay/craft/test/web_minigames_test.dart at
// build time; never reached from main_web.dart, so it is not part of the web bundle.
import 'dart:convert';

import 'package:game_core/engine/engine.dart';

import '../ui/game_registry.dart';

/// [open] = every item the web build plays. B-13: for each game, the topic keys (subject/year/topic) with enough
/// questions the game can play (`canPlay` and `minPool`: the rule a round and the web shell use), by year.
String minigamesJson([List<PoolItem> open = const []]) {
  final games = <Map<String, Object?>>[];
  for (final e in appGames.entries) {
    final g = e.game;
    games.add({
      'id': g.id,
      'title': g.title,
      'access': g.access.name,
      'minPool': g.minPool,
      'itemTypes': [for (final t in g.itemTypes) t.name],
      'modes': [for (final m in (e.modes ?? g.modes)) m.name],
      'minYear': e.minYear,
      'maxYear': e.maxYear,
      'playable': _playable(g, open),
    });
  }
  return const JsonEncoder.withIndent(' ').convert({'games': games});
}

Map<String, List<String>> _playable(MiniGame g, List<PoolItem> open) {
  final counts = <String, int>{};
  for (final p in open) {
    if (g.canPlay(p)) {
      final k = '${p.subject}/${p.year}/${p.topic}';
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  final out = <String, List<String>>{};
  for (final e in counts.entries) {
    if (e.value < g.minPool) continue;
    out.putIfAbsent(e.key.split('/')[1], () => <String>[]).add(e.key);
  }
  for (final l in out.values) {
    l.sort();
  }
  return out;
}
