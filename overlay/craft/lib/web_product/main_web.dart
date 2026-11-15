// ignore_for_file: depend_on_referenced_packages
// Web product entry for the Craft learning games (Scout, Ranger, Champion). games-web copies this file
// into a checkout of the app at a pinned commit and builds it with `-t lib/web_product/main_web.dart`;
// the app repo is never changed. No coins, no shop, no purchases, no profiles, nothing saved: the
// built-in starter packs are all open and a round runs on an anonymous, empty progress.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../core/config/app_config.dart';
import '../core/config/products.dart';
import '../core/services.dart';
import '../engine/engine.dart';
import '../ui/quick_quiz_screen.dart';
import '../ui/theme/app_theme.dart';
import '../ui/theme/design_loader.dart';
import '../ui/theme/design_scope.dart';
import '../ui/theme/design_tokens.dart';
import 'web_link.dart';
import 'web_rules.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Progress is not saved on the web: every visit starts empty.
  SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
  final config = AppConfig.fromYamlString(
    await rootBundle.loadString('app.config.yaml'),
  );
  final catalog = ProductCatalog.fromYamlString(
    await rootBundle.loadString('products.yaml'),
  );
  final services = await Services.create(config: config, catalog: catalog);
  final design = config.designId == null
      ? null
      : await DesignBundle.load(config.designId!);
  final packs = await services.learning?.loadedPacks() ?? const <LoadedPack>[];
  Topics? topics;
  try {
    topics = Topics.parse(await rootBundle.loadString('assets/content/topics.yaml'));
  } on Object {
    topics = null; // topics are then listed in id order
  }
  // Everything in the built-in packs is open (fullUnlock), on an empty progress.
  final open = OpenItems.compute(packs, const ChildProgress(), fullUnlock: true);
  runApp(
    WebLearningApp(
      services: services,
      design: design,
      packs: packs,
      open: open,
      topics: topics,
      link: WebLink.fromUri(Uri.base),
    ),
  );
}

class WebLearningApp extends StatefulWidget {
  const WebLearningApp({
    super.key,
    required this.services,
    required this.design,
    required this.packs,
    required this.open,
    required this.topics,
    required this.link,
  });
  final Services services;
  final DesignBundle? design;
  final List<LoadedPack> packs;
  final List<PoolItem> open;
  final Topics? topics;
  final WebLink link;

  @override
  State<WebLearningApp> createState() => _WebLearningAppState();
}

class _WebLearningAppState extends State<WebLearningApp> {
  int? _year;

  /// `#/quiz/<subject>/<year>/<topic>` (topic may be `all`): the catalog page links here, so the quiz starts at once.
  _Launch? get _launch {
    final l = widget.link;
    if (l.kind != 'quiz') return null;
    final y = int.tryParse(l.at(2) ?? '');
    final subject = l.at(1);
    if (subject == null || y == null) return null;
    final topic = l.at(3);
    return _Launch(subject, y, topic == null || topic == 'all' ? null : topic);
  }

  List<int> get _years =>
      ({for (final p in widget.open) p.year}.toList()..sort());

  @override
  Widget build(BuildContext context) {
    final cfg = widget.services.config;
    final design = widget.design;
    final launch = _launch;
    final year = _year ?? launch?.year ?? (_years.isEmpty ? null : _years.first);
    final mode = design?.app.resolveMode(DesignMode.study);
    final level = design?.app.levelForYear(year);
    final theme = design != null
        ? buildDesignTheme(
            app: design.app,
            shared: design.shared,
            mode: mode!,
            level: level,
            colorOverrides: null,
          )
        : ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Color(cfg.themeSeedColor),
              brightness: cfg.themeDark ? Brightness.dark : Brightness.light,
            ),
          );
    return ServicesScope(
      services: widget.services,
      child: MaterialApp(
        title: cfg.displayName,
        debugShowCheckedModeBanner: false,
        theme: theme,
        builder: (context, child) => design == null
            ? child!
            : DesignScope(
                design: design,
                mode: mode!,
                level: level,
                colorOverrides: null,
                child: child!,
              ),
        home: TopicPicker(
          title: cfg.displayName,
          services: widget.services,
          packs: widget.packs,
          open: widget.open,
          topics: widget.topics,
          years: _years,
          year: year,
          onYear: (y) => setState(() => _year = y),
          launch: launch,
        ),
      ),
    );
  }
}

