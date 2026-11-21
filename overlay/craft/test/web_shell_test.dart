// Tests of the Craft web shell (W6): year gate, default topic, all-done screen, topic sheet and undo. build_game.sh
// copies this file into the app's test folder with the overlay and replaces APP_PKG with the app's package name
// (the three Craft apps have different ones).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:APP_PKG/core/services.dart';
import 'package:APP_PKG/engine/engine.dart';
import 'package:APP_PKG/ui/game_registry.dart';
import 'package:APP_PKG/ui/quick_quiz_screen.dart';
import 'package:APP_PKG/web_product/craft_shell.dart';
import 'package:APP_PKG/web_product/web_state_model.dart';
import 'helpers/fake_services.dart';

PoolItem _item(String id, String subject, int year, String topic) => PoolItem(
      item: ContentItem({
        'id': id,
        'type': 'mcq',
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

class _Harness extends StatefulWidget {
  const _Harness({required this.services, required this.state, this.year, this.launch = WebLinkLaunch.none});
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
    ];
    return ServicesScope(
      services: widget.services,
      child: MaterialApp(
        home: CraftShell(
          services: widget.services,
          packs: const [],
          open: open,
          topics: Topics.parse(_yaml),
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

Future<void> _pump(WidgetTester tester, WebState state, {int? year, WebLinkLaunch launch = WebLinkLaunch.none}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final s = await buildFakeServices(contentEnabled: true);
  await tester.pumpWidget(_Harness(services: s, state: state, year: year, launch: launch));
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
    expect(find.textContaining('has no questions for Alpha topic yet'), findsOneWidget);
    expect(find.byKey(const Key('web.note')), findsNothing);
    expect(find.byType(Card), findsWidgets); // the proposals are cards with art, like the home page
    expect(state.statusOf('maths/3/alpha'), TopicStatus.fresh); // nothing was played
  });

  testWidgets('the Game button shows "Game: <name>" for the game on screen', (tester) async {
    final state = WebState();
    await _pump(tester, state, year: 3);
    expect(find.byKey(const Key('web.bar.gameLabel')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('web.bar.gameName'))).data, ': Learn');
  });
}
