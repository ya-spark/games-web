// Tests of the web state model (W6). build_game.sh copies this file into the app's test folder with the overlay.
import 'package:flutter_test/flutter_test.dart';

import '../lib/web_product/web_state_model.dart';

void main() {
  final topics = [
    const TopicRef('maths', 3, 'a', 'A'),
    const TopicRef('maths', 3, 'b', 'B'),
    const TopicRef('english', 3, 'c', 'C'),
  ];

  test('empty, broken or wrong-version input gives an empty state', () {
    for (final raw in [null, '', 'nope', '[]', '{"v":2,"year":3}']) {
      final s = WebState.parse(raw);
      expect(s.year, isNull);
      expect(s.topics, isEmpty);
    }
  });

  test('round trip keeps year, statuses, last and per game topics', () {
    final s = WebState(year: 3)
      ..setStatus('maths/3/a', TopicStatus.known)
      ..played('memory_match', 'maths/3/b');
    final t = WebState.parse(s.encode());
    expect(t.year, 3);
    expect(t.statusOf('maths/3/a'), TopicStatus.known);
    expect(t.statusOf('maths/3/b'), TopicStatus.practising);
    expect(t.lastGame, 'memory_match');
    expect(t.byGame['memory_match'], 'maths/3/b');
  });

  test('odd values are dropped and unknown ids are harmless', () {
    final s = WebState.parse('{"v":1,"year":99,"topics":{"x/1/y":"known","a":7},"byGame":{"g":3}}');
    expect(s.year, isNull);
    expect(s.topics.length, 1);
    expect(s.byGame, isEmpty);
    expect(defaultTopic(topics, s)!.id, 'a');
  });

  test('default topic is the first not known; all known gives null', () {
    final s = WebState(year: 3)..setStatus('maths/3/a', TopicStatus.known);
    expect(defaultTopic(topics, s)!.id, 'b');
    s
      ..setStatus('maths/3/b', TopicStatus.known)
      ..setStatus('english/3/c', TopicStatus.known);
    expect(defaultTopic(topics, s), isNull);
    expect(allKnown(topics, s), isTrue);
    s.setStatus('maths/3/b', TopicStatus.fresh);
    expect(allKnown(topics, s), isFalse);
  });

  test('a game reopens its last topic unless that is now known', () {
    final s = WebState(year: 3)..played('g', 'english/3/c');
    expect(defaultTopic(topics, s, game: 'g')!.id, 'c');
    s.setStatus('english/3/c', TopicStatus.known);
    expect(defaultTopic(topics, s, game: 'g')!.id, 'a');
  });

  test('next topic skips known ones and does not return the same', () {
    final s = WebState(year: 3)..setStatus('maths/3/b', TopicStatus.known);
    expect(nextTopic(topics, 'maths/3/a', s)!.id, 'c');
    s.setStatus('english/3/c', TopicStatus.known);
    expect(nextTopic(topics, 'maths/3/a', s), isNull);
  });

  test('position text and prove-it rule', () {
    expect(topicPosition(topics, 'maths/3/b'), 'Topic 2 of 3');
    expect(topicPosition(topics, 'nope'), isNull);
    expect(provedIt(4, 5), isTrue);
    expect(provedIt(5, 5), isTrue);
    expect(provedIt(3, 5), isFalse);
    expect(provedIt(2, 3), isTrue);
    expect(provedIt(1, 3), isFalse);
    expect(provedIt(1, 1), isFalse);
  });
}
