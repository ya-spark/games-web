// ignore_for_file: depend_on_referenced_packages
// The Craft web home (W6): the thin bar over the game, with year, game and topic switching, "I know this" and Learn.
// Kept apart from main_web.dart (which needs the browser) so it can be tested on the Dart VM.
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/services.dart';
import '../engine/engine.dart';
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
  const _Unsupported(this.game, this.topic, this.mixed, this.alternatives);
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
    if (old.year != widget.year) _begin(_gameId);
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
      t = defaultTopic(topics, widget.state, game: gameId);
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
      setState(() {
        _gameId = gameId;
        _screen = _Screen.unsupported;
        _unsupported = _Unsupported(game, t, mixed, alts);
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
    final topics = _topicsOf(t.year);
    final next = nextTopic(topics, t.key, s);
    if (_current?.key == t.key || _round == null) {
      next == null ? setState(() => _screen = _Screen.allDone) : _begin(_gameId, topic: next);
    } else {
      setState(() {});
    }
  }

  List<Widget> _actions() {
    final year = widget.year;
    final topics = year == null ? const <TopicRef>[] : _topicsOf(year);
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
                  final topics = year == null ? const <TopicRef>[] : _topicsOf(year);
                  if (topics.isNotEmpty) _begin(_gameId, topic: topics.first);
                },
                child: const Text('Start the year again'),
              ),
            ],
          ),
        );
      case _Screen.unsupported:
        final u = _unsupported!;
        final topicName = u.topic?.title ?? 'this topic';
        return _Centered(
          title: '${u.game.title} has no questions for $topicName yet',
          text: u.alternatives.isEmpty ? 'Try another topic, or use Learn.' : 'Try one of these games instead:',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final g in u.alternatives)
                _GameCard(
                  key: Key('web.alt.${g.id}'),
                  game: g,
                  onTap: () => _begin(g.id, topic: u.topic, mixed: u.mixed),
                ),
            ],
          ),
        );
      case _Screen.empty:
        return _Centered(title: 'Nothing to play here yet', text: _message);
      case _Screen.ended:
        final cur = _current;
        final topics = year == null ? const <TopicRef>[] : _topicsOf(year);
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
  const _Centered({required this.title, this.text, this.child});
  final String title;
  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              if (text != null) ...[const SizedBox(height: 8), Text(text!, textAlign: TextAlign.center)],
              if (child != null) ...[const SizedBox(height: 16), child!],
            ],
          ),
        ),
      );
}

/// A game as a card with its art and name, like the tiles on the home page.
class _GameCard extends StatelessWidget {
  const _GameCard({super.key, required this.game, required this.onTap});
  final MiniGame game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Semantics(
              button: true,
              label: 'Play ${game.title}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 96, child: DsGameArt(game.id)),
                    const SizedBox(height: 8),
                    Text(game.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
