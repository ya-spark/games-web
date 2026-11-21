// Prints the app's minigame registry as JSON (id, title, access, item types, modes, years) so the catalog can list
// exactly the free minigames each Craft app really has. Used only by overlay/craft/test/web_minigames_test.dart at
// build time; never reached from main_web.dart, so it is not part of the web bundle.
import 'dart:convert';

import '../ui/game_registry.dart';

String minigamesJson() {
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
    });
  }
  return const JsonEncoder.withIndent(' ').convert({'games': games});
}
