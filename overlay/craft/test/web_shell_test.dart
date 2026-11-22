// Tests of the Craft web shell (W6): year gate, default topic, all-done screen, topic sheet and undo. build_game.sh
// copies this file into the app's test folder with the overlay and replaces APP_PKG with the app's package name
// (the three Craft apps have different ones).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:APP_PKG/core/services.dart';
import 'package:game_core/engine/engine.dart';
import 'package:APP_PKG/ui/game_registry.dart';
import 'package:APP_PKG/ui/quick_quiz_screen.dart';
import 'package:APP_PKG/web_product/craft_shell.dart';
import 'package:APP_PKG/web_product/web_state_model.dart';
import 'helpers/fake_services.dart';

PoolItem _item(String id, String subject, int year, String topic, [String type = 'mcq']) => PoolItem(
      item: ContentItem({
        'id': id,
        'type': type,
        'seq': 1,
        'difficulty': 1,
        'explanation': 'e',
        'prompt': 'Question $id',
        'options': ['a', 'b'],
        'correct': 0,
      }),
      packId: 'pk',
      subject: subject,
      year: year,
      topic: topic,
    );

const _yaml = '''
maths:
  3:
    alpha: Alpha topic
    beta: Beta topic
  4:
    gamma: Gamma topic
''';

const _extraYaml = '''
english:
  3:
    zeta: Zeta topic
''';

