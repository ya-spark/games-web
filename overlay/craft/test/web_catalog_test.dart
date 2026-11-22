// B-13: the catalog hides a Craft game that has nothing to play in the chosen year.
import 'package:flutter_test/flutter_test.dart';

import 'package:APP_PKG/web_product/web_catalog.dart';

void main() {
  final catalog = WebCatalog.fromJson({
    'games': [
      {
        'slug': 'scout', 'gameId': 'full', 'title': 'Full', 'from': 'S', 'kind': 'craft',
        'playable': {'3': ['maths/3/a'], '7': ['maths/7/b']},
      },
      {
        'slug': 'scout', 'gameId': 'y7only', 'title': 'Y7', 'from': 'S', 'kind': 'craft',
        'playable': {'7': ['maths/7/b']},
      },
      {'slug': 'scout', 'gameId': 'unknown', 'title': 'Unknown', 'from': 'S', 'kind': 'craft'},
      {'slug': 'ember', 'gameId': 'puzzle', 'title': 'Puzzle', 'from': 'E', 'kind': 'mind'},
    ],
  });
  List<String> ids(int? y, {String? keep}) =>
      [for (final g in catalog.sorted(y, keepSlug: 'scout', keepGameId: keep)) g.gameId];

  test('a year with no playable topic hides the card; no year, or no data, shows it', () {
    expect(ids(3), ['full', 'unknown', 'puzzle']);
    expect(ids(7), ['full', 'y7only', 'unknown', 'puzzle']);
    expect(ids(null), ['full', 'y7only', 'unknown', 'puzzle']);
  });

  test('the game on screen stays in the menu', () {
    expect(ids(3, keep: 'y7only'), ['full', 'y7only', 'unknown', 'puzzle']);
  });
}
