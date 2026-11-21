// ignore_for_file: depend_on_referenced_packages
// Web product entry for the Craft learning games (Scout, Ranger, Champion). games-web copies this file
// into a checkout of the app at a pinned commit and builds it with `-t lib/web_product/main_web.dart`;
// the app repo is never changed. No coins, no shop, no purchases, no profiles: the built-in starter packs are all open
// and a round runs on an anonymous, empty progress (the app's own progress is not kept). What the web remembers is the
// small state in web_state.dart (year, topic status, last game), on this device only. build_game.sh merges the free
// packs of all three Craft apps into this build, so every game plays every year and topic (W6).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../core/config/app_config.dart';
import '../core/config/products.dart';
import '../core/services.dart';
import '../engine/engine.dart';
import '../ui/theme/app_theme.dart';
import '../ui/theme/design_loader.dart';
import '../ui/theme/design_scope.dart';
import '../ui/theme/design_tokens.dart';
import 'craft_shell.dart';
import 'web_link.dart';
import 'web_platform.dart';
import 'web_state.dart';
import 'web_state_model.dart';

Future<void> main() async {
  keepAddressAsIs();
  WidgetsFlutterBinding.ensureInitialized();
  // The app's own progress is not kept on the web: every visit starts empty (see web_state.dart for what is).
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
  final WebState _ws = loadWebState();
  late final WebLinkLaunch _launch = WebLinkLaunch.fromLink(widget.link);
  int? _year;

  List<int> get _years => ({for (final p in widget.open) p.year}.toList()..sort());

  @override
  void initState() {
    super.initState();
    // The address year wins for this view; otherwise the saved year. Only a choice made here is saved.
    final y = _launch.year ?? _ws.year;
    _year = y != null && _years.contains(y) ? y : null;
  }

  void _setYear(int y) {
    _ws.year = y;
    saveWebState(_ws);
    setState(() => _year = y);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.services.config;
    final design = widget.design;
    final year = _year;
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
        home: CraftShell(
          services: widget.services,
          packs: widget.packs,
          open: widget.open,
          topics: widget.topics,
          years: _years,
          year: year,
          onYear: _setYear,
          launch: _launch,
          state: _ws,
        ),
      ),
    );
  }
}
