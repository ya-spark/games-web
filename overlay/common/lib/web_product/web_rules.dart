// ignore_for_file: depend_on_referenced_packages
// Rules and tips for the web product (R1, web side). Shared by the Mind and Craft overlays: build_game.sh copies
// overlay/common on top of the app, then the family overlay. The first time a game is played in this browser the
// rules dialog opens by itself; afterwards a Rules button reopens it. The only thing remembered is one small flag per
// game in the browser (no progress, no account). Text is short and plain on purpose; the owner reviews it.
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class GameRules {
  const GameRules(this.title, this.rules, this.tips);
  final String title;
  final List<String> rules;
  final List<String> tips;
}

const Map<String, GameRules> webRules = {
  'block_puzzle': GameRules('Block Puzzle', [
    'Drag one of the three pieces from the tray onto the 8 by 8 board.',
    'Fill a whole row or column to clear it. Rows and columns can clear together.',
    'When all three pieces are placed, a new tray of three arrives. The game ends when no piece fits.',
  ], [
    'Keep room for the big pieces.',
    'Look at all three pieces before you place the first one.',
    'Clear several lines in one go to score more.',
  ]),
  'blockfall': GameRules('Blockfall', [
    'Blocks fall into a 10 wide well. Move and turn each piece as it falls.',
    'Fill a whole row to clear it. Clear enough rows to reach the next level; blocks then fall faster.',
    'You can hold one piece for later and see the next ones coming. The game ends when the stack reaches the top.',
  ], [
    'Keep the surface flat.',
    'Hold a piece you will need soon.',
    'Only drop a piece fast when you are sure where it goes.',
  ]),
  'sudoku': GameRules('Sudoku', [
    'Fill the 9 by 9 grid so every row, every column and every 3 by 3 box has the digits 1 to 9 once.',
    'Tap a square, then tap a digit. Tap the same digit again to clear it. The digits you start with cannot change.',
    'Notes mode lets you pencil in small candidates.',
  ], [
    'Start with the digit that shows up most.',
    'Look for a square that can only be one digit.',
    'There is no timer, and Undo is unlimited.',
  ]),
  'solitaire': GameRules('Solitaire', [
    'Move every card up to the four foundations, building each suit from the ace to the king.',
    'In the seven columns, build down in alternating colours: a red 6 goes on a black 7. A face-up run moves together.',
    'Only a king, or a run that starts with a king, can go into an empty column. Tap the stock to turn over new cards.',
  ], [
    'Turn over the hidden cards early.',
    'Easier levels give more hints.',
    'There is no timer.',
  ]),
  'ball_sort': GameRules('Ball sort', [
    'Sort the balls so every tube holds just one colour.',
    'Tap a tube, then tap another tube to move the top balls across. They can go onto an empty tube or onto the same colour.',
    'Each tube holds 4 balls.',
  ], [
    'Keep an empty tube free for as long as you can.',
    'Undo is unlimited.',
    'You can add one extra tube on each level.',
  ]),
  'mahjong': GameRules('Mahjong solitaire', [
    'Take all the tiles off the board by matching pairs.',
    'A tile is free when nothing is on top of it and its left or right side is open.',
    'Tap two free tiles that match to remove them.',
  ], [
    'Prefer pairs that free tiles in tall stacks.',
    'Hints and shuffles cost points.',
    'There is no timer.',
  ]),
  'merge': GameRules('Merge', [
    'Swipe, or use the arrow buttons, to slide all the plants across the 4 by 4 board.',
    'When two plants of the same stage meet, they grow into the next stage.',
    'After every move a new seedling appears. In Classic the game ends when no move is left; Relaxed never ends.',
  ], [
    'Keep your biggest plant in a corner.',
    'Plan two moves ahead.',
    'Undo takes back your last move.',
  ]),
  'wingy': GameRules('Wingy', [
    'Tap to flap and fly the moth through the gaps between the crystal spires.',
    'Gravity pulls you down all the time, so keep tapping.',
    'Every spire you pass scores a point.',
  ], [
    'Aim for the middle of each gap.',
    'Look at the height of the next gap before you reach it.',
    'Short, steady taps work better than lots of fast ones.',
  ]),
  'snake': GameRules('Snake', [
    'Swipe, or use the arrow buttons, to steer the snake.',
    'Eat the food to grow longer. Each one is worth 10 points.',
    'The game ends when you hit a wall or yourself, unless Walls wrap round is switched on.',
  ], [
    'Plan your turns early.',
    'You can line up two turns in a row.',
    'Staying near the middle gives you more room.',
  ]),
  'bricks': GameRules('Brick breaker', [
    'Drag to move the paddle, or use the left and right buttons. Tap to launch the ball.',
    'Break every brick to clear the level. You have 3 lives; a ball that drops past the paddle costs one.',
    'Some bricks drop power-ups. Catch them with the paddle.',
  ], [
    'Where the ball hits the paddle changes its angle.',
    'A wide paddle or a slow ball helps for a while.',
    'The ball gets faster on later levels.',
  ]),
  'stack': GameRules('Stack tower', [
    'Tap, or press Drop, to drop the sliding block onto the tower.',
    'Only the part that sits on the block below stays. The overhang is cut off, so the tower gets narrower.',
    'If a block misses the tower completely, the game is over.',
  ], [
    'Drop right on top of the block below for a perfect drop. It keeps the full width and builds a streak.',
    'Watch the edge of the block, not the middle.',
    'The blocks speed up as the tower grows.',
  ]),
  'runner': GameRules('Runner', [
    'Tap anywhere on the track, or press Jump, to jump. You run by yourself and get faster.',
    'Jump over the gaps in the ground and over the blocks.',
    'The game ends when you hit a block or fall into a gap. The distance you run is your score.',
  ], [
    'Time the jump so the top of the arc is over the middle of the obstacle.',
    'There is no double jump.',
    'Wait for the right moment instead of jumping early.',
  ]),
  'memory_match': GameRules('Memory match', [
    'Flip two cards at a time to find the matching pairs. Each pair is a question and its answer.',
    'Match every pair to finish the board.',
  ], [
    'Try to remember where each card is.',
    'Younger levels have no timer. Older levels add a gentle clock.',
  ]),
  'sort_bins': GameRules('Sort into bins', [
    'Put each item into the right bin. Drag it there, or tap the item and then the bin.',
    'A wrong drop never ends the round. The item stays and you try again.',
  ], [
    'Read the names of the bins first.',
    'Take your time. Every item gets as many tries as it needs.',
  ]),
  'series_builder': GameRules('Series builder', [
    'Put the steps in the right order by tapping the tiles one after the other.',
    'A wrong tile is greyed out and you try again.',
  ], [
    'Find the first step before you start tapping.',
    'Older levels add a gentle timer.',
  ]),
  'word_builder': GameRules('Word builder', [
    'Build the answer from the letter tiles. Use the hint if you need it.',
    'After a miss, the correct spelling is shown.',
  ], [
    'Say the word to yourself as you build it.',
    'Older levels build the word and press Check.',
  ]),
  'true_false': GameRules('True or false', [
    'Read each statement, then choose True or False.',
  ], [
    'Read the whole statement before you answer.',
    'Look for words like always, never and only.',
  ]),
  'cloze_fix': GameRules('Cloze and grammar fix', [
    'Choose the word that fills the gap, or the corrected sentence.',
  ], [
    'Read the sentence out loud in your head with each choice.',
    'Check the whole sentence, not just the gap.',
  ]),
  'equation_builder': GameRules('Equation builder', [
    'Build a sum from the tiles so that it equals the target number.',
    'Any sum that works is a right answer.',
  ], [
    'Start with the biggest tile that fits.',
    'Try different tiles if you get stuck.',
  ]),
  'word_grid': GameRules('Word search and crossword', [
    'Choose word search or crossword on the start screen.',
    'Find the words in the grid, or fill in the crossword from the clues.',
  ], [
    'Start with the words you know best.',
    'There is no need to hurry.',
  ]),
  'balloon_pop': GameRules('Balloon pop', [
    'Read the question, then pop the balloon with the right answer.',
  ], [
    'Read every balloon before you pop one.',
    'Take a moment if the question is tricky.',
  ]),
  'door_runner': GameRules('Door runner', [
    'Read the question, then run through the door with the right answer.',
  ], [
    'Read every door before you choose.',
    'Take a moment if the question is tricky.',
  ]),
  'quick_quiz': GameRules('Quick quiz', [
    'Answer the questions one by one.',
    'Pick a topic to practise one thing, or play a mixed round.',
  ], [
    'Take your time. There is no rush to answer.',
    'Read every answer before you choose.',
    'Play the same topic again to get better at it.',
  ]),
};

