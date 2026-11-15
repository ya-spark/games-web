// Web product entry for the Mind games (Ember, Presto). games-web copies this file into a checkout
// of the app at a pinned commit and builds it with `-t lib/web_product/main_web.dart`. The app repo
// is never changed. Nothing is saved: preferences are replaced by an in-memory store, there are no
// profiles, no coins, no shop and no purchases; each game is opened straight from the game list.
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
  runApp(WebProductApp(services: services, design: design, games: appGames));
}

class WebProductApp extends StatelessWidget {
  const WebProductApp({
    super.key,
    required this.services,
    required this.design,
    required this.games,
  });
  final Services services;
  final DesignBundle? design;
  final MiniGameRegistry games;

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
        home: GameList(title: cfg.displayName, games: games),
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
                  builder: (_) => g.buildStandalone!((_) async {}) as Widget,
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
