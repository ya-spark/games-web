// The list of games across all the web builds, read from the site's catalog.json (written by scripts/make_catalog.py).
// A game build lives at <site>/<slug>/ and the catalog at <site>/catalog.json, so it is one level up (`../`). If it
// cannot be read the game menu shows only the games of this build.
import 'dart:convert';

import 'web_platform.dart';

class CatalogGame {
  const CatalogGame({
    required this.slug,
    required this.gameId,
    required this.title,
    required this.from,
    required this.kind,
    this.minYear = 0,
    this.maxYear = 12,
    this.playable,
  });

  final String slug;
  final String gameId;
  final String title;
  final String from;

  /// `craft` (learning minigames, take a year and topic) or `mind` (puzzles, no topic).
  final String kind;
  final int minYear;
  final int maxYear;

  bool get isCraft => kind == 'craft';

  /// B-13: topic keys this game can play (enough questions of its kinds), by year. Null = not known (an older
  /// catalog, or a game of this build's own list): the game is then treated as playable.
  final Map<int, List<String>>? playable;

  /// False only for a Craft game that is known to have no topic with enough questions in [year].
  bool playsIn(int? year) {
    final p = playable;
    if (!isCraft || p == null || year == null) return true;
    return (p[year] ?? const <String>[]).isNotEmpty;
  }
}

class CraftBand {
  const CraftBand(this.slug, this.title, this.minYear, this.maxYear);
  final String slug;
  final String title;
  final int minYear;
  final int maxYear;
}

class WebCatalog {
  const WebCatalog(this.games, this.bands);
  final List<CatalogGame> games;
  final List<CraftBand> bands;

  factory WebCatalog.fromJson(Object? j) {
    final games = <CatalogGame>[];
    final bands = <CraftBand>[];
    if (j is Map) {
      for (final b in (j['craft'] as List? ?? const [])) {
        if (b is Map && b['slug'] is String) {
          bands.add(CraftBand(b['slug'] as String, '${b['title']}', (b['minYear'] as num?)?.toInt() ?? 0,
              (b['maxYear'] as num?)?.toInt() ?? 12));
        }
      }
      for (final g in (j['games'] as List? ?? const [])) {
        if (g is Map && g['slug'] is String && g['gameId'] is String) {
          games.add(CatalogGame(
            slug: g['slug'] as String,
            gameId: g['gameId'] as String,
            title: '${g['title']}',
            from: '${g['from']}',
            kind: '${g['kind']}',
            minYear: (g['minYear'] as num?)?.toInt() ?? 0,
            maxYear: (g['maxYear'] as num?)?.toInt() ?? 12,
            playable: _readPlayable(g['playable']),
          ));
        }
      }
    }
    return WebCatalog(games, bands);
  }

  static Map<int, List<String>>? _readPlayable(Object? j) {
    if (j is! Map) return null;
    final out = <int, List<String>>{};
    for (final e in j.entries) {
      final y = int.tryParse('${e.key}');
      if (y != null && e.value is List) out[y] = [for (final t in e.value as List) '$t'];
    }
    return out;
  }

  /// Craft games first, the ones made for [year] before the others (nearest year band first), then the Mind games.
  /// A Craft game with nothing to play in [year] is left out (B-13), except the one on screen ([keepSlug], [keepGameId]).
  List<CatalogGame> sorted(int? year, {String? keepSlug, String? keepGameId}) {
    int distance(CatalogGame g) {
      if (year == null) return g.minYear;
      if (year < g.minYear) return g.minYear - year;
      if (year > g.maxYear) return year - g.maxYear;
      return 0;
    }

    final craft = [
      for (final g in games)
        if (g.isCraft && (g.playsIn(year) || (g.slug == keepSlug && g.gameId == keepGameId))) g,
    ];
    final mind = [for (final g in games) if (!g.isCraft) g];
    final order = {for (var i = 0; i < craft.length; i++) craft[i]: i};
    craft.sort((a, b) {
      final d = distance(a).compareTo(distance(b));
      return d != 0 ? d : order[a]!.compareTo(order[b]!);
    });
    return [...craft, ...mind];
  }

  /// The Craft build that Learn opens in for [year]: the band that holds it, else the nearest band.
  String? learnSlug(int? year) {
    if (bands.isEmpty) return null;
    final y = year ?? bands.first.minYear;
    CraftBand? best;
    var bestD = 1 << 30;
    for (final b in bands) {
      final d = y < b.minYear ? b.minYear - y : (y > b.maxYear ? y - b.maxYear : 0);
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    return best?.slug;
  }
}

Future<WebCatalog?> loadWebCatalog() async {
  try {
    final text = await fetchText('../catalog.json');
    return text == null ? null : WebCatalog.fromJson(jsonDecode(text));
  } on Object {
    return null;
  }
}

/// The address of a game in its own build, relative to the current build (`../<slug>/#/...`).
String webGameUrl(CatalogGame g, {String? subject, int? year, String? topic}) {
  final tail = (subject != null && year != null && topic != null) ? '/$subject/$year/$topic' : '';
  return g.isCraft ? '../${g.slug}/#/play/${g.gameId}$tail' : '../${g.slug}/#/game/${g.gameId}';
}

/// The address of Learn in the Craft build [slug].
String webLearnUrl(String slug, {String? subject, int? year, String? topic}) {
  final tail = (subject != null && year != null && topic != null) ? '/$subject/$year/$topic' : '';
  return '../$slug/#/learn$tail';
}
