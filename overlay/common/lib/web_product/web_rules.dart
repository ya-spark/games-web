// Rules and tips for the web product (R1, web side). Shared by the Mind and Craft overlays: build_game.sh copies
// overlay/common on top of the app, then the family overlay. The first time a game is played in this browser the
// rules dialog opens by itself; afterwards a Rules button reopens it. The only thing remembered is one small flag per
// game in the browser (no progress, no account). The text is the apps' own (web_rules_data.dart, generated).
import 'package:flutter/material.dart';

import 'web_bar.dart';
import 'web_platform.dart';
import 'web_rules_data.dart';
import 'web_rules_model.dart';

/// The text for every game, by game id (generated: see web_rules_data.dart).
const Map<String, GameRules> webRules = webRulesData;

bool _seen(String id) => storageGet('rules-seen:$id') != null;

// A browser that blocks storage simply shows the rules every time.
void _markSeen(String id) => storageSet('rules-seen:$id', '1');

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

/// Wraps a game screen with a thin top bar: "All games" (back to the catalog), the [actions] of the build (game and
/// topic switching, Learn: see web_bar.dart) and "Rules". The first time this game is opened in this browser the
/// rules dialog opens by itself.
class RulesGate extends StatefulWidget {
  const RulesGate({super.key, required this.gameId, required this.child, this.actions = const [], this.autoOpen = true});
  final String gameId;

  /// Open the rules by themselves the first time (off while a screen other than the game is showing).
  final bool autoOpen;
  final Widget child;
  final List<Widget> actions;

  @override
  State<RulesGate> createState() => _RulesGateState();
}

class _RulesGateState extends State<RulesGate> {
  @override
  void initState() {
    super.initState();
    if (widget.autoOpen && webRules.containsKey(widget.gameId) && !_seen(widget.gameId)) {
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
              height: 44,
              child: Row(
                children: [
                  BarButton(
                    key: const Key('web.allGames'),
                    color: BarColors.allGames,
                    onPressed: () => navigateTo('../'),
                    icon: Icons.apps,
                    label: 'All games',
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('web.bar.actions'),
                      scrollDirection: Axis.horizontal,
                      child: Row(children: widget.actions),
                    ),
                  ),
                  if (has)
                    BarButton(
                      key: const Key('web.rules.button'),
                      color: BarColors.rules,
                      onPressed: () => showWebRules(context, widget.gameId),
                      icon: Icons.help_outline,
                      label: 'Rules',
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
