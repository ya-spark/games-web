// The controls of the thin top bar (W6): Year, Game, Topic, I know this and Learn. They are plain Material widgets so
// the Craft and Mind shells can both use them (the Mind shell shows only the Game menu). All state is passed in; the
// shells decide what a choice does.
import 'package:flutter/material.dart';

import 'web_catalog.dart';
import 'web_platform.dart';
import 'web_state_model.dart';

String yearLabel(int y) => y == 0 ? 'Foundation' : 'Year $y';

/// Year chip: shows the active year, opens a picker with every year that has content.
class YearButton extends StatelessWidget {
  const YearButton({super.key, required this.year, required this.years, required this.onPick});
  final int? year;
  final List<int> years;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        key: const Key('web.bar.year'),
        onPressed: () async {
          final y = await showYearDialog(context, years, year);
          if (y != null) onPick(y);
        },
        icon: const Icon(Icons.school_outlined, size: 18),
        label: Text(year == null ? 'Choose year' : yearLabel(year!)),
      );
}

Future<int?> showYearDialog(BuildContext context, List<int> years, int? current, {bool dismissible = true}) =>
    showDialog<int>(
      context: context,
      barrierDismissible: dismissible,
      builder: (ctx) => AlertDialog(
        key: const Key('web.yearDialog'),
        title: const Text('Which year are you in?'),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final y in years)
                ChoiceChip(
                  key: Key('web.year.$y'),
                  label: Text(yearLabel(y)),
                  selected: y == current,
                  onSelected: (_) => Navigator.of(ctx).pop(y),
                ),
            ],
          ),
        ),
      ),
    );

/// Game menu: Learn, then every game (Craft games for the year first, Mind games last). A choice calls [onPick] or
/// [onLearn]; the shell either switches in place (same build) or opens the other build.
class GameMenuButton extends StatelessWidget {
  const GameMenuButton({
    super.key,
    required this.catalog,
    required this.year,
    required this.currentSlug,
    required this.currentGameId,
    required this.onPick,
    this.onLearn,
  });
  final WebCatalog catalog;
  final int? year;
  final String currentSlug;
  final String currentGameId;
  final ValueChanged<CatalogGame> onPick;
  final VoidCallback? onLearn;

  @override
  Widget build(BuildContext context) {
    final games = catalog.sorted(year);
    final firstMind = games.indexWhere((g) => !g.isCraft);
    return PopupMenuButton<Object>(
      key: const Key('web.bar.game'),
      tooltip: 'Switch game',
      onSelected: (v) {
        if (v is CatalogGame) onPick(v);
        if (v == 'learn') onLearn?.call();
      },
      itemBuilder: (_) => [
        if (onLearn != null)
          const PopupMenuItem<Object>(value: 'learn', child: ListTile(leading: Icon(Icons.menu_book_outlined), title: Text('Learn'), dense: true)),
        for (var i = 0; i < games.length; i++) ...[
          if (i == firstMind) const PopupMenuDivider(),
          PopupMenuItem<Object>(
            value: games[i],
            enabled: !(games[i].slug == currentSlug && games[i].gameId == currentGameId),
            child: ListTile(
              dense: true,
              title: Text(games[i].title),
              subtitle: Text(games[i].isCraft ? games[i].from : 'Puzzle, ${games[i].from}'),
              selected: games[i].slug == currentSlug && games[i].gameId == currentGameId,
            ),
          ),
        ],
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sports_esports_outlined, size: 18),
          SizedBox(width: 6),
          Text('Game'),
          Icon(Icons.arrow_drop_down, size: 18),
        ]),
      ),
    );
  }
}

/// Topic button: opens a sheet with the year's topics and their state. Tapping a topic opens it; the check button
/// starts the "prove it" check (or undoes `known`).
class TopicButton extends StatelessWidget {
  const TopicButton({
    super.key,
    required this.topics,
    required this.state,
    required this.current,
    required this.onOpen,
    required this.onToggleKnown,
    this.label,
  });
  final List<TopicRef> topics;
  final WebState state;
  final TopicRef? current;
  final ValueChanged<TopicRef> onOpen;
  final ValueChanged<TopicRef> onToggleKnown;
  final String? label;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        key: const Key('web.bar.topic'),
        onPressed: topics.isEmpty
            ? null
            : () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (ctx) => TopicSheet(
                    topics: topics,
                    state: state,
                    current: current,
                    onOpen: (t) {
                      Navigator.of(ctx).pop();
                      onOpen(t);
                    },
                    onToggleKnown: (t) {
                      Navigator.of(ctx).pop();
                      onToggleKnown(t);
                    },
                  ),
                ),
        icon: const Icon(Icons.list_alt, size: 18),
        label: Text(label ?? current?.title ?? 'Topic'),
      );
}