class _Harness extends StatefulWidget {
  const _Harness({required this.services, required this.state, this.year, this.launch = WebLinkLaunch.none, this.extra = const []});
  final List<PoolItem> extra;
  final WebLinkLaunch launch;
  final Services services;
  final WebState state;
  final int? year;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late int? year = widget.year;
  @override
  Widget build(BuildContext context) {
    final open = [
      for (final t in ['alpha', 'beta'])
        for (var i = 0; i < 6; i++) _item('$t$i', 'maths', 3, t),
      for (var i = 0; i < 6; i++) _item('g$i', 'maths', 4, 'gamma'),
      ...widget.extra,
    ];
    return ServicesScope(
      services: widget.services,
      child: MaterialApp(
        home: CraftShell(
          services: widget.services,
          packs: const [],
          open: open,
          topics: Topics.parse(_yaml + (widget.extra.isEmpty ? '' : _extraYaml)),
          years: const [3, 4],
          year: year,
          onYear: (y) => setState(() => year = y),
          launch: widget.launch,
          state: widget.state,
        ),
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, WebState state,
    {int? year, WebLinkLaunch launch = WebLinkLaunch.none, List<PoolItem> extra = const [], Size size = const Size(900, 1400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = await buildFakeServices(contentEnabled: true);
  await tester.pumpWidget(_Harness(services: s, state: state, year: year, launch: launch, extra: extra));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('no year: asks once, then plays the first topic and marks it practising', (tester) async {
    final state = WebState();
    await _pump(tester, state);
    expect(find.byKey(const Key('web.year.3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('web.year.3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('web.year.3')), findsNothing);
    expect(state.statusOf('maths/3/alpha'), TopicStatus.practising);
    expect(find.text('Alpha topic'), findsWidgets); // the Topic button names the topic
  });

  testWidgets('default topic skips a known one', (tester) async {
    final state = WebState()..setStatus('maths/3/alpha', TopicStatus.known);
    await _pump(tester, state, year: 3);
    expect(state.statusOf('maths/3/beta'), TopicStatus.practising);
  });

  testWidgets('all topics known: all done, with a way to the next year', (tester) async {
    final state = WebState()
      ..setStatus('maths/3/alpha', TopicStatus.known)
      ..setStatus('maths/3/beta', TopicStatus.known);
    await _pump(tester, state, year: 3);
    expect(find.text('All done in Year 3'), findsOneWidget);
    await tester.tap(find.byKey(const Key('web.nextYear')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('All done in Year 3'), findsNothing);
    expect(state.statusOf('maths/4/gamma'), TopicStatus.practising);
  });

  testWidgets('topic sheet lists the topics; Undo moves a known topic back to practising', (tester) async {
    final state = WebState()..setStatus('maths/3/beta', TopicStatus.known);
    await _pump(tester, state, year: 3);
    await tester.tap(find.byKey(const Key('web.bar.topic')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('web.topic.alpha')), findsOneWidget);
    expect(find.byKey(const Key('web.topic.beta')), findsOneWidget);
    await tester.tap(find.byKey(const Key('web.known.beta')));
    await tester.pumpAndSettle();
    expect(state.statusOf('maths/3/beta'), TopicStatus.practising);
  });

  testWidgets('I know this opens the check before anything is marked known', (tester) async {
    final state = WebState();
    await _pump(tester, state, year: 3);
    await tester.ensureVisible(find.byKey(const Key('web.bar.known'))); // the bar scrolls sideways when it is full
    await tester.pump();
    await tester.tap(find.byKey(const Key('web.bar.known')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('web.prove.intro')), findsOneWidget);
    expect(state.statusOf('maths/3/alpha'), TopicStatus.practising);
  });

  testWidgets('a game with no questions for the topic proposes other games, not the Quick quiz', (tester) async {
    // The test topics hold only multiple-choice items, so a free game that does not play them cannot run.
    final blocked = appGames.entries.firstWhere((e) =>
        e.game.access != GameAccess.coins &&
        e.game.id != quickQuizGame.id &&
        !e.game.itemTypes.contains(ItemType.mcq));
    final state = WebState();
    await _pump(tester, state,
        year: 3, launch: WebLinkLaunch(gameId: blocked.game.id, subject: 'maths', year: 3, topic: 'alpha'));
    expect(find.text('This game has no questions yet'), findsOneWidget); // plays nothing in any year
    expect(find.byKey(const Key('web.note')), findsNothing);
    expect(find.byType(Card), findsWidgets); // the proposals are cards with art, like the home page
    expect(state.statusOf('maths/3/alpha'), TopicStatus.fresh); // nothing was played
  });

  testWidgets('the unsupported screen shows only the games when the game plays no topic of the year', (tester) async {
    // A game that plays only types the test topics lack cannot run alpha; it plays no topic here, so only the games show.
    final blocked = appGames.entries.firstWhere((e) =>
        e.game.access != GameAccess.coins &&
        e.game.id != quickQuizGame.id &&
        !e.game.itemTypes.contains(ItemType.mcq));
    final state = WebState();
    await _pump(tester, state,
        year: 3, launch: WebLinkLaunch(gameId: blocked.game.id, subject: 'maths', year: 3, topic: 'alpha'));
    expect(find.byKey(const Key('web.supported.title')), findsNothing);
    expect(find.byKey(const Key('web.supported.list')), findsNothing);
    // Nothing in any year: no year buttons, a plain message and the games below.
    expect(find.textContaining('has no topics for'), findsNothing);
    expect(find.text('This game has no questions yet'), findsOneWidget);
    expect(find.text('Try one of the games below.'), findsOneWidget);
    expect(find.byKey(const Key('web.years.title')), findsNothing);
    expect(find.byKey(const Key('web.years.4')), findsNothing);
  });

  testWidgets('the unsupported screen lists the playable topics of this year only, in order, and a tap opens the game on it',
      (tester) async {
    final blocked = appGames.entries.firstWhere((e) =>
        e.game.access != GameAccess.coins &&
        e.game.id != quickQuizGame.id &&
        !e.game.itemTypes.contains(ItemType.mcq));
    final type = blocked.game.itemTypes.first.name;
    // The game plays items of its own type: English (listed first on purpose) and a Maths topic of Year 3, and a Year 4 one.
    final extra = [
      for (var i = 0; i < 40; i++) _item('z$i', 'english', 3, 'zeta', type),
      for (var i = 0; i < 40; i++) _item('d$i', 'maths', 3, 'delta', type),
      for (var i = 0; i < 40; i++) _item('y$i', 'maths', 4, 'gamma', type),
    ];
    final state = WebState();
    await _pump(tester, state,
        year: 3,
        launch: WebLinkLaunch(gameId: blocked.game.id, subject: 'maths', year: 3, topic: 'alpha'),
        extra: extra);
    expect(find.textContaining('has no questions for Alpha topic yet'), findsOneWidget);
    expect(find.byKey(const Key('web.supported.title')), findsOneWidget);
    expect(find.text('This game plays these topics'), findsOneWidget);
    final delta = find.byKey(const Key('web.supported.maths.delta'));
    final zeta = find.byKey(const Key('web.supported.english.zeta'));
    expect(delta, findsOneWidget);
    expect(zeta, findsOneWidget);
    expect(find.byKey(const Key('web.supported.maths.alpha')), findsNothing); // the unsupported topic itself
    expect(find.byKey(const Key('web.supported.maths.beta')), findsNothing); // no items of the game's type
    expect(find.byKey(const Key('web.supported.maths.gamma')), findsNothing); // another year
    final dp = tester.getTopLeft(delta), zp = tester.getTopLeft(zeta);
    expect(dp.dy < zp.dy || (dp.dy == zp.dy && dp.dx < zp.dx), isTrue); // Maths then English
    expect(find.text('Maths'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    // Topics come first, the games row (with its label) after them.
    expect(tester.getTopLeft(find.byKey(const Key('web.supported.title'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('web.alt.title'))).dy));
    expect(find.text('Try one of these games instead'), findsOneWidget);
    expect(tester.getSize(delta).height, greaterThanOrEqualTo(44));
    // The rows are ListTiles (focusable, Enter and Space activate them, visible focus); a tap opens this game on the topic.
    await tester.ensureVisible(delta);
    await tester.tap(delta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.takeException(); // the game opens on the bare test items (no real fields), so its own build may complain
    expect(find.byKey(const Key('web.supported.title')), findsNothing);
    expect(state.statusOf('maths/3/delta'), TopicStatus.practising);
    expect(state.byGame[blocked.game.id], isNotNull);
  });

  testWidgets('the Game button shows "Game: <name>" for the game on screen', (tester) async {
    final state = WebState();
    await _pump(tester, state, year: 3);
    expect(find.byKey(const Key('web.bar.gameLabel')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('web.bar.gameName'))).data, ': Learn');
  });

  testWidgets('a game with no topic this year but one in another year: message, year buttons, a tap switches the year and opens its first topic',
      (tester) async {
    final blocked = appGames.entries.firstWhere((e) =>
        e.game.access != GameAccess.coins &&
        e.game.id != quickQuizGame.id &&
        !e.game.itemTypes.contains(ItemType.mcq));
    final type = blocked.game.itemTypes.first.name;
    // Only Year 4 has items of the game's type: it plays nothing in Year 3 (the Word grid / Year 7 case).
    final extra = [for (var i = 0; i < 40; i++) _item('y$i', 'maths', 4, 'gamma', type)];
    final state = WebState();
    await _pump(tester, state,
        year: 3,
        launch: WebLinkLaunch(gameId: blocked.game.id, subject: 'maths', year: 3, topic: 'alpha'),
        extra: extra);
    expect(find.text('${blocked.game.title} has no topics for Year 3'), findsOneWidget);
    expect(find.byKey(const Key('web.years.title')), findsOneWidget);
    expect(find.text('It plays these years'), findsOneWidget);
    expect(find.byKey(const Key('web.supported.title')), findsNothing);
    final y4 = find.byKey(const Key('web.years.4'));
    expect(y4, findsOneWidget);
    expect(find.byKey(const Key('web.years.3')), findsNothing); // this year is not offered
    expect(find.bySemanticsLabel(RegExp('Play .* in Year 4, starting with Gamma topic')), findsOneWidget);
    expect(tester.getSize(y4).height, greaterThanOrEqualTo(44));
    expect(find.byKey(const Key('web.shortcut.1')), findsWidgets); // the key is shown on the button
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1); // the first button: the only year
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.takeException();
    expect(find.byKey(const Key('web.years.title')), findsNothing);
    expect(state.statusOf('maths/4/gamma'), TopicStatus.practising);
    expect(state.byGame[blocked.game.id], isNotNull);
  });

  testWidgets('fits 1280x720 without scrolling: five topics and many games', (tester) async {
    final blocked = appGames.entries.firstWhere((e) =>
        e.game.access != GameAccess.coins &&
        e.game.id != quickQuizGame.id &&
        !e.game.itemTypes.contains(ItemType.mcq));
    final type = blocked.game.itemTypes.first.name;
    final extra = [
      for (final t in ['t1', 't2', 't3', 't4', 't5'])
        for (var i = 0; i < 40; i++) _item('$t$i', 'maths', 3, t, type),
    ];
    final state = WebState();
    await _pump(tester, state,
        year: 3,
        launch: WebLinkLaunch(gameId: blocked.game.id, subject: 'maths', year: 3, topic: 'alpha'),
        extra: extra,
        size: const Size(1280, 720));
    expect(find.byKey(const Key('web.supported.list')), findsOneWidget);
    final cards = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('web.alt.') && (w.key as ValueKey<String>).value != 'web.alt.title');
    expect(cards.evaluate().length, greaterThanOrEqualTo(5));
    final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    expect(vertical, findsOneWidget);
    expect(tester.state<ScrollableState>(vertical).position.maxScrollExtent, 0);
  });
}
