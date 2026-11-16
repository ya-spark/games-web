// ignore_for_file: depend_on_referenced_packages
// Rules and tips for the web product (R1, web side). Shared by the Mind and Craft overlays: build_game.sh copies
// overlay/common on top of the app, then the family overlay. The first time a game is played in this browser the
// rules dialog opens by itself; afterwards a Rules button reopens it. The only thing remembered is one small flag per
// game in the browser (no progress, no account). The text is the apps' own (web_rules_data.dart, generated).
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'web_rules_data.dart';
import 'web_rules_model.dart';

/// The text for every game, by game id (generated: see web_rules_data.dart).
const Map<String, GameRules> webRules = webRulesData;

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
