// Build-time helper (see lib/web_product/list_minigames.dart): writes minigames.json to $MINIGAMES_OUT.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../lib/web_product/list_minigames.dart';

void main() {
  test('write the minigame list', () {
    final out = Platform.environment['MINIGAMES_OUT'];
    if (out == null || out.isEmpty) return;
    File(out).writeAsStringSync(minigamesJson());
  });
}