bool _seen(String id) {
  try {
    return web.window.localStorage.getItem('rules-seen:$id') != null;
  } on Object {
    return false;
  }
}

void _markSeen(String id) {
  try {
    web.window.localStorage.setItem('rules-seen:$id', '1');
  } on Object {
    // A browser that blocks storage simply shows the rules every time.
  }
}

/// Opens the rules dialog for [gameId]. Does nothing for an id without rules text.
Future<void> showWebRules(BuildContext context, String gameId) {
  final rules = webRules[gameId];
  if (rules == null) return Future<void>.value();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('web.rules.dialog'),
      title: Text('How to play ${rules.title}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in rules.rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(r),
              ),
            if (rules.tips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Tips', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final t in rules.tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $t'),
                ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          key: const Key('web.rules.gotIt'),
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

/// Wraps a game screen with a thin top bar: "All games" (back to the catalog) and "Rules". The first time this
/// game is opened in this browser the rules dialog opens by itself.
class RulesGate extends StatefulWidget {
  const RulesGate({super.key, required this.gameId, required this.child});
  final String gameId;
  final Widget child;

  @override
  State<RulesGate> createState() => _RulesGateState();
}

class _RulesGateState extends State<RulesGate> {
  @override
  void initState() {
    super.initState();
    if (webRules.containsKey(widget.gameId) && !_seen(widget.gameId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _markSeen(widget.gameId);
        await showWebRules(context, widget.gameId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = webRules.containsKey(widget.gameId);
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  TextButton.icon(
                    key: const Key('web.allGames'),
                    onPressed: () => web.window.location.href = '../',
                    icon: const Icon(Icons.apps, size: 18),
                    label: const Text('All games'),
                  ),
                  const Spacer(),
                  if (has)
                    TextButton.icon(
                      key: const Key('web.rules.button'),
                      onPressed: () => showWebRules(context, widget.gameId),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('Rules'),
                    ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
