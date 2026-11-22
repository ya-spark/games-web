// Build-time helper (see lib/web_product/list_minigames.dart): writes minigames.json to $MINIGAMES_OUT, with the topics
// each game can play (B-13), counted over the same packs the web build plays (all of them open, empty progress).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/engine/engine.dart';

import '../lib/web_product/list_minigames.dart';

void main() {
  test('write the minigame list', () {
    final out = Platform.environment['MINIGAMES_OUT'];
    if (out == null || out.isEmpty) return;
    final dir = Directory('assets/content');
    final index = jsonDecode(File('${dir.path}/index.json').readAsStringSync()) as Map<String, dynamic>;
    final packs = <LoadedPack>[];
    for (final p in (index['packs'] as List).cast<Map<String, dynamic>>()) {
      if (p['product_id'] != null || (p['status'] ?? 'live') != 'live') continue;
      final f = File('${dir.path}/${(p['file'] as Map)['path']}');
      if (!f.existsSync()) continue;
      packs.add(LoadedPack(ContentPack(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>)));
    }
    final open = OpenItems.compute(packs, const ChildProgress(), fullUnlock: true);
    File(out).writeAsStringSync(minigamesJson(open));
  });
}
