// What the web product remembers in the browser (W6). Pure Dart (no browser imports) so it can be unit tested; the
// browser read and write is in web_state.dart. The same JSON is read and written by site/progress.js on the landing
// page, so keep the two in step:
//   {"v":1,"year":3,"topics":{"maths/3/money":"known","english/3/spelling":"practising"},
//    "last":{"game":"memory_match","topic":"maths/3/money"},"byGame":{"memory_match":"maths/3/money"}}
// Every read is tolerant: bad JSON, a wrong version or an odd value gives an empty state, never an error, and topic
// ids that a build does not know are simply never looked up.
import 'dart:convert';

enum TopicStatus { fresh, practising, known }

String topicKey(String subject, int year, String topic) => '$subject/$year/$topic';

/// A topic of the active year, in teaching order.
class TopicRef {
  const TopicRef(this.subject, this.year, this.id, this.title);
  final String subject;
  final int year;
  final String id;
  final String title;
  String get key => topicKey(subject, year, id);
}

class WebState {
  WebState({
    this.year,
    Map<String, TopicStatus>? topics,
    Map<String, String>? byGame,
    this.lastGame,
    this.lastTopic,
  })  : topics = topics ?? <String, TopicStatus>{},
        byGame = byGame ?? <String, String>{};

  static const int version = 1;
  static const String storageKey = 'amc.state';

  /// The active year (0 = Foundation, 1 to 12), or null until the person has chosen one.
  int? year;
  final Map<String, TopicStatus> topics;

  /// The last topic key played in each game, by game id.
  final Map<String, String> byGame;
  String? lastGame;
  String? lastTopic;

  factory WebState.parse(String? raw) {
    if (raw == null || raw.isEmpty) return WebState();
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['v'] != version) return WebState();
      final s = WebState();
      final y = j['year'];
      if (y is int && y >= 0 && y <= 12) s.year = y;
      final t = j['topics'];
      if (t is Map) {
        t.forEach((k, v) {
          if (k is String && v == 'known') s.topics[k] = TopicStatus.known;
          if (k is String && v == 'practising') s.topics[k] = TopicStatus.practising;
        });
      }
      final b = j['byGame'];
      if (b is Map) {
        b.forEach((k, v) {
          if (k is String && v is String) s.byGame[k] = v;
        });
      }
      final l = j['last'];
      if (l is Map) {
        if (l['game'] is String) s.lastGame = l['game'] as String;
        if (l['topic'] is String) s.lastTopic = l['topic'] as String;
      }
      return s;
    } on Object {
      return WebState();
    }
  }

  String encode() => jsonEncode({
        'v': version,
        if (year != null) 'year': year,
        'topics': {
          for (final e in topics.entries)
            if (e.value != TopicStatus.fresh) e.key: e.value.name,
        },
        if (lastGame != null || lastTopic != null)
          'last': {
            if (lastGame != null) 'game': lastGame,
            if (lastTopic != null) 'topic': lastTopic,
          },
        'byGame': byGame,
      });

  TopicStatus statusOf(String key) => topics[key] ?? TopicStatus.fresh;

  void setStatus(String key, TopicStatus status) {
    if (status == TopicStatus.fresh) {
      topics.remove(key);
    } else {
      topics[key] = status;
    }
  }

  /// Records that [topic] was opened in [game]: it becomes `practising` unless it is already `known`.
  void played(String game, String topic) {
    lastGame = game;
    lastTopic = topic;
    byGame[game] = topic;
    if (statusOf(topic) == TopicStatus.fresh) topics[topic] = TopicStatus.practising;
  }
}

/// The topic to open when none is asked for: the one this game was last played with if it is still listed and not
/// known, else the first topic that is not known. Null when every topic is known (or there are none).
TopicRef? defaultTopic(List<TopicRef> ordered, WebState s, {String? game}) {
  final byKey = {for (final t in ordered) t.key: t};
  final mine = game == null ? null : byKey[s.byGame[game]];
  if (mine != null && s.statusOf(mine.key) != TopicStatus.known) return mine;
  for (final t in ordered) {
    if (s.statusOf(t.key) != TopicStatus.known) return t;
  }
  return null;
}

/// The next topic after [key] that is not known, or null when there is none after it (it wraps to the start).
TopicRef? nextTopic(List<TopicRef> ordered, String key, WebState s) {
  final i = ordered.indexWhere((t) => t.key == key);
  for (var n = 1; n <= ordered.length; n++) {
    final t = ordered[(i + n) % ordered.length];
    if (t.key != key && s.statusOf(t.key) != TopicStatus.known) return t;
  }
  return null;
}

bool allKnown(List<TopicRef> ordered, WebState s) =>
    ordered.isNotEmpty && ordered.every((t) => s.statusOf(t.key) == TopicStatus.known);

/// "Topic 3 of 12": the 1-based position of [key] in [ordered], or null if it is not listed.
String? topicPosition(List<TopicRef> ordered, String? key) {
  final i = ordered.indexWhere((t) => t.key == key);
  return i < 0 ? null : 'Topic ${i + 1} of ${ordered.length}';
}

/// The prove-it check: [correct] answers out of [asked]. Passes with all but one right (4 of 5), and needs a round of
/// at least 3 questions (a topic with fewer cannot be proved, the caller marks it known directly).
bool provedIt(int correct, int asked) => asked >= 3 && correct >= asked - 1;
