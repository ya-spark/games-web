// ignore_for_file: depend_on_referenced_packages
// The Craft web home (W6): the thin bar over the game, with year, game and topic switching, "I know this" and Learn.
// Kept apart from main_web.dart (which needs the browser) so it can be tested on the Dart VM.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../core/services.dart';
import 'package:game_core/engine/engine.dart';
import '../ui/game_registry.dart';
import '../ui/kit/ds_art.dart';
import '../ui/quick_quiz_screen.dart';
import 'web_bar.dart';
import 'web_catalog.dart';
import 'web_link.dart';
import 'web_platform.dart';
import 'web_rules.dart';
import 'web_state.dart';
import 'web_state_model.dart';

/// What the address asks for. `#/learn` with optional subject, year and topic is Learn (the Quick quiz now),
/// `#/play/<game>` with the same optional parts a minigame; the topic may be `all` (a mixed round). Missing parts
/// come from the saved state.
class WebLinkLaunch {
  const WebLinkLaunch({this.gameId, this.subject, this.year, this.topic});

  /// Nothing asked for: the saved state decides.
  static const WebLinkLaunch none = WebLinkLaunch();
  final String? gameId;
  final String? subject;
  final int? year;
  final String? topic;

  factory WebLinkLaunch.fromLink(WebLink l) {
    if (l.kind != 'learn' && l.kind != 'play') return WebLinkLaunch.none;
    final o = l.kind == 'play' ? 1 : 0;
    return WebLinkLaunch(
      gameId: l.kind == 'play' ? l.at(1) : null,
      subject: l.at(1 + o),
      year: int.tryParse(l.at(2 + o) ?? ''),
      topic: l.at(3 + o),
    );
  }
}

/// One round on screen: the game, its session and the topic it plays (null topic = a mixed round of [mixed]).
class _Round {
  _Round(this.game, this.session, this.topic, this.mixed, this.epoch);
  final MiniGame game;
  final QuizSession session;
  final TopicRef? topic;
  final String? mixed;
  final int epoch;
}

enum _Screen { playing, needYear, allDone, ended, empty, unsupported }

/// A game that has no questions for the chosen topic, and the games that do (proposed instead; never the Quick quiz).
class _Unsupported {
  const _Unsupported(this.game, this.topic, this.mixed, this.alternatives,
      [this.playable = const <TopicRef>[], this.otherYears = const <(int, TopicRef)>[]]);

  /// When the game plays no topic this year: each other year it does play, with the first topic it can run there.
  final List<(int, TopicRef)> otherYears;

  /// The topics of the same year this game can run (teaching order, Maths then English).
  final List<TopicRef> playable;
  final MiniGame game;
  final TopicRef? topic;
  final String? mixed;
  final List<MiniGame> alternatives;
}

/// The whole web home of a Craft build: the thin bar (year, game, topic, I know this, Learn, rules) over the game.
class CraftShell extends StatefulWidget {
  const CraftShell({
    super.key,
    required this.services,
    required this.packs,
    required this.open,
    required this.topics,
    required this.years,
    required this.year,
    required this.onYear,
    required this.launch,
    required this.state,
  });
  final Services services;
  final List<LoadedPack> packs;
  final List<PoolItem> open;
  final Topics? topics;
  final List<int> years;
  final int? year;
  final ValueChanged<int> onYear;
  final WebLinkLaunch launch;
  final WebState state;

  @override
  State<CraftShell> createState() => _CraftShellState();
}

class _CraftShellState extends State<CraftShell> {
  static const _quiz = 'quick_quiz';
  final String _slug = currentWebSlug();
  _Screen _screen = _Screen.playing;
  _Round? _round;
  _Unsupported? _unsupported;
  String _gameId = _quiz;
  int _epoch = 0;
  String? _message;

  /// Set by a year button on the unsupported screen: when the saved year changes, open this game on this topic
  /// (the first one the game can play in that year) instead of the default topic.
  (String, TopicRef)? _afterYear;