/// Year, subject and topic: the whole web "home". Topics follow the teaching order of topics.yaml.
class TopicPicker extends StatefulWidget {
  const TopicPicker({
    super.key,
    required this.title,
    required this.services,
    required this.packs,
    required this.open,
    required this.topics,
    required this.years,
    required this.year,
    required this.onYear,
    this.launch,
  });
  final _Launch? launch;
  final String title;
  final Services services;
  final List<LoadedPack> packs;
  final List<PoolItem> open;
  final Topics? topics;
  final List<int> years;
  final int? year;
  final ValueChanged<int> onYear;

  @override
  State<TopicPicker> createState() => _TopicPickerState();
}

class _TopicPickerState extends State<TopicPicker> {
  String _subject = 'maths';

  @override
  void initState() {
    super.initState();
    final l = widget.launch;
    if (l != null) {
      _subject = l.subject;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _play(l.subject, l.year, l.topic);
      });
    }
  }

  List<String> get _subjects =>
      ({for (final p in widget.open) p.subject}.toList()..sort());

  List<String> _topicsFor(String subject, int year) {
    final ids = {
      for (final p in widget.open)
        if (p.subject == subject && p.year == year) p.topic,
    };
    final order = widget.topics?.orderFor(subject, year) ?? const <String>[];
    return [
      ...order.where(ids.contains),
      ...(ids.toList()..sort()).where((t) => !order.contains(t)),
    ];
  }

  void _play(String subject, int year, String? topic) {
    final session = QuizSession.start(
      open: widget.open,
      progress: const ChildProgress(),
      packs: widget.packs,
      rewardsConfig: const RewardsConfig(weeklyCapPerChild: 0),
      subject: subject,
      year: year,
      today: 0,
      random: Random(),
      types: quickQuizGame.itemTypes,
      topic: topic,
      minPool: 1,
      gameId: quickQuizGame.id,
    );
    if (session == null) return;
    final nav = Navigator.of(context);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: RulesGate(
            gameId: 'quick_quiz',
            child: quickQuizGame.build(
              MiniGameContext(
                session: session,
                mode: MiniGameMode.study,
                onAnswered: (r, sess) {},
                onExit: () {
                  if (nav.mounted) nav.pop();
                },
              ),
            ) as Widget,
          ),
        ),
      ),
    );
  }

  /// A topic id that topics.yaml does not name, shown as words: comparing_size -> Comparing size.
  String _pretty(String id) => _label(id.replaceAll('_', ' '));

  String _label(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final year = widget.year;
    final subjects = _subjects;
    if (!subjects.contains(_subject) && subjects.isNotEmpty) {
      _subject = subjects.first;
    }
    final topics = year == null ? const <String>[] : _topicsFor(_subject, year);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        key: const Key('web.topicPicker'),
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final y in widget.years)
                ChoiceChip(
                  key: Key('web.year.$y'),
                  label: Text(y == 0 ? 'Foundation' : 'Year $y'),
                  selected: y == year,
                  onSelected: (_) => widget.onYear(y),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final s in subjects)
                ChoiceChip(
                  key: Key('web.subject.$s'),
                  label: Text(_label(s)),
                  selected: s == _subject,
                  onSelected: (_) => setState(() => _subject = s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (year != null && topics.isNotEmpty)
            FilledButton.icon(
              key: const Key('web.playAll'),
              onPressed: () => _play(_subject, year, null),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play a mixed round'),
            ),
          const SizedBox(height: 8),
          for (var i = 0; year != null && i < topics.length; i++)
            Card(
              child: ListTile(
                key: Key('web.topic.${topics[i]}'),
                title: Text(
                  widget.topics?.displayName(_subject, year, topics[i]) ??
                      _pretty(topics[i]),
                ),
                subtitle: Text('Topic ${i + 1} of ${topics.length}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _play(_subject, year, topics[i]),
              ),
            ),
        ],
      ),
    );
  }
}

/// A quiz the address asks for (see `_WebLearningAppState._launch`).
class _Launch {
  const _Launch(this.subject, this.year, this.topic);
  final String subject;
  final int year;
  final String? topic;
}