class TopicSheet extends StatelessWidget {
  const TopicSheet({
    super.key,
    required this.topics,
    required this.state,
    required this.current,
    required this.onOpen,
    required this.onToggleKnown,
  });
  final List<TopicRef> topics;
  final WebState state;
  final TopicRef? current;
  final ValueChanged<TopicRef> onOpen;
  final ValueChanged<TopicRef> onToggleKnown;

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    String? subject;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: ListView(
          key: const Key('web.topicSheet'),
          children: [
            for (var i = 0; i < topics.length; i++) ...[
              if (topics[i].subject != subject)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(_cap(subject = topics[i].subject), style: Theme.of(context).textTheme.titleSmall),
                ),
              _row(context, topics[i], i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, TopicRef t, int i) {
    final status = state.statusOf(t.key);
    final known = status == TopicStatus.known;
    return ListTile(
      key: Key('web.topic.${t.id}'),
      selected: t.key == current?.key,
      leading: Icon(known
          ? Icons.check_circle
          : status == TopicStatus.practising
              ? Icons.timelapse
              : Icons.radio_button_unchecked),
      title: Text(t.title),
      subtitle: Text(known
          ? 'You know this'
          : status == TopicStatus.practising
              ? 'Practising'
              : 'New'),
      trailing: TextButton(
        key: Key('web.known.${t.id}'),
        onPressed: () => onToggleKnown(t),
        child: Text(known ? 'Undo' : 'I know this'),
      ),
      onTap: () => onOpen(t),
    );
  }
}

/// The game menu with its own catalog loading: shows the games of this build at once and all games when the catalog
/// has loaded. [onPickHere] handles a game of this same build (switch in place); every other game opens its own page.
class CatalogGameMenu extends StatefulWidget {
  const CatalogGameMenu({
    super.key,
    required this.currentSlug,
    required this.currentGameId,
    required this.fallback,
    required this.year,
    required this.onPickHere,
    this.onLearnHere,
    this.topic,
  });
  final String currentSlug;
  final String currentGameId;

  /// The games of this build, used until (or if) the catalog cannot be read.
  final List<CatalogGame> fallback;
  final int? year;
  final ValueChanged<CatalogGame> onPickHere;

  /// Opens Learn in this build (Craft). Null in a Mind build: Learn then opens in the Craft build for the year.
  final VoidCallback? onLearnHere;

  /// The current topic (`subject`, `year`, `topic`), carried to another Craft game.
  final ({String subject, int year, String topic})? topic;

  @override
  State<CatalogGameMenu> createState() => _CatalogGameMenuState();
}

class _CatalogGameMenuState extends State<CatalogGameMenu> {
  WebCatalog? _catalog;

  @override
  void initState() {
    super.initState();
    loadWebCatalog().then((c) {
      if (mounted && c != null) setState(() => _catalog = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog ?? WebCatalog(widget.fallback, const []);
    final t = widget.topic;
    return GameMenuButton(
      catalog: catalog,
      year: widget.year,
      currentSlug: widget.currentSlug,
      currentGameId: widget.currentGameId,
      onPick: (g) {
        if (g.slug == widget.currentSlug) {
          widget.onPickHere(g);
        } else {
          navigateTo(webGameUrl(g, subject: g.isCraft ? t?.subject : null, year: t?.year, topic: t?.topic));
        }
      },
      onLearn: widget.onLearnHere ??
          (catalog.learnSlug(widget.year) == null
              ? null
              : () => navigateTo(webLearnUrl(catalog.learnSlug(widget.year)!,
                  subject: t?.subject, year: t?.year, topic: t?.topic))),
    );
  }
}

/// The slug of this build, from the address (`/games/scout/` or locally `/scout/`).
String currentWebSlug() {
  final segs = [for (final s in Uri.base.pathSegments) if (s.isNotEmpty && !s.contains('.')) s];
  return segs.isEmpty ? '' : segs.last;
}