  @override
  void initState() {
    super.initState();
    final l = widget.launch;
    _gameId = l.gameId ?? _quiz;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final topics = widget.year == null ? const <TopicRef>[] : _topicsOf(widget.year!);
      TopicRef? t;
      String? mixed;
      if (l.topic == 'all' && l.subject != null) {
        mixed = l.subject;
      } else if (l.topic != null && l.subject != null) {
        t = _find(topics, l.subject!, l.topic!);
      }
      _begin(_gameId, topic: t, mixed: mixed);
    });
  }

  @override
  void didUpdateWidget(CraftShell old) {
    super.didUpdateWidget(old);
    if (old.year != widget.year) {
      final after = _afterYear;
      _afterYear = null;
      if (after != null && after.$2.year == widget.year) {
        _begin(after.$1, topic: after.$2);
      } else {
        _begin(_gameId);
      }
    }
  }

  TopicRef? _find(List<TopicRef> topics, String subject, String id) {
    for (final t in topics) {
      if (t.subject == subject && t.id == id) return t;
    }
    return null;
  }

  /// The topics of [year]: Maths then English (then any other subject), each in the teaching order of topics.yaml.
  List<TopicRef> _topicsOf(int year) {
    final subjects = {for (final p in widget.open) p.subject}.toList()
      ..sort((a, b) {
        int rank(String s) => s == 'maths' ? 0 : (s == 'english' ? 1 : 2);
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.compareTo(b);
      });
    final out = <TopicRef>[];
    for (final subject in subjects) {
      final ids = {
        for (final p in widget.open)
          if (p.subject == subject && p.year == year) p.topic,
      };
      final order = widget.topics?.orderFor(subject, year) ?? const <String>[];
      final listed = [...order.where(ids.contains), ...(ids.toList()..sort()).where((t) => !order.contains(t))];
      for (final id in listed) {
        out.add(TopicRef(subject, year, id, widget.topics?.displayName(subject, year, id) ?? _pretty(id)));
      }
    }
    return out;
  }

  final Map<String, List<TopicRef>> _gameTopicsCache = {};

  /// The topics of [year] that [gameId] can play (enough questions of its kinds: the same `minPool` rule a round
  /// uses), in teaching order. Learn (the Quick quiz) plays every topic. B-13: lists and "next topic" use this, so
  /// no topic is offered that would open an empty game.
  List<TopicRef> _gameTopics(String gameId, int year) {
    final all = _topicsOf(year);
    final game = _gameFor(gameId);
    if (game.id == quickQuizGame.id) return all;
    return _gameTopicsCache.putIfAbsent('${game.id}/$year', () {
      final counts = <String, int>{};
      for (final p in widget.open) {
        if (p.year == year && game.canPlay(p)) {
          final k = '${p.subject}/$year/${p.topic}';
          counts[k] = (counts[k] ?? 0) + 1;
        }
      }
      return [for (final t in all) if ((counts[t.key] ?? 0) >= game.minPool) t];
    });
  }

  String _subjectLabel(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// A topic id that topics.yaml does not name, shown as words: comparing_size -> Comparing size.
  String _pretty(String id) {
    final s = id.replaceAll('_', ' ');
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  /// The free minigame with this id, or the Quick quiz. A coin-locked game is never played on the web.
  MiniGame _gameFor(String? id) {
    if (id == null || id == quickQuizGame.id) return quickQuizGame;
    for (final e in appGames.entries) {
      if (e.game.id == id && e.game.access != GameAccess.coins) return e.game;
    }
    return quickQuizGame;
  }

  QuizSession? _session(MiniGame game, String subject, int year, String? topic, {int? count, int? minPool}) =>
      QuizSession.start(
        open: widget.open,
        progress: const ChildProgress(),
        packs: widget.packs,
        rewardsConfig: const RewardsConfig(weeklyCapPerChild: 0),
        subject: subject,
        year: year,
        today: 0,
        random: Random(),
        types: game.itemTypes,
        // The game's own limits (size class, value range, letter count): without them a round could start with
        // items the game then drops, an empty "0 of 0" round (B-13).
        accepts: game.id == quickQuizGame.id ? null : game.canPlay,
        topic: topic,
        count: count ?? 10,
        minPool: minPool ?? (game.id == quickQuizGame.id ? 1 : game.minPool),
        gameId: game.id,
      );

  /// Starts a round of [gameId]. With no [topic] the default is used (the last topic of this game, else the first
  /// topic of the year that is not known).
  void _begin(String gameId, {TopicRef? topic, String? mixed}) {
    final year = widget.year;
    if (year == null) {
      setState(() => _screen = _Screen.needYear);
      return;
    }
    final topics = _topicsOf(year);
    if (topics.isEmpty) {
      setState(() {
        _gameId = gameId;
        _screen = _Screen.empty;
        _message = 'There are no topics for ${yearLabel(year)} yet.';
      });
      return;
    }
    var t = topic;
    if (t == null && mixed == null) {
      final own = _gameTopics(gameId, year);
      // A game with no playable topic this year keeps the plain list: the no-questions screen then explains it.
      t = defaultTopic(own.isEmpty ? topics : own, widget.state, game: gameId);
      if (t == null) {
        setState(() {
          _gameId = gameId;
          _screen = _Screen.allDone;
        });
        return;
      }
    }
    var game = _gameFor(gameId);
    final subject = t?.subject ?? mixed!;
    var session = _session(game, subject, year, t?.id);
    if (session == null && game.id != quickQuizGame.id) {
      // No Quick quiz here: propose the games that can run this topic instead.
      final alts = <MiniGame>[
        for (final e in appGames.entries)
          if (e.game.access != GameAccess.coins &&
              e.game.id != quickQuizGame.id &&
              e.game.id != game.id &&
              e.modes?.contains(MiniGameMode.game) != false &&
              _session(e.game, subject, year, t?.id) != null)
            e.game,
      ];
      // And the topics of this year the game does play: the same check, applied per topic.
      final playable = [
        for (final o in topics)
          if (o.key != t?.key && _session(game, o.subject, year, o.id) != null) o,
      ];
      // None this year: the other years it does play, each with the first topic it can run there (same check).
      final otherYears = <(int, TopicRef)>[];
      if (playable.isEmpty) {
        for (final y in [...widget.years]..sort()) {
          if (y == year) continue;
          for (final o in _topicsOf(y)) {
            if (_session(game, o.subject, y, o.id) != null) {
              otherYears.add((y, o));
              break;
            }
          }
        }
      }
      setState(() {
        _gameId = gameId;
        _screen = _Screen.unsupported;
        _unsupported = _Unsupported(game, t, mixed, alts, playable, otherYears);
      });
      return;
    }
    if (session == null) {
      setState(() {
        _gameId = gameId;
        _screen = _Screen.empty;
        _message = 'There are no questions for this topic yet. Try another topic.';
      });
      return;
    }
    if (t != null) {
      widget.state.played(game.id, t.key);
      saveWebState(widget.state);
    }
    final id = t?.id ?? 'all';
    replaceHash(game.id == quickQuizGame.id ? '#/learn/$subject/$year/$id' : '#/play/${game.id}/$subject/$year/$id');
    setState(() {
      _gameId = game.id;
      _screen = _Screen.playing;
      _round = _Round(game, session, t, mixed, ++_epoch);
    });
  }

  TopicRef? get _current => _screen == _Screen.unsupported ? _unsupported?.topic : _round?.topic;

  void _toggleKnown(TopicRef t) {
    final s = widget.state;
    if (s.statusOf(t.key) == TopicStatus.known) {
      s.setStatus(t.key, TopicStatus.practising);
      saveWebState(s);
      setState(() {});
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('${t.title} is back to practising.')),
      );
      return;
    }
    _proveIt(t);
  }

  /// "I know this": five questions from the topic; four or more right marks it known and moves to the next topic.
  Future<void> _proveIt(TopicRef t) async {
    final year = widget.year;
    if (year == null) return;
    final session = _session(quickQuizGame, t.subject, year, t.id, count: 5, minPool: 3);
    final nav = Navigator.of(context);
    if (session == null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mark as known?'),
          content: Text('There are too few questions on ${t.title} for a check.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Not now')),
            FilledButton(key: const Key('web.known.confirm'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('I know this')),
          ],
        ),
      );
      if (ok == true) _finishProve(t, true);
      return;
    }
    final ready = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('web.prove.intro'),
        title: Text('Show you know ${t.title}'),
        content: Text('Answer ${session.items.length} questions. Get ${session.items.length - 1} or more right and this topic is marked as known.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Not now')),
          FilledButton(key: const Key('web.prove.start'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Start')),
        ],
      ),
    );
    if (ready != true || !mounted) return;
    final report = await nav.push<SessionReport>(
      MaterialPageRoute<SessionReport>(
        builder: (routeCtx) => Scaffold(
          body: SafeArea(
            child: quickQuizGame.build(
              MiniGameContext(
                session: session,
                mode: MiniGameMode.study,
                onAnswered: (r, s) {},
                onExit: () {
                  if (routeCtx.mounted) Navigator.of(routeCtx).pop(session.report);
                },
              ),
            ) as Widget,
          ),
        ),
      ),
    );
    if (!mounted) return;
    final asked = session.items.length;
    final right = report?.correct ?? 0;
    final passed = report != null && report.answered >= asked && provedIt(right, asked);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: Key(passed ? 'web.prove.passed' : 'web.prove.failed'),
        title: Text(passed ? 'You know this' : 'Not yet'),
        content: Text(passed
            ? '$right of $asked right. ${t.title} is marked as known.'
            : 'You got $right of $asked. Keep practising ${t.title} and try again when you are ready.'),
        actions: [FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
      ),
    );
    if (mounted) _finishProve(t, passed);
  }

  void _finishProve(TopicRef t, bool passed) {
    final s = widget.state;
    s.setStatus(t.key, passed ? TopicStatus.known : TopicStatus.practising);
    saveWebState(s);
    if (!passed) {
      setState(() {});
      return;
    }
    final topics = _gameTopics(_gameId, t.year);
    final next = nextTopic(topics, t.key, s);
    if (_current?.key == t.key || _round == null) {
      next == null ? setState(() => _screen = _Screen.allDone) : _begin(_gameId, topic: next);
    } else {
      setState(() {});
    }
  }

  List<Widget> _actions() {
    final year = widget.year;
    final topics = year == null ? const <TopicRef>[] : _gameTopics(_gameId, year);
    final cur = _current;
    final known = cur != null && widget.state.statusOf(cur.key) == TopicStatus.known;
    final fallback = [
      for (final e in appGames.entries)
        if (e.game.access != GameAccess.coins && e.game.id != quickQuizGame.id && e.modes?.contains(MiniGameMode.game) != false)
          CatalogGame(slug: _slug, gameId: e.game.id, title: e.game.title, from: widget.services.config.displayName, kind: 'craft'),
    ];
    return [
      CatalogGameMenu(
        currentSlug: _slug,
        currentGameId: _gameId,
        currentTitle: _gameId == _quiz ? 'Learn' : _gameFor(_gameId).title,
        fallback: fallback,
        year: year,
        topic: cur == null ? null : (subject: cur.subject, year: cur.year, topic: cur.id),
        onPickHere: (g) => _begin(g.gameId, topic: cur, mixed: _round?.mixed),
        onLearnHere: () => _begin(_quiz, topic: cur, mixed: _round?.mixed),
      ),
      YearButton(year: year, years: widget.years, onPick: widget.onYear),
      if (topics.isNotEmpty)
        TopicButton(
          topics: topics,
          state: widget.state,
          current: cur,
          label: cur?.title ?? (_round?.mixed != null ? 'All topics' : 'Topic'),
          onOpen: (t) => _begin(_gameId, topic: t),
          onToggleKnown: _toggleKnown,
        ),
      if (cur != null)
        BarButton(
          key: const Key('web.bar.known'),
          color: BarColors.known,
          onPressed: () => _toggleKnown(cur),
          icon: known ? Icons.check_circle : Icons.check_circle_outline,
          label: known ? 'Known (undo)' : 'I know this',
        ),
      BarButton(
        key: const Key('web.bar.learn'),
        color: BarColors.learn,
        onPressed: () => _begin(_quiz, topic: cur, mixed: _round?.mixed),
        icon: Icons.menu_book_outlined,
        label: 'Learn',
      ),
    ];
  }

  Widget _body() {
    final year = widget.year;
    switch (_screen) {
      case _Screen.needYear:
        return _Centered(
          title: 'Which year are you in?',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final y in widget.years)
                ChoiceChip(
                  key: Key('web.year.$y'),
                  label: Text(yearLabel(y)),
                  selected: false,
                  onSelected: (_) => widget.onYear(y),
                ),
            ],
          ),
        );
      case _Screen.allDone:
        final next = [for (final y in widget.years) if (year != null && y > year) y];
        return _Centered(
          title: 'All done in ${year == null ? 'this year' : yearLabel(year)}',
          text: 'You know every topic. Pick any topic to revisit it${next.isEmpty ? '.' : ', or move on.'}',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (next.isNotEmpty)
                FilledButton(
                  key: const Key('web.nextYear'),
                  onPressed: () => widget.onYear(next.first),
                  child: Text('Go to ${yearLabel(next.first)}'),
                ),
              OutlinedButton(
                key: const Key('web.revisit'),
                onPressed: () {
                  final topics = year == null ? const <TopicRef>[] : _gameTopics(_gameId, year);
                  if (topics.isNotEmpty) _begin(_gameId, topic: topics.first);
                },
                child: const Text('Start the year again'),
              ),
            ],
          ),
        );
      case _Screen.unsupported:
        return _unsupportedBody(_unsupported!, year);
      case _Screen.empty:
        return _Centered(title: 'Nothing to play here yet', text: _message);
      case _Screen.ended:
        final cur = _current;
        final topics = year == null ? const <TopicRef>[] : _gameTopics(_gameId, year);
        final known = cur != null && widget.state.statusOf(cur.key) == TopicStatus.known;
        return _Centered(
          title: 'Round finished',
          text: cur == null ? 'Nice work.' : 'Nice work on ${cur.title}.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton(
                key: const Key('web.again'),
                onPressed: () => _begin(_gameId, topic: cur, mixed: _round?.mixed),
                child: const Text('Play again'),
              ),
              if (cur != null && !known)
                OutlinedButton(key: const Key('web.endKnown'), onPressed: () => _proveIt(cur), child: const Text('I know this')),
              if (cur != null)
                OutlinedButton(
                  key: const Key('web.nextTopic'),
                  onPressed: () {
                    final n = nextTopic(topics, cur.key, widget.state);
                    n == null ? setState(() => _screen = _Screen.allDone) : _begin(_gameId, topic: n);
                  },
                  child: const Text('Next topic'),
                ),
            ],
          ),
        );
      case _Screen.playing:
        final r = _round;
        if (r == null) return const Center(child: CircularProgressIndicator());
        final isQuiz = r.game.id == quickQuizGame.id;
        return Column(
          children: [
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('round.${r.epoch}'),
                child: r.game.build(
                  MiniGameContext(
                    session: r.session,
                    mode: isQuiz ? MiniGameMode.study : MiniGameMode.game,
                    onAnswered: (res, sess) {},
                    onExit: () {
                      if (mounted && _round?.epoch == r.epoch) setState(() => _screen = _Screen.ended);
                    },
                  ),
                ) as Widget,
              ),
            ),
          ],
        );
    }
  }

  /// The screen for a game that cannot run the chosen topic. Order: what this game plays (topics of this year, or the
  /// years it does play), then the games that can run the topic. Compact so it fits a 1280x720 window without scrolling.
  Widget _unsupportedBody(_Unsupported u, int? year) {
    final theme = Theme.of(context);
    final yearName = year == null ? 'this year' : yearLabel(year);
    final noTopicsThisYear = u.playable.isEmpty;
    final noYearAtAll = noTopicsThisYear && u.otherYears.isEmpty;
    final String title;
    final String? text;
    if (!noTopicsThisYear) {
      title = '${u.game.title} has no questions for ${u.topic?.title ?? 'this topic'} yet';
      text = null;
    } else if (noYearAtAll) {
      title = 'This game has no questions yet';
      text = u.alternatives.isEmpty ? 'Try Learn instead.' : 'Try one of the games below.';
    } else {
      title = '${u.game.title} has no topics for $yearName';
      text = null;
    }
    Widget heading(String t, Key key) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Semantics(
            header: true,
            child: Text(t, key: key, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          ),
        );
    // One key per button, in the order on screen: 1 to 9, then 0, then a, b, c ...
    const keyNames = '1234567890abcdefghijklmnopqrstuvwxyz';
    final actions = <String, VoidCallback>{};
    String? nextKey(VoidCallback f) {
      if (actions.length >= keyNames.length) return null;
      final k = keyNames[actions.length];
      actions[k] = f;
      return k;
    }

    void pickYear((int, TopicRef) e) {
      _afterYear = (u.game.id, e.$2);
      widget.onYear(e.$1);
    }

    final sections = <Widget>[];
    if (!noTopicsThisYear) {
      sections.add(heading('This game plays these topics', const Key('web.supported.title')));
      sections.add(
        Semantics(
          role: SemanticsRole.list,
          child: Wrap(
            key: const Key('web.supported.list'),
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final o in u.playable)
                _ChoiceTile(
                  key: Key('web.supported.${o.subject}.${o.id}'),
                  label: o.title,
                  note: _subjectLabel(o.subject),
                  semantics: 'Play ${u.game.title} on ${o.title}, ${_subjectLabel(o.subject)}',
                  onTap: () => _begin(u.game.id, topic: o),
                  shortcut: nextKey(() => _begin(u.game.id, topic: o)),
                ),
            ],
          ),
        ),
      );
    } else if (!noYearAtAll) {
      sections.add(heading('It plays these years', const Key('web.years.title')));
      sections.add(
        Semantics(
          role: SemanticsRole.list,
          child: Wrap(
            key: const Key('web.years.list'),
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final e in u.otherYears)
                _ChoiceTile(
                  key: Key('web.years.${e.$1}'),
                  label: yearLabel(e.$1),
                  semantics: 'Play ${u.game.title} in ${yearLabel(e.$1)}, starting with ${e.$2.title}',
                  onTap: () => pickYear(e),
                  shortcut: nextKey(() => pickYear(e)),
                ),
            ],
          ),
        ),
      );
    }
    if (u.alternatives.isNotEmpty) {
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 14));
      sections.add(heading(
          'Try one of these games instead', const Key('web.alt.title')));
      sections.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final g in u.alternatives)
              _GameCard(
                key: Key('web.alt.${g.id}'),
                game: g,
                onTap: () => _begin(g.id, topic: u.topic, mixed: u.mixed),
                shortcut: nextKey(() => _begin(g.id, topic: u.topic, mixed: u.mixed)),
              ),
          ],
        ),
      );
    }
    if (actions.isNotEmpty) {
      sections.add(const SizedBox(height: 10));
      sections.add(Text('Press the key shown on a button, or Tab and Enter.',
          key: const Key('web.keys.hint'), style: theme.textTheme.bodySmall, textAlign: TextAlign.center));
    }
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isAltPressed) {
          return KeyEventResult.ignored;
        }
        final c = (event.character ?? event.logicalKey.keyLabel).toLowerCase();
        final f = actions[c];
        if (f == null) return KeyEventResult.ignored;
        f();
        return KeyEventResult.handled;
      },
      child: _Centered(
        title: title,
        text: text,
        compact: true,
        child: sections.isEmpty
            ? null
            : ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(mainAxisSize: MainAxisSize.min, children: sections),
              ),
      ),
    );
  }

  /// True while a game is on screen (the rules dialog may then open by itself).
  bool get _showing => _screen == _Screen.playing && _round != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('web.craftShell'),
      body: RulesGate(
        key: ValueKey('gate.$_gameId.$_showing'),
        gameId: _gameId,
        autoOpen: _showing,
        actions: _actions(),
        child: _body(),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.title, this.text, this.child, this.compact = false});
  final bool compact;
  final String title;
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(title,
                    style: compact ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
              ),
              if (text != null) ...[const SizedBox(height: 6), Text(text!, textAlign: TextAlign.center)],
              if (child != null) ...[SizedBox(height: compact ? 12 : 16), child!],
            ],
          ),
        ),
      );
}

