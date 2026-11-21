// ignore_for_file: depend_on_referenced_packages
// Web product entry for the Mind games (Ember, Presto). games-web copies this file into a checkout
// of the app at a pinned commit and builds it with `-t lib/web_product/main_web.dart`. The app repo
// is never changed. The app's own preferences are replaced by an in-memory store; there are no profiles, no coins,
// no shop and no purchases. Each game opens straight from the game list or the address, with the thin bar (Game menu,
// Rules) on top; the only things remembered are the web state of web_state.dart and the rules-seen flags.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../core/config/app_config.dart';
import '../core/config/products.dart';
import '../core/services.dart';
import '../engine/engine.dart';
import '../ui/game_registry.dart';
import '../ui/kit/ds_art.dart';
import '../ui/theme/app_theme.dart';
import '../ui/theme/design_loader.dart';
import '../ui/theme/design_scope.dart';
import '../ui/theme/design_tokens.dart';
import 'web_bar.dart';
import 'web_catalog.dart';
import 'web_link.dart';
import 'web_platform.dart';
import 'web_rules.dart';
import 'web_state.dart';

Future<void> main() async {
  keepAddressAsIs();
  WidgetsFlutterBinding.ensureInitialized();
  // The app's own progress is not kept on the web: every visit starts empty.
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
  runApp(
    WebProductApp(
      services: services,
      design: design,
      games: appGames,
      link: WebLink.fromUri(Uri.base),
    ),
  );
}

class WebProductApp extends StatelessWidget {
  const WebProductApp({
    super.key,
    required this.services,
    required this.design,
    required this.games,
    required this.link,
  });
  final Services services;
  final DesignBundle? design;
  final MiniGameRegistry games;
  final WebLink link;

  /// `#/game/<id>` opens that game straight away (the catalog page links here); anything else shows the list.
  Widget _home() {
    final cfg = services.config;
    if (link.kind == 'game') {
      for (final e in games.entries) {
        final g = e.game;
        if (g.id == link.at(1) && g.buildStandalone != null) return MindGameScreen(games: games, gameId: g.id);
      }
    }
    return GameList(title: cfg.displayName, games: games);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = services.config;
    final mode = design?.app.resolveMode(DesignMode.game);
    final theme = design != null
        ? buildDesignTheme(
            app: design!.app,
            shared: design!.shared,
            mode: mode!,
            level: null,
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
      services: services,
      child: MaterialApp(
        title: cfg.displayName,
        debugShowCheckedModeBanner: false,
        theme: theme,
        builder: (context, child) => design == null
            ? child!
            : DesignScope(
                design: design!,
                mode: mode!,
                level: null,
                colorOverrides: null,
                child: child!,
              ),
        home: _home(),
      ),
    );
  }
}

/// The game list: one tile per game that can run on its own. Coin prices and locks are ignored,
/// everything on this page is free (the web product sells nothing).
class GameList extends StatelessWidget {
  const GameList({super.key, required this.title, required this.games});
  final String title;
  final MiniGameRegistry games;

  @override
  Widget build(BuildContext context) {
    final playable = [
      for (final e in games.entries)
        if (e.game.buildStandalone != null) e.game,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: GridView.count(
        key: const Key('web.gameList'),
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          for (final g in playable)
            InkWell(
              key: Key('web.game.${g.id}'),
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(body: MindGameScreen(games: games, gameId: g.id)),
                ),
              ),
              child: Semantics(
                label: 'Play ${g.title}',
                button: true,
                excludeSemantics: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: DsGameArt(g.id)),
                    const SizedBox(height: 8),
                    Text(g.title, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One Mind game under the thin bar. The Game menu switches to another game of this build in place (and keeps the
/// address in step); a game of another build, or Learn, opens that build's page.
class MindGameScreen extends StatefulWidget {
  const MindGameScreen({super.key, required this.games, required this.gameId});
  final MiniGameRegistry games;
  final String gameId;

  @override
  State<MindGameScreen> createState() => _MindGameScreenState();
}

class _MindGameScreenState extends State<MindGameScreen> {
  late String _id = widget.gameId;
  final String _slug = currentWebSlug();

  MiniGame? get _game {
    for (final e in widget.games.entries) {
      if (e.game.id == _id && e.game.buildStandalone != null) return e.game;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    if (g == null) return const SizedBox.shrink();
    final from = ServicesScope.of(context).config.displayName;
    return RulesGate(
      key: ValueKey('gate.$_id'),
      gameId: _id,
      actions: [
        CatalogGameMenu(
          currentSlug: _slug,
          currentGameId: _id,
          year: loadWebState().year,
          fallback: [
            for (final e in widget.games.entries)
              if (e.game.buildStandalone != null)
                CatalogGame(slug: _slug, gameId: e.game.id, title: e.game.title, from: from, kind: 'mind'),
          ],
          onPickHere: (c) {
            replaceHash('#/game/${c.gameId}');
            setState(() => _id = c.gameId);
          },
        ),
      ],
      child: g.buildStandalone!((_) async {}) as Widget,
    );
  }
}