/// A compact button for a topic or a year: at least 44 dp high, focusable (Tab, Enter, Space) with a visible focus ring.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile(
      {super.key, required this.label, required this.semantics, required this.onTap, this.note, this.shortcut});
  final String? shortcut;
  final String label;
  final String? note;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    return Semantics(
      role: SemanticsRole.listItem,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44, maxWidth: 300),
        child: Material(
          color: scheme.surfaceContainerHighest,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            focusColor: scheme.primary.withValues(alpha: 0.28),
            child: Semantics(
              button: true,
              link: true,
              label: semantics,
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (shortcut != null) ...[_KeyBadge(shortcut!), const SizedBox(width: 8)],
                    Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis)),
                    if (note != null) ...[
                      const SizedBox(width: 8),
                      Text(note!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A game as a card with its art and name, like the tiles on the home page (compact: 120 dp wide).
class _GameCard extends StatelessWidget {
  const _GameCard({super.key, required this.game, required this.onTap, this.shortcut});
  final String? shortcut;
  final MiniGame game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 120,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Semantics(
              button: true,
              label: 'Play ${game.title}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 64, child: DsGameArt(game.id)),
                    const SizedBox(height: 4),
                    if (shortcut != null) ...[_KeyBadge(shortcut!), const SizedBox(height: 2)],
                    Text(game.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// The key that does the same as a button, drawn on it (for example "1").
class _KeyBadge extends StatelessWidget {
  const _KeyBadge(this.keyName);
  final String keyName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: Key('web.shortcut.$keyName'),
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(keyName.toUpperCase(),
          textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
